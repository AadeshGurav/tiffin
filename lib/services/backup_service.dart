import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pointycastle/export.dart';

import '../core/errors.dart';
import '../core/logging.dart';
import '../data/store.dart';
import 'legacy_import.dart';

/// What a `.tiffin` file says about itself.
class BackupManifest {
  const BackupManifest({
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.encrypted,
    required this.rowCounts,
    this.salt,
    this.nonce,
  });

  factory BackupManifest.fromJson(Map<String, dynamic> j) => BackupManifest(
        schemaVersion: (j['schemaVersion'] as num).toInt(),
        appVersion: j['appVersion'] as String? ?? 'unknown',
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '')?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0),
        encrypted: j['encrypted'] as bool? ?? false,
        rowCounts: (j['rowCounts'] as Map<String, dynamic>? ?? const {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        salt: j['salt'] as String?,
        nonce: j['nonce'] as String?,
      );

  final int schemaVersion;
  final String appVersion;
  final DateTime createdAt;
  final bool encrypted;

  /// Per-collection counts, so a restore can report what it actually put back
  /// instead of a bare "done".
  final Map<String, int> rowCounts;

  final String? salt;
  final String? nonce;

  int get totalRows => rowCounts.values.fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'appVersion': appVersion,
        'createdAt': createdAt.toIso8601String(),
        'encrypted': encrypted,
        'rowCounts': rowCounts,
        if (salt != null) 'salt': salt,
        if (nonce != null) 'nonce': nonce,
      };
}

/// What a backup file holds once opened: every data collection, plus the
/// settings document.
class BackupContents {
  const BackupContents({required this.collections, this.settings});

  final Map<String, List<Json>> collections;
  final Json? settings;
}

/// Full-fidelity backup and restore — the way to move a canteen to a new
/// Firebase project, and a copy the admin owns outside Google's.
///
/// Format 2 (this build): a zip with a manifest and `data.json`
/// (`{collection: [documents with id]}`). Format 1 files — the SQLite snapshot
/// the LAN-host build wrote — are still read, through [LegacyImport]; that is
/// how an existing canteen's records cross over.
///
/// A passphrase is optional and offered prominently, not forced: the file
/// carries member names and password hashes, but a mandatory passphrase turns
/// "forgot it" into permanent data loss, and losing the data is the worse
/// failure of the two.
class BackupService {
  BackupService(
    this._store, {
    required this.appVersion,
    required this.workingDirectory,
  });

  final Store _store;
  final String appVersion;

  /// Scratch space for unpacking a format-1 SQLite file.
  final Directory workingDirectory;
  final _log = log('backup');

  static const manifestEntry = 'manifest.json';
  static const dataEntry = 'data.json';
  static const legacyDatabaseEntry = 'tiffin.sqlite';
  static const fileExtension = 'tiffin';

  /// Bumping this rejects files a newer app wrote, rather than misreading them.
  static const formatVersion = 2;

  /// Firestore allows 500 writes per batch; stay clear of it.
  static const _batchSize = 400;

  Future<List<int>> export({String? passphrase}) async {
    final collections = <String, List<Json>>{
      for (final c in Col.data) c: await _store.fresh(_store.col(c)),
    };
    final settings = await _store.freshDoc(_store.doc(Col.meta, 'settings'));
    var bytes = Uint8List.fromList(utf8.encode(jsonEncode({
      'collections': collections,
      'settings': settings,
    })));

    String? salt;
    String? nonce;
    if (passphrase != null && passphrase.isNotEmpty) {
      final saltBytes = _randomBytes(16);
      final nonceBytes = _randomBytes(12);
      bytes = _encrypt(bytes, passphrase, saltBytes, nonceBytes);
      salt = base64Encode(saltBytes);
      nonce = base64Encode(nonceBytes);
    }

    final manifest = BackupManifest(
      schemaVersion: formatVersion,
      appVersion: appVersion,
      createdAt: DateTime.now().toUtc(),
      encrypted: salt != null,
      rowCounts: collections.map((k, v) => MapEntry(k, v.length)),
      salt: salt,
      nonce: nonce,
    );
    final manifestBytes = utf8.encode(const JsonEncoder.withIndent('  ')
        .convert({'format': formatVersion, ...manifest.toJson()}));
    final archive = Archive()
      ..addFile(ArchiveFile(manifestEntry, manifestBytes.length, manifestBytes))
      ..addFile(ArchiveFile(dataEntry, bytes.length, bytes));
    _log.info('backup_exported rows=${manifest.totalRows} '
        'encrypted=${manifest.encrypted}');
    return ZipEncoder().encode(archive);
  }

  String fileName({DateTime? now}) =>
      'tiffin-backup-${DateFormat('yyyy-MM-dd-HHmm').format(now ?? DateTime.now())}'
      '.$fileExtension';

  /// Reads and validates a backup without touching any data, so the UI can
  /// show what it holds before anyone commits to replacing anything.
  BackupManifest inspect(List<int> bytes) => _open(bytes).manifest;

