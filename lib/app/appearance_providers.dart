import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme/appearance.dart';
import '../ui/theme/theme_catalog.dart';
import 'providers.dart';

final appearanceStoreProvider = Provider<AppearanceStore>(
    (ref) => AppearanceStore(ref.read(sharedPreferencesProvider)));

/// This device's own appearance choice, persisted immediately so the app opens
/// on the chosen theme rather than flashing the default first.
class AppearanceController extends Notifier<Appearance> {
  @override
  Appearance build() => ref.read(appearanceStoreProvider).read();

  Future<void> setTheme(TiffinThemeId theme) =>
      _save(state.copyWith(theme: theme));

  Future<void> setMode(ThemeMode mode) => _save(state.copyWith(mode: mode));

  Future<void> setMotion({required bool enabled}) =>
      _save(state.copyWith(motion: enabled));

  Future<void> _save(Appearance next) async {
    state = next;
    await ref.read(appearanceStoreProvider).write(next);
  }
}

final deviceAppearanceProvider =
    NotifierProvider<AppearanceController, Appearance>(
        AppearanceController.new);

/// The canteen's name and appearance policy, from its settings document.
///
/// Any failure — not approved yet, cache still cold — resolves to
/// [HostGreeting.unknown]: a phone must still render *something*, and its own
/// choice is the honest default until the canteen's policy is readable.
final hostGreetingProvider = FutureProvider<HostGreeting>((ref) async {
  try {
    await ref.watch(backendReadyProvider.future);
    return await ref.watch(backendProvider).greeting();
  } catch (_) {
    return HostGreeting.unknown;
  }
});

/// The host's appearance policy, from the same pre-login greeting.
final appearancePolicyProvider = Provider<AppearancePolicy>((ref) =>
    ref.watch(hostGreetingProvider).asData?.value.appearance ??
    AppearancePolicy.none);

/// What this device actually renders: the host's choice when it enforces one,
/// otherwise the device's own.
final effectiveAppearanceProvider = Provider<Appearance>((ref) {
  final device = ref.watch(deviceAppearanceProvider);
  return ref.watch(appearancePolicyProvider).resolve(device);
});

/// True when the host is dictating appearance, so the Appearance controls can
/// say so instead of silently discarding taps.
final appearanceIsEnforcedProvider =
    Provider<bool>((ref) => ref.watch(appearancePolicyProvider).enforced);
