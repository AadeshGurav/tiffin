import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/errors.dart';
import '../core/logging.dart';
import '../data/store.dart';
import '../domain/settings.dart';

/// The single global settings document, `meta/settings` (PRD §6.8). A missing
/// document — a canteen that has never saved settings — reads as the defaults,
/// so there is no seeding step to forget.
class SettingsService {
  SettingsService(this._store);

  final Store _store;
  final _log = log('settings');

  static final _hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  static const defaults = SettingsSnapshot(
    graceAllowanceEnabled: false,
    graceAllowanceUnits: 0,
    reversalWindowMinutes: 10,
    mealWindows: {
      'breakfast': MealWindowConfig(start: '07:00', end: '09:30'),
      'lunch': MealWindowConfig(start: '12:00', end: '14:30'),
      'brunch': MealWindowConfig(start: '09:00', end: '12:00'),
    },
    // A canteen's meal windows are local wall-clock times, so UTC would be
    // wrong everywhere it runs; this is the deployment's own zone.
    localTimezone: 'Asia/Kolkata',
    upiId: '',
    upiPayeeName: '',
    unitPrices: UnitPrices(lunch: 0, breakfast: 0, brunch: 0),
    appName: 'Tiffin',
    prepLeadMinutes: 60,
    purchaseLeadDays: 1,
  );

  DocumentRef get _ref => _store.doc(Col.meta, 'settings');

  Future<SettingsSnapshot> read() async {
    final stored = await _store.cachedDoc(_ref) ?? await _freshOrNull();
    if (stored == null) return defaults;
    return SettingsSnapshot.fromJson({...defaults.toJson(), ...stored});
  }

  Future<Json?> _freshOrNull() async {
    try {
      return await _store.freshDoc(_ref);
    } catch (_) {
      return null; // offline and never synced: the defaults are the answer
    }
  }

  /// Whether the canteen lets people sign in with online (email) accounts.
  Future<bool> onlineAccountsEnabled() async =>
      (await _store.cachedDoc(_ref) ?? await _freshOrNull())?['onlineAccounts']
          as bool? ??
      false;

  Future<void> setOnlineAccountsEnabled(bool enabled) async {
    final b = _store.batch()
      ..set(_ref, {'onlineAccounts': enabled}, SetOptions(merge: true));
    await _store.commit(b, 'settings.onlineAccounts');
    _log.info('online_accounts enabled=$enabled');
  }

  Future<String> readAppName() async => (await read()).appName;

  /// Every IANA zone the bundled tz database knows — backs the Settings
  /// timezone dropdown so a value it accepts is the only value pickable.
  List<String> availableTimezones() =>
      tz.timeZoneDatabase.locations.keys.toList()..sort();

  /// Applies a partial update. Meal windows merge (send just `lunch`); each
  /// window's start must be before its end. A bad timezone or HH:MM is
  /// rejected here so it can never reach the scan path and crash it.
  Future<SettingsSnapshot> update(SettingsPatch patch) async {
    for (final v in [
      patch.graceAllowanceUnits,
      patch.reversalWindowMinutes,
      patch.prepLeadMinutes,
      patch.purchaseLeadDays,
    ]) {
      if (v != null && v < 0) {
        throw const ValidationException(ErrorCode.settingsNegative);
      }
    }
    final prices = patch.unitPrices;
    if (prices != null &&
        [prices.lunch, prices.breakfast, prices.brunch].any((p) => p < 0)) {
      throw const ValidationException(ErrorCode.settingsNegative);
    }
    if (patch.localTimezone != null) {
      try {
        tz.getLocation(patch.localTimezone!);
      } catch (_) {
        throw ValidationException(
            ErrorCode.settingsBadTimezone, {'name': patch.localTimezone!});
      }
    }
    if (patch.appName != null && patch.appName!.trim().isEmpty) {
      throw const ValidationException(ErrorCode.settingsBlank);
    }
    patch.mealWindows?.forEach((meal, w) {
      for (final v in [w.start, w.end]) {
        if (!_hhmm.hasMatch(v)) {
          throw ValidationException(ErrorCode.settingsBadTime, {'meal': meal});
        }
      }
      if (w.start.compareTo(w.end) >= 0) {
        throw ValidationException(ErrorCode.settingsWindowOrder,
            {'meal': meal, 'start': w.start, 'end': w.end});
      }
    });

    final current = await read();
    final json = patch.toJson();
    if (patch.mealWindows != null) {
      json['mealWindows'] = {
        ...current.toJson()['mealWindows'] as Map<String, dynamic>,
        ...json['mealWindows'] as Map<String, dynamic>,
      };
    }
    final b = _store.batch()..set(_ref, json, SetOptions(merge: true));
    await _store.commit(b, 'settings.update');
    _log.info('updated fields=${patch.changedFields}');
    return read();
  }
}

typedef DocumentRef = DocumentReference<Json>;

