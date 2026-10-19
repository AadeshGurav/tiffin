import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/role.dart';
import '../data/access.dart';
import '../l10n/app_localizations.dart';
import '../ui/admin/admin_dashboard.dart';
import '../ui/auth/connect_firebase_screen.dart';
import '../ui/auth/device_setup_screen.dart';
import '../ui/auth/host_setup_screen.dart';
import '../ui/auth/login_screen.dart';
import '../ui/auth/waiting_screen.dart';
import '../ui/counter/counter_home.dart';
import '../ui/scanner/scanner_screen.dart';
import '../ui/shared_widgets/brand_splash.dart';
import '../ui/shared_widgets/nb_feedback.dart';
import '../ui/shared_widgets/notice_screen.dart';
import 'providers.dart';

/// The single routing decision, kept flat (CLAUDE.md §3):
///
///  1. no Firebase project imported   → connect screen
///  2. this phone not part of it yet   → set up / waiting for approval
///  3. approved, cache warming         → splash
///  4. no accounts exist yet           → first-run setup (admin phones)
///  5. not signed in                   → sign-in
///  6. signed in                       → the role's home
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(context);
    if (ref.watch(firebaseConfigProvider) == null) {
      return const ConnectFirebaseScreen();
    }
    if (ref.watch(needsRestartProvider)) {
      return NoticeScreen(
          icon: Icons.restart_alt,
          title: text.restartTitle,
          body: text.restartBody);
    }

    final app = ref.watch(firebaseAppProvider);
    if (app.hasError) {
      return _Failed(
          error: app.error!,
          onRetry: () => ref.invalidate(firebaseAppProvider));
    }
    if (!app.hasValue) return BrandSplash(message: text.splashPreparing);

    final access = ref.watch(accessProvider);
    if (access.hasError) {
      return _Failed(
          error: access.error!, onRetry: () => ref.invalidate(accessProvider));
    }
    return switch (access.asData?.value) {
      null => BrandSplash(message: text.splashPreparing),
      SignedOut() =>
        const DeviceSetupScreen(newCanteen: false, signedIn: false),
      NotJoined(:final newCanteen) =>
        DeviceSetupScreen(newCanteen: newCanteen, signedIn: true),
      PendingApproval(:final device) => WaitingScreen(device: device),
      Removed(:final device) => WaitingScreen(device: device, removed: true),
      OnlineRefused(:final email) => WaitingScreen.onlineRefused(email: email),
      ApprovedDevice() || OnlineAccess() => const _SignedInGate(),
    };
  }
}

/// Steps 3–6, once the phone may read the canteen's data.
class _SignedInGate extends ConsumerWidget {
  const _SignedInGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(context);
    final ready = ref.watch(backendReadyProvider);
    if (ready.hasError) {
      return _Failed(
          error: ready.error!,
          onRetry: () => ref.invalidate(cacheWarmerProvider));
    }
    if (!ready.hasValue) return BrandSplash(message: text.splashSyncing);

    final grant = ref.watch(grantProvider)!;
    final session = ref.watch(sessionProvider);
    if (!grant.online) {
      final setup = ref.watch(setupRequiredProvider).asData?.value;
      if (setup == null) return BrandSplash(message: text.splashSyncing);
      if (setup) {
        return grant.role == Role.admin
            ? const HostSetupScreen()
            : NoticeScreen(
                icon: Icons.person_off_outlined,
                title: text.noAccountsTitle,
                body: text.noAccountsBody);
      }
      if (session == null) return const LoginScreen();
    }
    if (session == null) return BrandSplash(message: text.splashPreparing);
    return switch (session.role) {
      Role.scanner => const ScannerScreen(isRoleHome: true),
      Role.counter => const CounterHome(),
      Role.admin => const AdminDashboard(),
    };
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorPanel(error: error, onRetry: onRetry),
            ),
          ),
        ),
      );
}
