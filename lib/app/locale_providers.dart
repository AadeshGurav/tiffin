import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/locale_store.dart';
import 'providers.dart';

final localeStoreProvider = Provider<LocaleStore>(
    (ref) => LocaleStore(ref.read(sharedPreferencesProvider)));

/// This device's own language choice, persisted immediately so the app opens
/// in the chosen language rather than flashing English first — the same
/// pattern as [AppearanceController] in appearance_providers.dart.
class LocaleController extends Notifier<AppLocaleId> {
  @override
  AppLocaleId build() => ref.read(localeStoreProvider).read();

  Future<void> set(AppLocaleId id) async {
    state = id;
    await ref.read(localeStoreProvider).write(id);
  }
}

final deviceLocaleProvider =
    NotifierProvider<LocaleController, AppLocaleId>(LocaleController.new);