/// A partial settings update (PRD §6.8). Every field optional.
class SettingsPatch {
  const SettingsPatch({
    this.graceAllowanceEnabled,
    this.graceAllowanceUnits,
    this.reversalWindowMinutes,
    this.mealWindows,
    this.localTimezone,
    this.upiId,
    this.upiPayeeName,
    this.unitPrices,
    this.appName,
    this.prepLeadMinutes,
    this.purchaseLeadDays,
    this.enforceAppearance,
    this.appearanceTheme,
    this.appearanceMode,
    this.appearanceMotion,
  });

  factory SettingsPatch.fromJson(Map<String, dynamic> j) => SettingsPatch(
        graceAllowanceEnabled: j['graceAllowanceEnabled'] as bool?,
        graceAllowanceUnits: (j['graceAllowanceUnits'] as num?)?.toInt(),
        reversalWindowMinutes: (j['reversalWindowMinutes'] as num?)?.toInt(),
        mealWindows: (j['mealWindows'] as Map<String, dynamic>?)?.map(
          (k, v) =>
              MapEntry(k, MealWindowConfig.fromJson(v as Map<String, dynamic>)),
        ),
        localTimezone: j['localTimezone'] as String?,
        upiId: j['upiId'] as String?,
        upiPayeeName: j['upiPayeeName'] as String?,
        unitPrices: j['unitPrices'] == null
            ? null
            : UnitPrices.fromJson(j['unitPrices'] as Map<String, dynamic>),
        appName: j['appName'] as String?,
        prepLeadMinutes: (j['prepLeadMinutes'] as num?)?.toInt(),
        purchaseLeadDays: (j['purchaseLeadDays'] as num?)?.toInt(),
        enforceAppearance: j['enforceAppearance'] as bool?,
        appearanceTheme: j['appearanceTheme'] as String?,
        appearanceMode: j['appearanceMode'] as String?,
        appearanceMotion: j['appearanceMotion'] as bool?,
      );

  final bool? graceAllowanceEnabled;
  final int? graceAllowanceUnits;
  final int? reversalWindowMinutes;
  final Map<String, MealWindowConfig>? mealWindows;
  final String? localTimezone;
  final String? upiId;
  final String? upiPayeeName;
  final UnitPrices? unitPrices;
  final String? appName;
  final int? prepLeadMinutes;
  final int? purchaseLeadDays;
  final bool? enforceAppearance;
  final String? appearanceTheme;
  final String? appearanceMode;
  final bool? appearanceMotion;

  /// Wire form for the client → host PATCH. Only set fields are included, so
  /// the host's partial-update semantics are preserved.
  Map<String, dynamic> toJson() => {
        if (graceAllowanceEnabled != null)
          'graceAllowanceEnabled': graceAllowanceEnabled,
        if (graceAllowanceUnits != null)
          'graceAllowanceUnits': graceAllowanceUnits,
        if (reversalWindowMinutes != null)
          'reversalWindowMinutes': reversalWindowMinutes,
        if (mealWindows != null)
          'mealWindows': mealWindows!.map((k, v) => MapEntry(k, v.toJson())),
        if (localTimezone != null) 'localTimezone': localTimezone,
        if (upiId != null) 'upiId': upiId,
        if (upiPayeeName != null) 'upiPayeeName': upiPayeeName,
        if (unitPrices != null) 'unitPrices': unitPrices!.toJson(),
        if (appName != null) 'appName': appName,
        if (prepLeadMinutes != null) 'prepLeadMinutes': prepLeadMinutes,
        if (purchaseLeadDays != null) 'purchaseLeadDays': purchaseLeadDays,
        if (enforceAppearance != null) 'enforceAppearance': enforceAppearance,
        if (appearanceTheme != null) 'appearanceTheme': appearanceTheme,
        if (appearanceMode != null) 'appearanceMode': appearanceMode,
        if (appearanceMotion != null) 'appearanceMotion': appearanceMotion,
      };

  List<String> get changedFields => {
        if (graceAllowanceEnabled != null) 'graceAllowanceEnabled',
        if (graceAllowanceUnits != null) 'graceAllowanceUnits',
        if (reversalWindowMinutes != null) 'reversalWindowMinutes',
        if (mealWindows != null) 'mealWindows',
        if (localTimezone != null) 'localTimezone',
        if (upiId != null) 'upiId',
        if (upiPayeeName != null) 'upiPayeeName',
        if (unitPrices != null) 'unitPrices',
        if (appName != null) 'appName',
        if (prepLeadMinutes != null) 'prepLeadMinutes',
        if (purchaseLeadDays != null) 'purchaseLeadDays',
        if (enforceAppearance != null) 'enforceAppearance',
        if (appearanceTheme != null) 'appearanceTheme',
        if (appearanceMode != null) 'appearanceMode',
        if (appearanceMotion != null) 'appearanceMotion',
      }.toList();
}
