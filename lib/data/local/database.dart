import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'schema_versions.dart';
import 'tables.dart';

part 'database.g.dart';

/// The host-mode database. Client mode never constructs this (PRD §13.7).
///
/// `part 'database.g.dart'` is produced by `dart run build_runner build`; it
/// does not exist until codegen runs. See the Makefile `gen` target.
@DriftDatabase(
  tables: [
    Members,
    Scans,
    Topups,
    Refunds,
    MenuCategories,
    MenuEntries,
    Ingredients,
    Recipes,
    PurchaseScheduleItems,
    Expenses,
    Users,
    Sessions,
    Notifications,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For tests: an in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedSettingsRow();
        },
        // Each step sees the schema as it was at *that* version, never the
        // latest. Writing them against the current tables looks fine until a
        // later version adds a column, at which point an old step starts
        // referencing something that does not exist yet on a real device.
        // Regenerate the step definitions with `make schema` after a bump.
        onUpgrade: stepByStep(
          from1To2: (m, schema) async {
            // A column DEFAULT lives in the CREATE TABLE, so changing it means
            // recreating the table; TableMigration carries existing rows over.
            await m.alterTable(TableMigration(schema.appSettings));
            // Raw SQL on purpose: it names only columns that exist at v2.
            //
            // v1 shipped a `UTC` default, which is wrong for every real
            // deployment — meal windows are local wall-clock times. Only
            // installs still on that untouched default are corrected; an admin
            // who chose UTC deliberately is indistinguishable, but on a
            // pre-pilot app that trade beats every install silently keeping a
            // bad zone.
            await customStatement(
              "UPDATE app_settings SET local_timezone = 'Asia/Kolkata' "
              "WHERE local_timezone = 'UTC'",
            );
          },
          from3To4: (m, schema) async {
            // Empty by default; SettingsService fills it on first read, so an
            // upgraded host keeps serving without a restart.
            await m.addColumn(schema.appSettings, schema.appSettings.hostId);
          },
          from4To5: (m, schema) async {
            // Top-up reversal. Additive and defaulted (reversed = false), so an
            // existing host's past top-ups read exactly as they did before.
            await m.addColumn(schema.topups, schema.topups.reversed);
            await m.addColumn(schema.topups, schema.topups.reversedAt);
            await m.addColumn(schema.topups, schema.topups.reversedBy);
          },
          from2To3: (m, schema) async {
            // Host-enforced appearance. Additive and defaulted off, so an
            // existing host keeps behaving exactly as it did.
            await m.addColumn(
                schema.appSettings, schema.appSettings.enforceAppearance);
            await m.addColumn(
                schema.appSettings, schema.appSettings.appearanceTheme);
            await m.addColumn(
                schema.appSettings, schema.appSettings.appearanceMode);
            await m.addColumn(
                schema.appSettings, schema.appSettings.appearanceMotion);
          },
          from5To6: (m, schema) async {
            // Recipe ingredient lines moved from a free-text note
            // ("2kg per 50 servings") to a numeric quantity in the
            // ingredient's own unit. No column changes — the lines live in a
            // JSON blob — so convert the blob in place: pull the leading
            // number out of each note, defaulting to 1 when there isn't one.
            final rows =
                await customSelect('SELECT id, ingredients_json FROM recipes')
                    .get();
            for (final row in rows) {
              final id = row.read<int>('id');
              final lines = (jsonDecode(row.read<String>('ingredients_json'))
                      as List<dynamic>)
                  .cast<Map<String, dynamic>>();
              final converted = [
                for (final line in lines)
                  {
                    'ingredientId': line['ingredientId'],
                    'quantity': line.containsKey('quantity')
                        ? (line['quantity'] as num).toDouble()
                        : _leadingNumber(line['quantityNote'] as String?),
                  }
              ];
              await customStatement(
                'UPDATE recipes SET ingredients_json = ? WHERE id = ?',
                [jsonEncode(converted), id],
              );
            }
          },
          from6To7: (m, schema) async {
            // Members gain a serving category; scans record the member's
            // category as-of-scan. Both additive and defaulted.
            await m.addColumn(schema.members, schema.members.category);
            await m.addColumn(schema.scans, schema.scans.memberCategory);

            // A menu entry is now one meal / one date / one *single* category
            // with a headcount, instead of a list of categories. Rebuild the
            // table and fan each old row out into one row per category.
            await customStatement(
                'ALTER TABLE menu_entries RENAME TO _menu_entries_v6');
            await m.createTable(schema.menuEntries);
            final rows = await customSelect(
              'SELECT date, meal_type, categories_json, items_json, created_by '
              'FROM _menu_entries_v6',
            ).get();
            for (final row in rows) {
              final cats = (jsonDecode(row.read<String>('categories_json'))
                      as List<dynamic>)
                  .cast<String>();
              for (final category in cats.isEmpty ? const ['General'] : cats) {
                await customStatement(
                  'INSERT OR IGNORE INTO menu_entries '
                  '(date, meal_type, category, headcount, items_json, '
                  'created_by) VALUES (?, ?, ?, 0, ?, ?)',
                  [
                    row.read<int>('date'),
                    row.read<String>('meal_type'),
                    category,
                    row.read<String>('items_json'),
                    row.read<String>('created_by'),
                  ],
                );
              }
            }
            await customStatement('DROP TABLE _menu_entries_v6');
          },
          from7To8: (m, schema) async {
            // Inventory: ingredients carry stock + an alert threshold; a
            // purchased schedule item records the actual quantity/cost; a scan
            // records what it consumed so a reversal can restore it. All
            // additive and defaulted.
            await m.addColumn(schema.ingredients, schema.ingredients.stockQty);
            await m.addColumn(
                schema.ingredients, schema.ingredients.lowStockAt);
            await m.addColumn(schema.purchaseScheduleItems,
                schema.purchaseScheduleItems.purchasedQty);
            await m.addColumn(schema.purchaseScheduleItems,
                schema.purchaseScheduleItems.purchasedCost);
            await m.addColumn(schema.purchaseScheduleItems,
                schema.purchaseScheduleItems.expenseId);
            await m.addColumn(schema.scans, schema.scans.consumedJson);
          },
        ),
      );

  /// Leading number in a free-text quantity note ("2kg per 50" -> 2.0), used
  /// once by the v5->v6 migration. Falls back to 1 so a converted recipe line
  /// still means "some of this ingredient", never zero.
  static double _leadingNumber(String? note) {
    if (note == null) return 1;
    final match = RegExp(r'\d+(\.\d+)?').firstMatch(note);
    return match == null ? 1 : (double.tryParse(match.group(0)!) ?? 1);
  }

  Future<void> _seedSettingsRow() => into(appSettings).insert(
        const AppSettingsCompanion(id: Value(0)),
        mode: InsertMode.insertOrIgnore,
      );

  /// Deletes every row and re-seeds the settings singleton — a fresh install
  /// without a reinstall. Host-admin "reset all data" only; destructive, so
  /// it's gated behind a typed confirmation in the UI (CLAUDE.md §18.2).
  Future<void> wipeAllData() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
      await _seedSettingsRow();
    });
  }
}

/// Where the host's database lives. Exposed because backup and restore have
/// to address the file itself, not just the connection.
///
/// Renames a pre-Tiffin `canteen.sqlite` into place on the way past. A host
/// that has been running for weeks holds the only copy of its data, and a
/// cosmetic rename must not be the thing that loses it — so the old file is
/// moved rather than ignored, along with any journal sitting beside it.
Future<File> appDatabaseFile() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'tiffin.sqlite'));
  if (file.existsSync()) return file;

  final legacy = File(p.join(dir.path, 'canteen.sqlite'));
  if (legacy.existsSync()) {
    for (final suffix in const ['-wal', '-shm']) {
      final sidecar = File('${legacy.path}$suffix');
      if (sidecar.existsSync()) sidecar.renameSync('${file.path}$suffix');
    }
    legacy.renameSync(file.path);
  }
  return file;
}

LazyDatabase _openConnection() {
  return LazyDatabase(
      () async => NativeDatabase.createInBackground(await appDatabaseFile()));
}
