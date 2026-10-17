import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:tiffin/core/errors.dart';
import 'package:tiffin/core/meal_type.dart';
import 'package:tiffin/data/backend.dart';
import 'package:tiffin/domain/member.dart';
import 'package:tiffin/services/backup_service.dart';

import 'support/fake_backend.dart';

/// Backup is the admin's own copy of the canteen, and the bridge from the
/// LAN-host build: a v1 `.tiffin` (SQLite inside) must land in Firestore with
/// its accounts still able to sign in.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  late Backend b;

  setUp(() async {
    b = (await fakeBackend()).backend;
    await signInAdmin(b);
  });

  Future<Member> member(String name, {int lunch = 0}) =>
      b.createMember(MemberDraft(
          type: 'staff', name: name, balances: UnitCounts(lunch: lunch)));

  test('every document survives a plain round trip', () async {
    final asha = await member('Asha', lunch: 4);
    await member('Ravi');
    final bytes = await b.backups.export();

    // Into a different, empty canteen.
    final other = (await fakeBackend()).backend;
    final restored =
        await other.backups.restore(await other.backups.read(bytes));
    expect(restored, greaterThanOrEqualTo(3)); // 2 members + the admin
    final back = await other.getMember(asha.id);
    expect(back.name, 'Asha');
    expect(back.balances.lunch, 4);
    expect((await other.login('admin', 'lunchtime99')).username, 'admin',
        reason: 'accounts come across and still sign in');
  });

  test('restore replaces what was there instead of merging', () async {
    final bytes = await b.backups.export();
    await member('Added after the backup');
    await b.backups.restore(await b.backups.read(bytes));
    expect(await b.listMembers(), isEmpty);
  });

  test('an encrypted backup round-trips with its password only', () async {
    await member('Asha');
    final bytes = await b.backups.export(passphrase: 'canteen-key');
    expect(utf8.decode(bytes, allowMalformed: true), isNot(contains('Asha')),
        reason: 'member names are not readable in a sealed file');
    expect(b.backups.inspect(bytes).encrypted, isTrue);

    await expectLater(
        b.backups.read(bytes),
        throwsA(isA<ValidationException>()
            .having((e) => e.code, 'code', ErrorCode.backupNeedsPassphrase)));
    await expectLater(
        b.backups.read(bytes, passphrase: 'wrong'),
        throwsA(isA<ValidationException>()
            .having((e) => e.code, 'code', ErrorCode.backupWrongPassphrase)));
    final contents = await b.backups.read(bytes, passphrase: 'canteen-key');
    expect(contents.collections['members'], hasLength(1));
  });

  test('a file that is not a backup is refused before anything is deleted',
      () async {
    await member('Asha');
    await expectLater(
        b.backups.read([1, 2, 3]),
        throwsA(isA<ValidationException>()
            .having((e) => e.code, 'code', ErrorCode.backupNotTiffin)));
    expect(await b.listMembers(), hasLength(1));
  });

  test('a backup from a newer format is refused rather than half-read', () {
    final manifest =
        utf8.encode(jsonEncode({'format': 99, 'schemaVersion': 99}));
    final zip = ZipEncoder().encode(Archive()
      ..addFile(ArchiveFile('manifest.json', manifest.length, manifest)));
    expect(
        () => b.backups.inspect(zip),
        throwsA(isA<ValidationException>()
            .having((e) => e.code, 'code', ErrorCode.backupNewerVersion)));
  });

  test('first-run import refuses to merge into a canteen that has members',
      () async {
    final bytes = await b.backups.export();
    await member('Already here');
    await expectLater(
        b.backups.restore(await b.backups.read(bytes), requireEmpty: true),
        throwsA(isA<ConflictException>()));
  });

  group('a v1 backup from the LAN-host build', () {
    late List<int> legacy;

    // The v1 hash format is the one AuthService still writes, so it can
    // produce a legacy row's hash too.
    setUp(() => legacy = _legacyBackup(b.auth.hashPassword('oldpassword1')));

    test('imports members, balances, accounts and settings', () async {
      final fresh = (await fakeBackend()).backend;
      final contents = await fresh.backups.read(legacy);
      await fresh.backups.restore(contents, requireEmpty: true);

      final m = await fresh.getMember('7');
      expect(m.name, 'Meera');
      expect(m.balances.lunch, 5);
      expect(m.qrCodeId, 'abc123def456', reason: 'printed cards keep working');
      expect((await fresh.getSettings()).appName, 'Hostel Mess');

      // The v1 hash format is unchanged, so the old password still works.
      expect((await fresh.login('owner', 'oldpassword1')).username, 'owner');
    });

    test('history keeps its references and scans keep their meal', () async {
      final fresh = (await fakeBackend()).backend;
      await fresh.backups.restore(await fresh.backups.read(legacy));
      final topups = await fresh.listTopups();
      expect(topups.single.memberId, '7');
      expect(topups.single.amount, 200);
      final scans = await fresh.recentScans();
      expect(scans.single.mealType, MealType.lunch);
      expect(scans.single.memberName, 'Meera');
    });
  });
}

