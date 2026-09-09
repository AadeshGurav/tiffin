import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_memory.dart';
import '../../core/app_mode.dart';
import '../admin/backup_screen.dart';
import '../admin/hosting_screen.dart';
import '../admin/menu_categories_screen.dart';
import '../admin/reports_screen.dart';
import '../admin/settings_config_screen.dart';
import '../admin/users_screen.dart';
import '../shared_widgets/motion.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/settings_row.dart';
import '../theme/tokens.dart';
import 'appearance_screen.dart';

/// The one Settings screen for every role. A short menu of grouped rows; the
/// forms and tools each live behind their own screen. Admins see the full set;
/// counter and scanner see just Appearance and Sign out — same layout, so
/// there's one visual language for "where the account/preference stuff lives"
/// instead of a popup for some roles and a screen for others.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final isAdmin = ref.watch(sessionProvider)?.role.isAdmin ?? false;
    final isHost = ref.watch(currentModeProvider) == AppMode.host;
    final serving = isHost && ref.watch(hostRunningProvider);

    void go(Widget screen) =>
        Navigator.of(context).push(tiffinRoute<void>(context, () => screen));

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(NbSpace.lg),
        children: [
          if (isAdmin) ...[
            _group(t, 'Canteen'),
            SettingsRow(
              icon: Icons.tune,
              title: 'Canteen configuration',
              subtitle:
                  'Prices, meal windows, timezone, grace, reminders, UPI.',
              onTap: () => go(const SettingsConfigScreen()),
            ),
            const SizedBox(height: NbSpace.sm),
            SettingsRow(
              icon: Icons.admin_panel_settings,
              title: 'Users & access',
              subtitle: 'Login accounts and roles.',
              onTap: () => go(const UsersScreen()),
            ),
            const SizedBox(height: NbSpace.sm),
            SettingsRow(
              icon: Icons.category,
              title: 'Menu categories',
              subtitle:
                  'The Jain / Normal / Staff… list menu entries are tagged '
                  'with. Also editable from the menu planner.',
              onTap: () => go(const MenuCategoriesScreen()),
            ),
          ],
          _group(t, 'Display'),
          SettingsRow(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Theme, light/dark, motion.',
            onTap: () => go(const AppearanceScreen()),
          ),
          if (isAdmin && isHost) ...[
            _group(t, 'This host'),
            SettingsRow(
              icon: serving ? Icons.wifi_tethering : Icons.wifi_off,
              title: 'Hosting & LAN',
              subtitle: serving
                  ? 'Serving. URLs, restart, certificate.'
                  : 'Not serving. Tap to start.',
              onTap: () => go(const HostingScreen()),
            ),
            const SizedBox(height: NbSpace.sm),
            SettingsRow(
              icon: Icons.table_view,
              title: 'Reports',
              subtitle: 'Export an .xlsx for reading and printing.',
              onTap: () => go(const ReportsScreen()),
            ),
            const SizedBox(height: NbSpace.sm),
            SettingsRow(
              icon: Icons.save_alt,
              title: 'Backup & restore',
              subtitle: 'A full encrypted copy — move phones, recover data.',
              onTap: () => go(const BackupScreen()),
            ),
          ],
          _group(t, 'Device'),
          SettingsRow(
            icon: Icons.logout,
            title: 'Sign out',
            subtitle: 'End this session on this device.',
            onTap: () => _confirmSignOut(context, ref),
          ),
          if (isAdmin) ...[
            const SizedBox(height: NbSpace.sm),
            SettingsRow(
              icon: Icons.swap_horiz,
              title: 'Switch device role',
              subtitle: 'Host or client. Signs you out; data is untouched.',
              onTap: () => _confirmSwitchRole(context, ref),
            ),
          ],
          if (isAdmin && isHost) ...[
            const SizedBox(height: NbSpace.sm),
            SettingsRow(
              icon: Icons.delete_forever,
              title: 'Reset all data',
              subtitle: 'Permanently wipe this host. No undo.',
              danger: true,
              onTap: () => _confirmReset(context, ref),
            ),
          ],
          const SizedBox(height: NbSpace.xl),
        ],
      ),
    );
  }

  Widget _group(TiffinTokens t, String label) => Padding(
        padding: const EdgeInsets.only(top: NbSpace.lg, bottom: NbSpace.sm),
        child: Text(label.toUpperCase(), style: t.text.heading),
      );

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again on this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(sessionMemoryProvider).signOut();
    // ModeGate swaps the *root* route's child to the login screen; the pushed
    // Settings routes have to come off the stack for that to be visible.
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _confirmSwitchRole(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Switch device role?'),
        content: const Text(
            'You will be signed out and taken back to Host / Client setup. '
            'Your data is not touched.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Switch')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(currentModeProvider.notifier).clear();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ResetConfirmDialog(),
    );
    if (ok == true && context.mounted) {
      await runGuarded(
        context,
        () => ref.read(hostServingProvider.notifier).resetAllData(),
        successMessage: 'All data cleared. Set the device up again.',
      );
    }
  }
}

/// Type-to-confirm guard for the destructive data reset.
class _ResetConfirmDialog extends StatefulWidget {
  const _ResetConfirmDialog();

  @override
  State<_ResetConfirmDialog> createState() => _ResetConfirmDialogState();
}

class _ResetConfirmDialogState extends State<_ResetConfirmDialog> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final armed = _field.text.trim() == 'RESET';
    return AlertDialog(
      title: const Text('Reset all data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This cannot be undone. Type RESET to confirm.'),
          const SizedBox(height: NbSpace.sm),
          TextField(
            controller: _field,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'RESET'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        TextButton(
          onPressed: armed ? () => Navigator.pop(context, true) : null,
          child: const Text('Delete everything'),
        ),
      ],
    );
  }
}
