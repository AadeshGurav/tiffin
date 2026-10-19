/// Values genuinely fixed for a given build.
///
/// CLAUDE.md §7 / PRD §6.8: anything an operator might reasonably change lives
/// in the canteen's settings document (see `SettingsService`), and the one
/// thing this build is configured with — which Firebase project — is imported
/// at runtime (`FirebaseConfig`). Neither belongs here.
class AppConfig {
  const AppConfig._();

  /// Stamped into backup manifests so a restore can say which build wrote a
  /// file. Kept in step with pubspec.yaml's `version:` by hand.
  static const String appVersion = '3.0.0';

  /// How often signed-in screens re-read notifications (PRD §6.5.2). Reads
  /// come from the local cache, so this costs no network.
  static const Duration notificationPollInterval = Duration(seconds: 45);

  /// Rotating log file budget (the admin's primary debugging tool, PRD §7).
  static const int logFileMaxBytes = 5 * 1000 * 1000;
  static const int logFileBackupCount = 5;
}