  /// Decrypts and decodes [bytes] fully — every failure (wrong passphrase,
  /// truncated file, wrong file) happens here, before [restore] deletes a
  /// single document.
  Future<BackupContents> read(List<int> bytes, {String? passphrase}) async {
    final opened = _open(bytes);
    final manifest = opened.manifest;
    var payload = opened.payload;
    if (manifest.encrypted) {
      if (passphrase == null || passphrase.isEmpty) {
        throw const ValidationException(ErrorCode.backupNeedsPassphrase);
      }
      payload = _decrypt(payload, passphrase, base64Decode(manifest.salt!),
          base64Decode(manifest.nonce!));
    }

    if (opened.legacy) {
      if (!_looksLikeSqlite(payload)) {
        throw const ValidationException(ErrorCode.backupUnreadable);
      }
      if (!workingDirectory.existsSync()) {
        workingDirectory.createSync(recursive: true);
      }
      final legacy = await const LegacyImport().read(payload, workingDirectory);
      return BackupContents(
          collections: legacy.collections, settings: legacy.settings);
    }

    try {
      final json = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
      return BackupContents(
        collections: {
          for (final e in (json['collections'] as Map<String, dynamic>).entries)
            if (Col.data.contains(e.key))
              e.key: [
                for (final d in e.value as List<dynamic>)
                  Map<String, dynamic>.from(d as Map)
              ],
        },
        settings: json['settings'] == null
            ? null
            : Map<String, dynamic>.from(json['settings'] as Map),
      );
    } catch (_) {
      throw const ValidationException(ErrorCode.backupUnreadable);
    }
  }

  /// Replaces every data collection with [contents]. Needs the network: this
  /// is thousands of writes, and a half-synced restore queued on one phone is
  /// worse than a clear "connect first".
  ///
  /// When [requireEmpty] is set (first-run import) it refuses to run over a
  /// canteen that already has members, instead of silently merging two.
  Future<int> restore(BackupContents contents,
      {bool requireEmpty = false}) async {
    if (!_store.online) {
      throw const ValidationException(ErrorCode.needsInternet);
    }
    if (requireEmpty &&
        (await _store.fresh(_store.col(Col.members).limit(1))).isNotEmpty) {
      throw const ConflictException(ErrorCode.backupTargetNotEmpty);
    }

    final writes = <void Function(WriteBatch b)>[];
    for (final c in Col.data) {
      for (final existing in await _store.fresh(_store.col(c))) {
        final ref = _store.doc(c, existing['id'] as String);
        writes.add((b) => b.delete(ref));
      }
    }
    var restored = 0;
    for (final MapEntry(key: c, value: docs) in contents.collections.entries) {
      for (final d in docs) {
        final id = d['id'] as String;
        final body = Map<String, dynamic>.from(d)..remove('id');
        final ref = _store.doc(c, id);
        writes.add((b) => b.set(ref, body));
        restored++;
      }
    }
    if (contents.settings != null) {
      final body = Map<String, dynamic>.from(contents.settings!)..remove('id');
      final ref = _store.doc(Col.meta, 'settings');
      writes.add((b) => b.set(ref, body));
    }

    // Deletes run before sets (they were queued first), so a document present
    // in both ends up with the backup's copy.
    for (var i = 0; i < writes.length; i += _batchSize) {
      final b = _store.batch();
      for (final w in writes.skip(i).take(_batchSize)) {
        w(b);
      }
      await _store.commit(b, 'backup.restore ${i ~/ _batchSize}');
    }
    _log.warning('backup_restored docs=$restored');
    return restored;
  }

  // ---- internals --------------------------------------------------------

  ({BackupManifest manifest, Uint8List payload, bool legacy}) _open(
      List<int> bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const ValidationException(ErrorCode.backupNotTiffin);
    }
    ArchiveFile? entry(String name) =>
        archive.files.where((f) => f.name == name).firstOrNull;

    final manifestFile = entry(manifestEntry);
    if (manifestFile == null) {
      throw const ValidationException(ErrorCode.backupNotTiffin);
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(manifestFile.content as List<int>))
          as Map<String, dynamic>;
    } catch (_) {
      throw const ValidationException(ErrorCode.backupUnreadable);
    }
    final format = (json['format'] as num?)?.toInt() ?? 1;
    if (format > formatVersion) {
      throw const ValidationException(ErrorCode.backupNewerVersion);
    }
    final legacy = format < 2;
    final payloadFile = entry(legacy ? legacyDatabaseEntry : dataEntry);
    if (payloadFile == null) {
      throw const ValidationException(ErrorCode.backupUnreadable);
    }
    return (
      manifest: BackupManifest.fromJson(json),
      payload: Uint8List.fromList(payloadFile.content as List<int>),
      legacy: legacy,
    );
  }

  static bool _looksLikeSqlite(Uint8List bytes) {
    const header = 'SQLite format 3';
    if (bytes.length < header.length) return false;
    return String.fromCharCodes(bytes.sublist(0, header.length)) == header;
  }

  Uint8List _randomBytes(int n) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => random.nextInt(256)));
  }

  /// PBKDF2-HMAC-SHA256 then AES-GCM, matching the iteration count the
  /// password hashes already use.
  KeyParameter _deriveKey(String passphrase, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, 100000, 32));
    return KeyParameter(
        derivator.process(Uint8List.fromList(utf8.encode(passphrase))));
  }

  Uint8List _encrypt(
      Uint8List data, String passphrase, Uint8List salt, Uint8List nonce) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
          true,
          AEADParameters(
              _deriveKey(passphrase, salt), 128, nonce, Uint8List(0)));
    return cipher.process(data);
  }

  Uint8List _decrypt(
      Uint8List data, String passphrase, Uint8List salt, Uint8List nonce) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
          false,
          AEADParameters(
              _deriveKey(passphrase, salt), 128, nonce, Uint8List(0)));
    try {
      return cipher.process(data);
    } catch (_) {
      // GCM authentication failing is overwhelmingly a wrong password, and
      // saying so beats surfacing a MAC error to a canteen admin.
      throw const ValidationException(ErrorCode.backupWrongPassphrase);
    }
  }
}
