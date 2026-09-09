import 'package:tiffin/data/local/database.dart';
import 'package:tiffin/services/settings_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated_migrations/schema.dart';

/// Migrations are the one place a bug silently corrupts a host's only copy of
/// the data, so every schema bump runs against a real database at the previous
/// version — including from the oldest version still in the wild, which is
/// where step ordering bugs actually show up.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  const current = 7;

  Future<String> timezoneOf(AppDatabase db) async =>
      (await db.select(db.appSettings).getSingle()).localTimezone;

  /// Opens a database at [from], seeds the settings row, then migrates it all
  /// the way to the current version and validates the resulting schema.
  Future<AppDatabase> migrated(int from, {String? timezone}) async {
    final schema = await verifier.schemaAt(from);
    final seed = schema.newConnection();
    await seed.executor.ensureOpen(_SeedUser(from));
    await seed.executor.runCustom(
      'INSERT INTO app_settings (id, app_name'
      '${timezone == null ? '' : ', local_timezone'}) '
      'VALUES (0, ?${timezone == null ? '' : ', ?'})',
      ['Tiffin', if (timezone != null) timezone],
    );
    await seed.executor.close();

    final db = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, current);
    return db;
  }

  for (final from in [1, 2, 3, 4, 5, 6]) {
    test('v$from -> v$current keeps the schema valid and the row intact',
        () async {
      final db = await migrated(from);
      final settings = await db.select(db.appSettings).getSingle();
      expect(settings.appName, 'Tiffin',
          reason: 'existing data survives the migration');
      // Appearance enforcement is additive and must default to off, so an
      // existing host behaves exactly as it did before the upgrade.
      expect(settings.enforceAppearance, isFalse);
      expect(settings.appearanceTheme, 'neobrutal');
      expect(settings.appearanceMode, 'system');
      expect(settings.appearanceMotion, isTrue);
      // The host id is added empty and filled on first read, so an upgraded
      // host doesn't need a data migration that invents one.
      expect(settings.hostId, isEmpty);
      await db.close();
    });
  }

  test('v4 -> v5 adds top-up reversal columns, defaulting to not-reversed',
      () async {
    final db = await migrated(4);
    final now = DateTime.now().toUtc();
    final memberId = await db.into(db.members).insert(MembersCompanion.insert(
          type: 'staff',
          name: 'Reversal Test',
          qrCodeId: 'qr-rev-test',
          createdAt: now,
          updatedAt: now,
        ));
    final topupId = await db.into(db.topups).insert(TopupsCompanion.insert(
          memberId: memberId,
          amount: 100,
          paymentMethod: 'cash',
          paymentStatus: 'confirmed',
          createdBy: 'tester',
          createdAt: now,
        ));
    final row = await (db.select(db.topups)..where((t) => t.id.equals(topupId)))
        .getSingle();
    expect(row.reversed, isFalse);
    expect(row.reversedAt, null);
    expect(row.reversedBy, null);
    await db.close();
  });

  test('v6 -> v7 fans a multi-category menu entry into one row per category',
      () async {
    final schema = await verifier.schemaAt(6);
    final seed = schema.newConnection();
    await seed.executor.ensureOpen(_SeedUser(6));
    await seed.executor
        .runCustom("INSERT INTO app_settings (id, app_name) VALUES (0, 'T')");
    await seed.executor.runCustom(
      'INSERT INTO menu_entries (id, date, meal_type, categories_json, '
      "items_json, created_by) VALUES (1, 0, 'lunch', ?, ?, 'admin')",
      ['["Normal","Jain"]', '["Rice","Dal"]'],
    );
    await seed.executor.close();

    final db = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, current);

    final rows = await db.select(db.menuEntries).get();
    expect(rows.map((e) => e.category).toSet(), {'Normal', 'Jain'});
    expect(rows.every((e) => e.headcount == 0), isTrue);
    expect(rows.every((e) => e.itemsJson.contains('Rice')), isTrue);
    await db.close();
  });

  test('v6 -> v7 defaults a member to the Normal category', () async {
    final db = await migrated(6);
    final now = DateTime.now().toUtc();
    final id = await db.into(db.members).insert(MembersCompanion.insert(
          type: 'student',
          name: 'Cat Default',
          qrCodeId: 'qr-cat-default',
          createdAt: now,
          updatedAt: now,
        ));
    final row = await (db.select(db.members)..where((m) => m.id.equals(id)))
        .getSingle();
    expect(row.category, 'Normal');
    await db.close();
  });

  test('v5 -> v6 turns a recipe quantity note into a number', () async {
    final schema = await verifier.schemaAt(5);
    final seed = schema.newConnection();
    await seed.executor.ensureOpen(_SeedUser(5));
    // DateTime columns persist as unix-second integers here, so raw inserts
    // pass 0 rather than an ISO string.
    await seed.executor
        .runCustom("INSERT INTO app_settings (id, app_name) VALUES (0, 'T')");
    await seed.executor.runCustom(
        'INSERT INTO ingredients (id, name, unit, created_at, updated_at) '
        "VALUES (1, 'Rice', 'kg', 0, 0)");
    await seed.executor.runCustom(
      'INSERT INTO recipes (id, dish_name, dish_name_lower, ingredients_json, '
      "created_at, updated_at) VALUES (1, 'Veg Pulao', 'veg pulao', ?, 0, 0)",
      ['[{"ingredientId":1,"quantityNote":"2kg per 50 servings"}]'],
    );
    await seed.executor.close();

    final db = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, current);

    final recipe = await db.select(db.recipes).getSingle();
    expect(recipe.ingredientsJson, contains('"quantity":2'));
    expect(recipe.ingredientsJson, isNot(contains('quantityNote')));
    await db.close();
  });

  test('v1 -> v3 moves an untouched UTC default to Asia/Kolkata', () async {
    final db = await migrated(1);
    expect(await timezoneOf(db), 'Asia/Kolkata');
    await db.close();
  });

  test('v1 -> v3 leaves a deliberately chosen zone alone', () async {
    final db = await migrated(1, timezone: 'Europe/Berlin');
    expect(await timezoneOf(db), 'Europe/Berlin');
    await db.close();
  });

  test('v2 -> v3 does not touch the timezone at all', () async {
    // The UTC correction belongs to the 1->2 step only; re-running it on a
    // v2 database would override a zone the admin chose after upgrading.
    final db = await migrated(2, timezone: 'UTC');
    expect(await timezoneOf(db), 'UTC');
    await db.close();
  });

  test('the host id is generated once and then stays put', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final settings = SettingsService(db);

    final first = await settings.ensureHostId();
    expect(first, isNotEmpty);
    // Saved logins are keyed on this, so a value that changed per call would
    // quietly orphan every remembered account.
    expect(await settings.ensureHostId(), first);
    await db.close();
  });

  test('a fresh database starts on Asia/Kolkata, not UTC', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(await timezoneOf(db), 'Asia/Kolkata');
    await db.close();
  });
}

/// [QueryExecutor.ensureOpen] wants a user, and it stamps that user's version
/// onto the database. It must therefore report the version actually being
/// seeded — reporting 1 here silently re-ran the 1->2 step on a v2 database.
class _SeedUser extends QueryExecutorUser {
  _SeedUser(this.schemaVersion);

  @override
  final int schemaVersion;

  @override
  Future<void> beforeOpen(_, __) async {}
}
