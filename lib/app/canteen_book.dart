import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bootstrap.dart';

/// A canteen this phone has joined or created.
class JoinedCanteen {
  const JoinedCanteen(
      {required this.code, required this.name, required this.lastUsed});

  factory JoinedCanteen.fromJson(Map<String, dynamic> j) => JoinedCanteen(
        code: j['code'] as String,
        name: j['name'] as String? ?? j['code'] as String,
        lastUsed:
            DateTime.tryParse(j['lastUsed'] as String? ?? '') ?? DateTime.now(),
      );

  final String code;
  final String name;
  final DateTime lastUsed;

  Map<String, dynamic> toJson() =>
      {'code': code, 'name': name, 'lastUsed': lastUsed.toIso8601String()};
}

/// Which canteens this phone knows, and which one is active (ADR 0006).
/// Saved logins live in `CredentialStore`, keyed by the same canteen code.
class CanteenBookState {
  const CanteenBookState({this.canteens = const [], this.activeCode});

  final List<JoinedCanteen> canteens;
  final String? activeCode;

  JoinedCanteen? get active =>
      canteens.where((c) => c.code == activeCode).firstOrNull;
}

class CanteenBook extends Notifier<CanteenBookState> {
  static const _key = 'canteen_book';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  CanteenBookState build() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const CanteenBookState();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final canteens = [
        for (final c in j['canteens'] as List<dynamic>)
          JoinedCanteen.fromJson(c as Map<String, dynamic>),
      ];
      final active = j['active'] as String?;
      return CanteenBookState(
        canteens: canteens,
        activeCode: canteens.any((c) => c.code == active) ? active : null,
      );
    } catch (_) {
      return const CanteenBookState(); // corrupt entry: start at Welcome
    }
  }

  /// Adds (or refreshes) a canteen and makes it the active one.
  Future<void> activate(String code, String name) async {
    final others = state.canteens.where((c) => c.code != code);
    await _save(CanteenBookState(canteens: [
      JoinedCanteen(code: code, name: name, lastUsed: DateTime.now().toUtc()),
      ...others,
    ], activeCode: code));
  }

  /// Back to the Welcome screen without forgetting any canteen.
  Future<void> deactivate() =>
      _save(CanteenBookState(canteens: state.canteens));

  /// Forgets a canteen on this phone. Nothing is deleted in Firebase.
  Future<void> leave(String code) async {
    await _save(CanteenBookState(
      canteens: [
        for (final c in state.canteens)
          if (c.code != code) c,
      ],
      activeCode: state.activeCode == code ? null : state.activeCode,
    ));
  }

  Future<void> _save(CanteenBookState next) async {
    state = next;
    await _prefs.setString(
        _key,
        jsonEncode({
          'canteens': [for (final c in next.canteens) c.toJson()],
          'active': next.activeCode,
        }));
  }
}

final canteenBookProvider =
    NotifierProvider<CanteenBook, CanteenBookState>(CanteenBook.new);

/// The code of the active canteen; null → Welcome screen. Everything that
/// reads canteen data watches this, so switching rebuilds it all.
final activeCanteenProvider =
    Provider<String?>((ref) => ref.watch(canteenBookProvider).activeCode);

/// Set when someone creates a canteen "from a backup": the new admin lands on
/// the backup screen once, instead of an empty dashboard.
class StartFromBackup extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void set(bool value) => state = value;
}

final startFromBackupProvider =
    NotifierProvider<StartFromBackup, bool>(StartFromBackup.new);
