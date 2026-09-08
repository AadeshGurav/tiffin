import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_memory.dart';
import '../../core/app_mode.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/settings_row.dart';
import '../settings/appearance_screen.dart';
import '../theme/tokens.dart';
import '../shared_widgets/motion.dart';
import 'backup_screen.dart';
import 'hosting_screen.dart';
import 'menu_categories_screen.dart';
import 'reports_screen.dart';
import 'settings_config_screen.dart';
import 'users_screen.dart';

/// Settings hub (PRD §6.8). A short menu of grouped destinations — the actual
/// forms and tools each live on their own screen, so nothing here is a wall of
/// fields.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final isHost = ref.watch(currentModeProvider) == AppMode.host;
    final serving = isHost && ref.watch(hostRunningProvider);

    void go(Widget screen) =>
        Navigator.of(context).push(tiffinRoute<void>(context, () => screen));

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(NbSpace.lg),
        children: [
          _group(t, 'Canteen'),
          SettingsRow(
            icon: Icons.tune,
            title: 'Canteen configuration',
            subtitle: 'Prices, meal windows, timezone, grace, reminders, UPI.',
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
            subtitle: 'The Jain / Normal / Staff… list menu entries are tagged '
                'with. Also editable from the menu planner.',
            onTap: () => go(const MenuCategoriesScreen()),
          ),
          const SizedBox(height: NbSpace.sm),
          SettingsRow(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Theme, light/dark, motion.',
            onTap: () => go(const AppearanceScreen()),
          ),
          if (isHost) ...[
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
          const SizedBox(height: NbSpace.sm),
          SettingsRow(
            icon: Icons.swap_horiz,
            title: 'Switch device role',
            subtitle: 'Host or client. Signs you out; data is untouched.',
            onTap: () => _confirmSwitchRole(context, ref),
          ),
          if (isHost) ...[
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
    if (ok == true) await ref.read(sessionMemoryProvider).signOut();
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
    if (ok == true) await ref.read(currentModeProvider.notifier).clear();
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
