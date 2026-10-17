import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../core/meal_type.dart';
import '../core/time/meal_window.dart';
import '../data/store.dart';
import 'menu_service.dart';
import 'scan_service.dart';

/// Reads a v1 `.tiffin` backup — the SQLite snapshot the LAN-host build wrote —
/// into the same `{collection: [documents]}` shape a v2 backup holds, so one
/// restore path writes both.
///
/// Old integer ids become string ids (`'12'`), references follow, and the
/// only scans that keep the per-meal lock id are today's unreversed ones; the
/// rest are history and get `legacy_<id>`.
class LegacyImport {
  const LegacyImport();

  /// [sqlite] is the decrypted database file from inside the backup.
  Future<LegacyData> read(List<int> sqlite, Directory scratch) async {
    final file = File(
        '${scratch.path}/legacy-${DateTime.now().microsecondsSinceEpoch}.sqlite');
    await file.writeAsBytes(sqlite, flush: true);
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      return _convert(db);
    } finally {
      db.close();
      if (file.existsSync()) file.deleteSync();
    }
  }

  LegacyData _convert(Database db) {
    List<Row> rows(String table) {
      try {
        return db.select('SELECT * FROM "$table"').toList();
      } on SqliteException {
        return const []; // a table an older schema didn't have yet
      }
    }

    String at(Object? seconds) =>
        DateTime.fromMillisecondsSinceEpoch((seconds as int) * 1000,
                isUtc: true)
            .toIso8601String();
    String? atOrNull(Object? s) => s == null ? null : at(s);
    String day(Object? seconds) =>
        ymd(DateTime.fromMillisecondsSinceEpoch((seconds as int) * 1000,
            isUtc: true));
    bool flag(Object? v) => v == 1 || v == true;
    List<dynamic> list(Object? json) =>
        json == null ? const [] : jsonDecode(json as String) as List<dynamic>;

    final settingsRow = rows('app_settings').firstOrNull;
    final zone = settingsRow?['local_timezone'] as String? ?? 'Asia/Kolkata';
    final today = ymd(toLocal(DateTime.now().toUtc(), zone));

    final out = <String, List<Json>>{};

    out[Col.users] = [
      for (final r in rows('users'))
        {
          'id': '${r['id']}',
          'username': r['username'],
          'passwordHash': r['password_hash'],
          'role': r['role'],
          'status': r['status'],
          'createdAt': at(r['created_at']),
          'updatedAt': at(r['updated_at']),
        }
    ];

    out[Col.members] = [
      for (final r in rows('members'))
        {
          'id': '${r['id']}',
          'type': r['type'],
          'name': r['name'],
          'className': r['class_name'],
          'rollNumber': r['roll_number'],
          'staffId': r['staff_id'],
          'qrCodeId': r['qr_code_id'],
          'balances': {
            'lunch': r['lunch_balance'],
            'breakfast': r['breakfast_balance'],
            'brunch': r['brunch_balance'],
          },
          'graceAllowanceOverride': r['grace_allowance_override'],
          'status': r['status'],
          'category': r['category'] ?? 'Normal',
          'createdAt': at(r['created_at']),
          'updatedAt': at(r['updated_at']),
        }
    ];
    final memberName = {
      for (final m in out[Col.members]!) m['id'] as String: m['name'] as String
    };

    out[Col.scans] = [
      for (final r in rows('scans'))
        () {
          final memberId = '${r['member_id']}';
          final meal = MealType.fromWire(r['meal_type'] as String);
          final scannedAt = DateTime.fromMillisecondsSinceEpoch(
              (r['scanned_at'] as int) * 1000,
              isUtc: true);
          final scanDay = ymd(toLocal(scannedAt, zone));
          final reversed = flag(r['reversed']);
          final consumed = r['consumed_json'] == null
              ? <String, dynamic>{}
              : (jsonDecode(r['consumed_json'] as String)
                  as Map<String, dynamic>);
          return <String, dynamic>{
            'id': !reversed && scanDay == today
                ? ScanService.lockId(memberId, scanDay, meal)
                : 'legacy_${r['id']}',
            'memberId': memberId,
            'memberName': memberName[memberId] ?? memberId,
            'mealType': meal.wire,
            'day': scanDay,
            'scannedAt': scannedAt.toIso8601String(),
            'result': r['result'] ?? 'accepted',
            'viaGrace': flag(r['via_grace']),
            'reversed': reversed,
            'reversedAt': atOrNull(r['reversed_at']),
            'reversedBy': r['reversed_by'],
            'memberCategory': r['member_category'],
            'consumed': consumed,
          };
        }()
    ];

    out[Col.topups] = [
      for (final r in rows('topups'))
        {
          'id': '${r['id']}',
          'memberId': '${r['member_id']}',
          'lunchUnits': r['lunch_units'],
          'breakfastUnits': r['breakfast_units'],
          'brunchUnits': r['brunch_units'],
          'amount': (r['amount'] as num).toDouble(),
          'paymentMethod': r['payment_method'],
          'paymentStatus': r['payment_status'],
          'hasBill': true,
          'hasUpiQr': r['upi_qr_path'] != null,
          'createdBy': r['created_by'],
          'createdAt': at(r['created_at']),
          'reversed': flag(r['reversed']),
          'reversedAt': atOrNull(r['reversed_at']),
          'reversedBy': r['reversed_by'],
        }
    ];

    out[Col.refunds] = [
      for (final r in rows('refunds'))
        {
          'id': '${r['id']}',
          'memberId': '${r['member_id']}',
          'lunchUnits': r['lunch_units'],
          'breakfastUnits': r['breakfast_units'],
          'brunchUnits': r['brunch_units'],
          'refundAmount': (r['refund_amount'] as num).toDouble(),
          'reason': r['reason'],
          'processedBy': r['processed_by'],
          'createdAt': at(r['created_at']),
        }
    ];

    out[Col.menuCategories] = [
      for (final r in rows('menu_categories'))
        {
          'id': '${r['id']}',
          'name': r['name'],
          'description': r['description'],
          'createdAt': at(r['created_at']),
          'updatedAt': at(r['updated_at']),
        }
    ];

    out[Col.menu] = [
      for (final r in rows('menu_entries'))
        () {
          final date = day(r['date']);
          final meal = MealType.fromWire(r['meal_type'] as String);
          final category = r['category'] as String? ?? 'Normal';
          return <String, dynamic>{
            'id': MenuService.entryId(date, meal, category),
            'date': date,
            'mealType': meal.wire,
            'category': category,
            'headcount': r['headcount'] ?? 0,
            'items': list(r['items_json']),
            'createdBy': r['created_by'],
          };
        }()
    ];

    out[Col.ingredients] = [
      for (final r in rows('ingredients'))
        {
          'id': '${r['id']}',
          'name': r['name'],
          'unit': r['unit'],
          'stockQty': (r['stock_qty'] as num?)?.toDouble() ?? 0,
          'lowStockAt': (r['low_stock_at'] as num?)?.toDouble(),
          'createdAt': at(r['created_at']),
          'updatedAt': at(r['updated_at']),
        }
    ];

    out[Col.recipes] = [
      for (final r in rows('recipes'))
        {
          'id': '${r['id']}',
          'dishName': r['dish_name'],
          'ingredients': [
            for (final line in list(r['ingredients_json']))
              {
                'ingredientId': '${(line as Map)['ingredientId']}',
                'quantity': (line['quantity'] as num?)?.toDouble() ?? 1,
              }
          ],
          'createdAt': at(r['created_at']),
          'updatedAt': at(r['updated_at']),
        }
    ];

    out[Col.purchaseSchedule] = [
      for (final r in rows('purchase_schedule_items'))
        {
          'id': '${r['id']}',
          'date': day(r['date']),
          'ingredientId': '${r['ingredient_id']}',
          'ingredientName': r['ingredient_name'],
          'ingredientUnit': r['ingredient_unit'],
          'quantityNote': r['quantity_note'],
          'source': r['source'],
          'purchased': flag(r['purchased']),
          'purchasedBy': r['purchased_by'],
          'purchasedAt': atOrNull(r['purchased_at']),
          'purchasedQty': (r['purchased_qty'] as num?)?.toDouble(),
          'purchasedCost': (r['purchased_cost'] as num?)?.toDouble(),
          'expenseId': r['expense_id'] == null ? null : '${r['expense_id']}',
          'createdAt': at(r['created_at']),
          'updatedAt': at(r['updated_at']),
        }
    ];

    out[Col.expenses] = [
      for (final r in rows('expenses'))
        {
          'id': '${r['id']}',
          'category': r['category'],
          'description': r['description'],
          'amount': (r['amount'] as num).toDouble(),
          'date': day(r['date']),
          'createdBy': r['created_by'],
        }
    ];

    Json? settings;
    if (settingsRow != null) {
      final s = settingsRow;
      settings = {
        'graceAllowanceEnabled': flag(s['grace_allowance_enabled']),
        'graceAllowanceUnits': s['grace_allowance_units'],
        'reversalWindowMinutes': s['reversal_window_minutes'],
        'mealWindows': {
          'breakfast': {
            'start': s['breakfast_start'],
            'end': s['breakfast_end']
          },
          'lunch': {'start': s['lunch_start'], 'end': s['lunch_end']},
          'brunch': {'start': s['brunch_start'], 'end': s['brunch_end']},
        },
        'localTimezone': zone,
        'upiId': s['upi_id'],
        'upiPayeeName': s['upi_payee_name'],
        'unitPrices': {
          'lunch': (s['lunch_price'] as num).toDouble(),
          'breakfast': (s['breakfast_price'] as num).toDouble(),
          'brunch': (s['brunch_price'] as num).toDouble(),
        },
        'appName': s['app_name'],
        'prepLeadMinutes': s['prep_lead_minutes'],
        'purchaseLeadDays': s['purchase_lead_days'],
        if (s['enforce_appearance'] != null)
          'enforceAppearance': flag(s['enforce_appearance']),
        if (s['appearance_theme'] != null)
          'appearanceTheme': s['appearance_theme'],
        if (s['appearance_mode'] != null)
          'appearanceMode': s['appearance_mode'],
        if (s['appearance_motion'] != null)
          'appearanceMotion': flag(s['appearance_motion']),
      };
    }
    return LegacyData(collections: out, settings: settings);
  }
}

class LegacyData {
  const LegacyData({required this.collections, this.settings});

  final Map<String, List<Json>> collections;
  final Json? settings;
}
