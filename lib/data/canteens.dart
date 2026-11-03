import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/errors.dart';
import '../core/logging.dart';
import 'store.dart';

/// Creating and finding canteens — the operations that happen before a phone
/// has an active canteen, so they cannot go through [Store] (ADR 0006).
class CanteenService {
  CanteenService(this._db, this._auth, {Random? random})
      : _random = random ?? Random.secure();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Random _random;
  final _log = log('canteens');

  /// No 0/O/1/I: the code is read aloud and typed from a screen.
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const codeLength = 8;

  String newCode() => String.fromCharCodes([
        for (var i = 0; i < codeLength; i++)
          _alphabet.codeUnitAt(_random.nextInt(_alphabet.length)),
      ]);

  /// Liberal in what people type: case, spaces and dashes don't matter.
  static String normalise(String typed) =>
      typed.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// The canteen's name, or [NotFoundException]. Asks the server: joining
  /// needs the network anyway and a stale cached answer would mislead.
  Future<String> nameOf(String typedCode) async {
    final code = normalise(typedCode);
    if (code.length != codeLength) {
      throw const NotFoundException(ErrorCode.canteenNotFound);
    }
    try {
      final snap = await Store.rootDoc(_db, code)
          .get(const GetOptions(source: Source.server));
      if (!snap.exists) {
        throw const NotFoundException(ErrorCode.canteenNotFound);
      }
      return snap.data()?['name'] as String? ?? code;
    } on FirebaseException catch (e) {
      throw mapFirebaseError(e);
    }
  }

  /// Email sign-in before any canteen is active. Registering and signing in
  /// are separate on purpose: a wrong password must not silently create an
  /// account.
  Future<void> signInWithEmail(String email, String password,
      {required bool register}) async {
    final address = email.trim();
    if (register) {
      await _auth.createUserWithEmailAndPassword(
          email: address, password: password);
    } else {
      await _auth.signInWithEmailAndPassword(
          email: address, password: password);
    }
  }

  /// Creates a canteen owned by the signed-in person, who becomes its admin.
  /// A transaction on purpose: it needs the network anyway, and two people
  /// drawing the same code must not both win.
  Future<({String code, String name})> create(String name) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const ValidationException(ErrorCode.signInRequired);
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final clean = name.trim();
    try {
      for (var attempt = 0; attempt < 5; attempt++) {
        final code = newCode();
        final root = Store.rootDoc(_db, code);
        final created = await _db.runTransaction((tx) async {
          if ((await tx.get(root)).exists) return false;
          tx
            ..set(root, {'name': clean, 'ownerUid': user.uid, 'createdAt': now})
            ..set(root.collection(Col.onlineUsers).doc(user.uid), {
              'email': user.email ?? '',
              'role': 'admin',
              'status': 'active',
              'createdAt': now,
            });
          return true;
        });
        if (created) {
          _log.warning('canteen_created code=$code uid=${user.uid}');
          return (code: code, name: clean);
        }
      }
    } on FirebaseException catch (e) {
      throw mapFirebaseError(e);
    }
    throw const InternalException(); // five collisions in 32^8: not luck
  }
}
