import 'dart:convert';
import 'dart:io';

import 'package:tiffin/data/local/database.dart';
import 'package:tiffin/server/host_container.dart';
import 'package:tiffin/server/server.dart';
import 'package:tiffin/server/tls.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

/// End-to-end: in-memory DB -> services -> shelf routes -> real HTTP. Proves the
/// host stack wires together and the core scan/top-up business rules survive
/// the round trip.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  late Directory tmp;
  late AppDatabase db;
  late HostContainer container;
  late HostServer server;
  late HttpClient http;
  late String base;
  late String adminToken;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('canteen_test_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Triggers the migration's onCreate, which seeds the settings row.
    await db.customSelect('SELECT 1').get();

    container = HostContainer.create(
      db: db,
      documentsDir: tmp.path,
      sessionTtl: const Duration(hours: 12),
    );
    await container.bootstrap();
    await container.auth.createInitialAdmin(
      username: 'admin',
      password: 'admin-password-1',
    );

    // A stand-in for the materialized web-admin bundle.
    final webDir = Directory('${tmp.path}/web_admin')..createSync();
    File('${webDir.path}/index.html')
        .writeAsStringSync('<!doctype html><h1>admin</h1>');
    File('${webDir.path}/styles.css').writeAsStringSync('body{color:#000}');

    server = HostServer(container, staticRoot: webDir.path);
    await server.start(bind: '127.0.0.1', port: 0);
    base = 'http://127.0.0.1:${server.port}';
    http = HttpClient();

    adminToken = await _login(http, base, 'admin', 'admin-password-1');
  });

  tearDown(() async {
    http.close(force: true);
    await server.stop();
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('login rejects a bad password', () async {
    final res = await _send(http, 'POST', '$base/api/auth/login',
        body: {'username': 'admin', 'password': 'wrong'});
    expect(res.status, 401);
    expect(res.json['error'], 'unauthenticated');
  });

  test('unauthenticated request to a protected route is 401', () async {
    final res = await _send(http, 'GET', '$base/api/members');
    expect(res.status, 401);
  });

  test('full flow: settings -> member -> top-up -> scan', () async {
    // Configure prices + a wide-open lunch window so the scan lands.
    final patch = await _send(http, 'PATCH', '$base/api/settings',
        token: adminToken,
        body: {
          'unitPrices': {'lunch': 40.0, 'breakfast': 25.0, 'brunch': 50.0},
          // Keep breakfast/brunch from ever matching so the scan is
          // unambiguously lunch regardless of wall-clock time.
          'mealWindows': {
            'breakfast': {'start': '00:00', 'end': '00:01'},
            'brunch': {'start': '00:00', 'end': '00:01'},
            'lunch': {'start': '00:02', 'end': '23:59'},
          },
        });
    expect(patch.status, 200);
    expect((patch.json['unitPrices'] as Map)['lunch'], 40.0);

    // Create a student.
    final created = await _send(http, 'POST', '$base/api/members',
        token: adminToken,
        body: {'type': 'student', 'name': 'Asha', 'className': '5B'});
    expect(created.status, 200);
    final memberId = created.json['id'] as int;
    final qrCode = created.json['qrCodeId'] as String;
    expect((created.json['balances'] as Map)['lunch'], 0);

    // Top up 3 lunch units, cash.
    final topup = await _send(http, 'POST', '$base/api/topups',
        token: adminToken,
        body: {'memberId': memberId, 'lunchUnits': 3, 'paymentMethod': 'cash'});
    expect(topup.status, 200);
    expect(topup.json['amount'], 120.0);
    expect(topup.json['paymentStatus'], 'confirmed');

    // Scan once -> accepted, 2 left.
    final scan1 = await _send(http, 'POST', '$base/api/scan',
        token: adminToken, body: {'qrCodeId': qrCode});
    expect(scan1.status, 200);
    expect(scan1.json['outcome'], 'accepted');
    expect(scan1.json['remainingBalance'], 2);

    // Scan again same day/meal -> rejected (one-scan lock).
    final scan2 = await _send(http, 'POST', '$base/api/scan',
        token: adminToken, body: {'qrCodeId': qrCode});
    expect(scan2.json['outcome'], 'rejected_already_scanned');

    // Reverse the first scan -> unit restored.
    final reverse = await _send(http, 'POST', '$base/api/scan/reverse',
        token: adminToken, body: {'scanId': scan1.json['scanId']});
    expect(reverse.json['success'], true);

    final member = await _send(http, 'GET', '$base/api/members/$memberId',
        token: adminToken);
    expect((member.json['balances'] as Map)['lunch'], 3);
  });

  test('reverse a top-up: balance is corrected and the row is flagged',
      () async {
    await _send(http, 'PATCH', '$base/api/settings', token: adminToken, body: {
      'unitPrices': {'lunch': 40.0, 'breakfast': 25.0, 'brunch': 50.0},
    });
    final m = await _send(http, 'POST', '$base/api/members',
        token: adminToken,
        body: {'type': 'staff', 'name': 'Meera', 'staffId': 'M1'});
    final memberId = m.json['id'] as int;

    final topup = await _send(http, 'POST', '$base/api/topups',
        token: adminToken,
        body: {'memberId': memberId, 'lunchUnits': 5, 'paymentMethod': 'cash'});
    final topupId = topup.json['id'] as int;

    final reverse = await _send(
        http, 'POST', '$base/api/topups/$topupId/reverse',
        token: adminToken);
    expect(reverse.status, 200);
    expect(reverse.json['success'], true);

    final member = await _send(http, 'GET', '$base/api/members/$memberId',
        token: adminToken);
    expect((member.json['balances'] as Map)['lunch'], 0);

    final topups =
        await _send(http, 'GET', '$base/api/topups', token: adminToken);
    final row = (jsonDecode(topups.body) as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((t) => t['id'] == topupId);
    expect(row['reversed'], true);
    expect(row['reversedBy'], 'admin');

    // A second reversal is refused.
    final again = await _send(http, 'POST', '$base/api/topups/$topupId/reverse',
        token: adminToken);
    expect(again.json['success'], false);
  });

  test('a top-up cannot be reversed once its units have been spent', () async {
    await _send(http, 'PATCH', '$base/api/settings', token: adminToken, body: {
      'unitPrices': {'lunch': 40.0, 'breakfast': 25.0, 'brunch': 50.0},
      'mealWindows': {
        'breakfast': {'start': '00:00', 'end': '00:01'},
        'brunch': {'start': '00:00', 'end': '00:01'},
        'lunch': {'start': '00:02', 'end': '23:59'},
      },
    });
    final m = await _send(http, 'POST', '$base/api/members',
        token: adminToken,
        body: {'type': 'staff', 'name': 'Nita', 'staffId': 'N1'});
    final memberId = m.json['id'] as int;
    final qr = m.json['qrCodeId'] as String;

    final topup = await _send(http, 'POST', '$base/api/topups',
        token: adminToken,
        body: {'memberId': memberId, 'lunchUnits': 1, 'paymentMethod': 'cash'});
    await _send(http, 'POST', '$base/api/scan',
        token: adminToken, body: {'qrCodeId': qr});

    final reverse = await _send(
        http, 'POST', '$base/api/topups/${topup.json['id']}/reverse',
        token: adminToken);
    expect(reverse.json['success'], false);
    expect(reverse.json['message'], contains('refund'));
  });

  test('purchase schedule generates from a menu item that matches a recipe',
      () async {
    final day = DateTime.now();
    String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final rice = await _send(http, 'POST', '$base/api/ingredients',
        token: adminToken, body: {'name': 'Rice', 'unit': 'kg'});
    final riceId = rice.json['id'] as int;

    // Per-plate recipe: 0.1 kg rice for one plate.
    await _send(http, 'POST', '$base/api/recipes', token: adminToken, body: {
      'dishName': 'Veg Pulao',
      'ingredients': [
        {'ingredientId': riceId, 'quantity': 0.1}
      ],
    });

    await _send(http, 'POST', '$base/api/menu-categories',
        token: adminToken, body: {'name': 'Normal'});
    await _send(http, 'POST', '$base/api/menu', token: adminToken, body: {
      'date': ymd(day),
      'mealType': 'lunch',
      'category': 'Normal',
      'headcount': 50,
      'items': ['Veg Pulao'],
    });

    final gen = await _send(
        http,
        'POST',
        '$base/api/purchase-schedule/generate'
            '?start=${ymd(day)}&end=${ymd(day.add(const Duration(days: 1)))}',
        token: adminToken);
    expect(gen.status, 200);
    expect(gen.json['created'], 1);

    final list = await _send(http, 'GET', '$base/api/purchase-schedule',
        token: adminToken);
    final item = (jsonDecode(list.body) as List).single as Map<String, dynamic>;
    expect(item['ingredientName'], 'Rice');
    // 0.1 kg/plate × 50 plates = 5 kg.
    expect(item['quantityNote'], '5 kg');

    // Idempotent for a repeat; but a headcount change re-computes the figure.
    final again = await _send(
        http,
        'POST',
        '$base/api/purchase-schedule/generate'
            '?start=${ymd(day)}&end=${ymd(day.add(const Duration(days: 1)))}',
        token: adminToken);
    expect(again.json['created'], 0);

    final entryId = (jsonDecode((await _send(
                http, 'GET', '$base/api/menu?start=${ymd(day)}&end=${ymd(day)}',
                token: adminToken))
            .body) as List)
        .single['id'];
    await _send(http, 'PATCH', '$base/api/menu/$entryId',
        token: adminToken, body: {'headcount': 80});
    await _send(
        http,
        'POST',
        '$base/api/purchase-schedule/generate'
            '?start=${ymd(day)}&end=${ymd(day.add(const Duration(days: 1)))}',
        token: adminToken);
    final after = await _send(http, 'GET', '$base/api/purchase-schedule',
        token: adminToken);
    expect((jsonDecode(after.body) as List).single['quantityNote'], '8 kg');
  });

  test('member category defaults to Normal and is editable; scans record it',
      () async {
    await _send(http, 'PATCH', '$base/api/settings', token: adminToken, body: {
      'unitPrices': {'lunch': 40.0, 'breakfast': 25.0, 'brunch': 50.0},
      'mealWindows': {
        'breakfast': {'start': '00:00', 'end': '00:01'},
        'brunch': {'start': '00:00', 'end': '00:01'},
        'lunch': {'start': '00:02', 'end': '23:59'},
      },
    });
    final created = await _send(http, 'POST', '$base/api/members',
        token: adminToken,
        body: {'type': 'staff', 'name': 'Kiran', 'staffId': 'K1'});
    final id = created.json['id'] as int;
    expect(created.json['category'], 'Normal');

    final patched = await _send(http, 'PATCH', '$base/api/members/$id',
        token: adminToken, body: {'category': 'Jain'});
    expect(patched.json['category'], 'Jain');

    await _send(http, 'POST', '$base/api/topups', token: adminToken, body: {
      'memberId': id,
      'lunchUnits': 1,
      'paymentMethod': 'cash',
    });
    await _send(http, 'POST', '$base/api/scan',
        token: adminToken, body: {'qrCodeId': created.json['qrCodeId']});

    final scans =
        await _send(http, 'GET', '$base/api/scans', token: adminToken);
    final row = (jsonDecode(scans.body) as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['memberId'] == id);
    expect(row['memberCategory'], 'Jain');
  });

  test('inventory: scan consumes stock, purchased adds it back with an expense',
      () async {
    String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final day = DateTime.now();

    await _send(http, 'PATCH', '$base/api/settings', token: adminToken, body: {
      'unitPrices': {'lunch': 40.0, 'breakfast': 25.0, 'brunch': 50.0},
      'mealWindows': {
        'breakfast': {'start': '00:00', 'end': '00:01'},
        'brunch': {'start': '00:00', 'end': '00:01'},
        'lunch': {'start': '00:02', 'end': '23:59'},
      },
    });

    final rice = await _send(http, 'POST', '$base/api/ingredients',
        token: adminToken,
        body: {
          'name': 'Rice',
          'unit': 'kg',
          'stockQty': 1.0,
          'lowStockAt': 2.0
        });
    final riceId = rice.json['id'] as int;
    expect(rice.json['stockQty'], 1.0);

    await _send(http, 'POST', '$base/api/recipes', token: adminToken, body: {
      'dishName': 'Dal Rice',
      'ingredients': [
        {'ingredientId': riceId, 'quantity': 0.15}
      ],
    });
    await _send(http, 'POST', '$base/api/menu-categories',
        token: adminToken, body: {'name': 'Normal'});
    await _send(http, 'POST', '$base/api/menu', token: adminToken, body: {
      'date': ymd(day),
      'mealType': 'lunch',
      'category': 'Normal',
      'headcount': 1,
      'items': ['Dal Rice'],
    });

    final m = await _send(http, 'POST', '$base/api/members',
        token: adminToken,
        body: {'type': 'staff', 'name': 'Anil', 'staffId': 'A9'});
    await _send(http, 'POST', '$base/api/topups', token: adminToken, body: {
      'memberId': m.json['id'],
      'lunchUnits': 1,
      'paymentMethod': 'cash'
    });

    final scan = await _send(http, 'POST', '$base/api/scan',
        token: adminToken, body: {'qrCodeId': m.json['qrCodeId']});
    expect(scan.json['outcome'], 'accepted');
    // Headcount was 1 and this is the first plate -> banner fields set.
    expect(scan.json['plannedCount'], 1);
    expect(scan.json['servedCount'], 1);

    final afterScan =
        await _send(http, 'GET', '$base/api/ingredients', token: adminToken);
    final riceAfter = (jsonDecode(afterScan.body) as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((i) => i['id'] == riceId);
    expect(riceAfter['stockQty'], closeTo(0.85, 1e-9)); // 1.0 - 0.15

    // Low-stock notification fired (stock 0.85 <= threshold 2.0).
    final notes =
        await _send(http, 'GET', '$base/api/notifications', token: adminToken);
    expect(
        (jsonDecode(notes.body) as List)
            .any((n) => n['title'].toString().contains('Low stock: Rice')),
        isTrue);

    // Buy 3 kg for Rs. 150 via a manual purchase item.
    final item = await _send(http, 'POST', '$base/api/purchase-schedule',
        token: adminToken,
        body: {
          'date': ymd(day),
          'ingredientId': riceId,
          'quantityNote': '3 kg'
        });
    await _send(http, 'PATCH', '$base/api/purchase-schedule/${item.json['id']}',
        token: adminToken,
        body: {'purchased': true, 'purchasedQty': 3.0, 'purchasedCost': 150.0});

    final afterBuy =
        await _send(http, 'GET', '$base/api/ingredients', token: adminToken);
    final riceBought = (jsonDecode(afterBuy.body) as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((i) => i['id'] == riceId);
    expect(riceBought['stockQty'], closeTo(3.85, 1e-9));

    final expenses =
        await _send(http, 'GET', '$base/api/expenses', token: adminToken);
    expect(
        (jsonDecode(expenses.body) as List)
            .any((e) => e['amount'] == 150.0 && e['category'] == 'ingredients'),
        isTrue);

    // Un-mark -> stock and expense roll back.
    await _send(http, 'PATCH', '$base/api/purchase-schedule/${item.json['id']}',
        token: adminToken, body: {'purchased': false});
    final rolledBack =
        await _send(http, 'GET', '$base/api/ingredients', token: adminToken);
    expect(
        (jsonDecode(rolledBack.body) as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((i) => i['id'] == riceId)['stockQty'],
        closeTo(0.85, 1e-9));
    final expenses2 =
        await _send(http, 'GET', '$base/api/expenses', token: adminToken);
    expect(
        (jsonDecode(expenses2.body) as List).any((e) => e['amount'] == 150.0),
        isFalse);
  });

  test('grace allowance lets a zero balance go negative, then hard-stops',
      () async {
    await _send(http, 'PATCH', '$base/api/settings', token: adminToken, body: {
      'graceAllowanceEnabled': true,
      'graceAllowanceUnits': 1,
      'mealWindows': {
        'breakfast': {'start': '00:00', 'end': '00:01'},
        'brunch': {'start': '00:00', 'end': '00:01'},
        'lunch': {'start': '00:02', 'end': '23:59'},
      },
    });
    final m = await _send(http, 'POST', '$base/api/members',
        token: adminToken,
        body: {'type': 'staff', 'name': 'Ravi', 'staffId': 'S1'});
    final qr = m.json['qrCodeId'] as String;

    // Balance 0, grace 1 → scan accepted on grace, flagged, balance → -1.
    final onGrace = await _send(http, 'POST', '$base/api/scan',
        token: adminToken, body: {'qrCodeId': qr});
    expect(onGrace.json['outcome'], 'accepted');
    expect(onGrace.json['viaGrace'], true);
    expect(onGrace.json['remainingBalance'], -1);

    // A second member with grace OFF and a zero balance → hard stop.
    await _send(http, 'PATCH', '$base/api/settings',
        token: adminToken, body: {'graceAllowanceEnabled': false});
    final m2 = await _send(http, 'POST', '$base/api/members',
        token: adminToken,
        body: {'type': 'staff', 'name': 'Sita', 'staffId': 'S2'});
    final stop = await _send(http, 'POST', '$base/api/scan',
        token: adminToken, body: {'qrCodeId': m2.json['qrCodeId']});
    expect(stop.json['outcome'], 'rejected_zero_balance');
  });

  test('unknown QR code is rejected with a clear outcome', () async {
    final res = await _send(http, 'POST', '$base/api/scan',
        token: adminToken, body: {'qrCodeId': 'nope-nope-nope'});
    expect(res.json['outcome'], 'rejected_unknown_code');
  });

  test('wipeAllData clears every table and re-seeds settings', () async {
    await _send(http, 'POST', '$base/api/members',
        token: adminToken,
        body: {'type': 'staff', 'name': 'Temp', 'staffId': 'T9'});
    expect((await db.select(db.members).get()), isNotEmpty);
    expect((await db.select(db.users).get()), isNotEmpty);

    await db.wipeAllData();

    expect((await db.select(db.members).get()), isEmpty);
    expect((await db.select(db.users).get()), isEmpty);
    expect((await db.select(db.sessions).get()), isEmpty);
    // settings singleton row survives (re-seeded)
    expect((await db.select(db.appSettings).get()).length, 1);
  });

  test('with a cert: plain HTTP on the port, HTTPS on port+1, both serve',
      () async {
    final tls = SelfSignedTls(tmp.path);
    await tls.generate();

    final dual = HostServer(container);
    const p = 8791; // fixed so port+1 is predictable and free
    await dual.start(
      bind: '127.0.0.1',
      port: p,
      securityContext: tls.securityContext(),
    );
    addTearDown(dual.stop);

    expect(dual.httpPort, p);
    expect(dual.httpsPort, p + 1);

    // Client-style plain HTTP works.
    final plain =
        await _send(http, 'GET', 'http://127.0.0.1:$p/api/settings/branding');
    expect(plain.status, 200);

    // HTTPS on port+1 works (accept the self-signed cert).
    final tlsClient = HttpClient()
      ..badCertificateCallback = (_, __, ___) => true;
    final req = await tlsClient
        .getUrl(Uri.parse('https://127.0.0.1:${p + 1}/api/settings/branding'));
    final res = await req.close();
    expect(res.statusCode, 200);
    await res.drain<void>();
    tlsClient.close(force: true);
  });

  test('cache-control: no-store on /api, no-cache on the static bundle',
      () async {
    final apiRes = await _send(http, 'GET', '$base/api/settings/branding');
    expect(apiRes.status, 200);

    final rawApi =
        await (await http.getUrl(Uri.parse('$base/api/settings/branding')))
            .close();
    expect(rawApi.headers.value('cache-control'), 'no-store');
    await rawApi.drain<void>();

    final rawStatic = await (await http.getUrl(Uri.parse('$base/'))).close();
    expect(rawStatic.headers.value('cache-control'), 'no-cache');
    await rawStatic.drain<void>();
  });

  test('desktop-admin web bundle is served at / and its assets', () async {
    final index = await _send(http, 'GET', '$base/');
    expect(index.status, 200);
    expect(index.body, contains('<h1>admin</h1>'));

    final css = await _send(http, 'GET', '$base/styles.css');
    expect(css.status, 200);
    expect(css.body, contains('color:#000'));

    // Unknown path under the SPA still resolves (hash routing → index.html).
    final missing = await _send(http, 'GET', '$base/nope');
    expect(missing.status, anyOf(200, 404));
  });

  test('?token= query param authenticates a browser file download', () async {
    final m = await _send(http, 'POST', '$base/api/members',
        token: adminToken,
        body: {'type': 'staff', 'name': 'Q', 'staffId': 'Q1'});
    final id = m.json['id'];

    Future<int> statusOf(String url) async {
      final req = await http.getUrl(Uri.parse(url));
      final res = await req.close();
      await res.drain<void>();
      return res.statusCode;
    }

    expect(await statusOf('$base/api/members/$id/qr?token=$adminToken'), 200);
    expect(await statusOf('$base/api/members/$id/qr'), 401);
  });

  test('scanner role cannot reach admin-only member creation', () async {
    await _send(http, 'POST', '$base/api/users', token: adminToken, body: {
      'username': 'kiosk',
      'password': 'kiosk-password-1',
      'role': 'scanner',
    });
    final scannerToken = await _login(http, base, 'kiosk', 'kiosk-password-1');
    final res = await _send(http, 'POST', '$base/api/members',
        token: scannerToken, body: {'type': 'student', 'name': 'X'});
    expect(res.status, 403);
    expect(res.json['error'], 'forbidden');
  });
}

Future<String> _login(
    HttpClient http, String base, String username, String password) async {
  final res = await _send(http, 'POST', '$base/api/auth/login',
      body: {'username': username, 'password': password});
  expect(res.status, 200, reason: 'login for $username: ${res.body}');
  return res.json['token'] as String;
}

class _Res {
  _Res(this.status, this.body);
  final int status;
  final String body;
  Map<String, dynamic> get json => jsonDecode(body) as Map<String, dynamic>;
}

Future<_Res> _send(
  HttpClient http,
  String method,
  String url, {
  Object? body,
  String? token,
}) async {
  final req = await http.openUrl(method, Uri.parse(url));
  if (token != null) req.headers.set('authorization', 'Bearer $token');
  if (body != null) {
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(jsonEncode(body)));
  }
  final res = await req.close();
  final text = await res.transform(utf8.decoder).join();
  return _Res(res.statusCode, text);
}
