import 'package:flutter/widgets.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';

/// The three locales this app ships (CLAUDE.md §13, PRD i18n plan §15.2).
/// English is the default and the fallback for any missing translation.
enum AppLocaleId {
  en('en', 'English'),
  hi('hi', 'हिन्दी'),
  mr('mr', 'मराठी');

  const AppLocaleId(this.code, this.nativeName);

  final String code;

  /// The language's own name for itself, for the picker UI — a Marathi
  /// speaker recognizes "मराठी" instantly; "Marathi" costs them a beat.
  final String nativeName;

  Locale get locale => Locale(code);

  static AppLocaleId fromCode(String? code) => switch (code) {
        'hi' => AppLocaleId.hi,
        'mr' => AppLocaleId.mr,
        _ => AppLocaleId.en,
      };
}

/// Device-local language choice, mirroring [AppearanceStore]'s shape.
///
/// Held per device rather than per account, and independent of the OS
/// locale: a scanning station is a shared device, and it's the person
/// operating it — not the phone itself — who determines the language they
/// need (PRD i18n plan §15.2).
class LocaleStore {
  LocaleStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'app_locale';

  AppLocaleId read() => AppLocaleId.fromCode(_prefs.getString(_key));

  Future<void> write(AppLocaleId id) => _prefs.setString(_key, id.code);
}