/// A minimal format-1 backup: the zip a v2.x host exported, with a SQLite
/// snapshot using that build's table and column names.
List<int> _legacyBackup(String hash) {
  final dir = Directory.systemTemp.createTempSync('tiffin-legacy');
  final file = File('${dir.path}/tiffin.sqlite');
  final db = sqlite3.open(file.path);
  const t = 1760000000; // seconds, as drift stored DateTime
  db
    ..execute('CREATE TABLE users (id INTEGER, username TEXT, password_hash '
        'TEXT, role TEXT, status TEXT, created_at INTEGER, updated_at INTEGER)')
    ..execute("INSERT INTO users VALUES (1, 'owner', '$hash', 'admin', "
        "'active', $t, $t)")
    ..execute('CREATE TABLE members (id INTEGER, type TEXT, name TEXT, '
        'class_name TEXT, roll_number TEXT, staff_id TEXT, qr_code_id TEXT, '
        'lunch_balance INTEGER, breakfast_balance INTEGER, brunch_balance '
        'INTEGER, grace_allowance_override INTEGER, category TEXT, status TEXT, '
        'created_at INTEGER, updated_at INTEGER)')
    ..execute("INSERT INTO members VALUES (7, 'student', 'Meera', '8A', '12', "
        "NULL, 'abc123def456', 5, 0, 0, NULL, 'Normal', 'active', $t, $t)")
    ..execute('CREATE TABLE topups (id INTEGER, member_id INTEGER, lunch_units '
        'INTEGER, breakfast_units INTEGER, brunch_units INTEGER, amount REAL, '
        'payment_method TEXT, payment_status TEXT, bill_pdf_path TEXT, '
        'upi_qr_path TEXT, created_by TEXT, created_at INTEGER, reversed '
        'INTEGER, reversed_at INTEGER, reversed_by TEXT)')
    ..execute("INSERT INTO topups VALUES (3, 7, 5, 0, 0, 200.0, 'cash', "
        "'confirmed', NULL, NULL, 'owner', $t, 0, NULL, NULL)")
    ..execute('CREATE TABLE scans (id INTEGER, member_id INTEGER, meal_type '
        'TEXT, scanned_at INTEGER, result TEXT, via_grace INTEGER, reversed '
        'INTEGER, reversed_at INTEGER, reversed_by TEXT, member_category TEXT, '
        'consumed_json TEXT)')
    ..execute("INSERT INTO scans VALUES (9, 7, 'lunch', $t, 'accepted', 0, 0, "
        "NULL, NULL, 'Normal', NULL)")
    ..execute('CREATE TABLE app_settings (id INTEGER, grace_allowance_enabled '
        'INTEGER, grace_allowance_units INTEGER, reversal_window_minutes '
        'INTEGER, breakfast_start TEXT, breakfast_end TEXT, lunch_start TEXT, '
        'lunch_end TEXT, brunch_start TEXT, brunch_end TEXT, local_timezone '
        'TEXT, upi_id TEXT, upi_payee_name TEXT, lunch_price REAL, '
        'breakfast_price REAL, brunch_price REAL, app_name TEXT, '
        'prep_lead_minutes INTEGER, purchase_lead_days INTEGER)')
    ..execute("INSERT INTO app_settings VALUES (0, 0, 0, 10, '07:00', '09:30', "
        "'12:00', '14:30', '09:00', '12:00', 'Asia/Kolkata', '', '', 40.0, "
        "25.0, 50.0, 'Hostel Mess', 60, 1)")
    ..close();
  final sqliteBytes = file.readAsBytesSync();
  dir.deleteSync(recursive: true);

  final manifest = utf8.encode(jsonEncode({
    'format': 1,
    'schemaVersion': 8,
    'appVersion': '2.1.0',
    'createdAt': '2026-10-01T10:00:00Z',
    'encrypted': false,
    'rowCounts': {'members': 1},
  }));
  return ZipEncoder().encode(Archive()
    ..addFile(
        ArchiveFile(BackupService.manifestEntry, manifest.length, manifest))
    ..addFile(ArchiveFile(
        BackupService.legacyDatabaseEntry, sqliteBytes.length, sqliteBytes)));
}
