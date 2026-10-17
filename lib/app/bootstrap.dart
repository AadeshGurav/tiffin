import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../core/logging.dart';

/// One-time process setup, shared by the real app and by tests. Kept out of
/// `main.dart` so every startup side effect has an obvious home.
Future<SharedPreferences> bootstrap() async {
  tzdata.initializeTimeZones(); // IANA database for meal-window resolution

  // Marathi's CLDR default is Devanagari digits, but every count the ARB
  // files interpolate is Latin; one digit system per screen beats a mix.
  DateFormat.useNativeDigitsByDefaultFor('mr', false);

  // The log file is the admin's debugging tool on every phone now that each
  // phone holds its own copy of the data (PRD §7).
  await AppLogger.configure(toFile: true);

  return SharedPreferences.getInstance();
}

/// Injected, never read as a global (CLAUDE.md §5). Overridden in `main()` /
/// tests with the value from [bootstrap].
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw StateError('sharedPreferencesProvider must be overridden'),
);
