import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_memory.dart';
import '../../l10n/messages.dart';
import '../../services/backup_service.dart';
import '../admin/backup_screen.dart';
import 'devices_screen.dart';
import 'online_accounts_screen.dart';
import '../admin/menu_categories_screen.dart';
import '../admin/reports_screen.dart';
import '../admin/settings_config_screen.dart';
import '../admin/users_screen.dart';
import '../shared_widgets/motion.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/settings_row.dart';
import '../theme/tokens.dart';
import 'appearance_screen.dart';
import '../../l10n/app_localizations.dart';

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
    final text = AppText.of(context);
    final isAdmin = ref.watch(sessionProvider)?.role.isAdmin ?? false;
    final project = ref.watch(firebaseConfigProvider)?.projectId ?? '';

    void go(Widget screen) =>
        Navigator.of(context).push(tiffinRoute<void>(context, () => screen));

    return Scaffold(
      appBar: AppBar(title: Text(text.settingsScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(NbSpace.lg),
        children: [
          if (isAdmin) ...[
            _group(t, text.settingsScreenGroupCanteen),
            SettingsRow(
              icon: Icons.tune,
              title: text.settingsScreenCanteenConfigTitle,
              subtitle: text.settingsScreenCanteenConfigSubtitle,
              onTap: () => go(const SettingsConfigScreen()),
            ),
            const SizedBox(height: NbSpace.sm),
            SettingsRow(
              icon: Icons.admin_panel_settings,
              title: text.settingsScreenUsersTitle,
              subtitle: text.settingsScreenUsersSubtitle,
              onTap: () => go(const UsersScreen()),
            ),
            const SizedBox(height: NbSpace.sm),
            SettingsRow(
              icon: Icons.category,
              title: text.settingsScreenMenuCategoriesTitle,
              subtitle: text.settingsScreenMenuCategoriesSubtitle,
              onTap: () => go(const MenuCategoriesScreen()),
            ),
          ],
          _group(t, text.settingsScreenGroupDisplay),
          SettingsRow(
            icon: Icons.palette_outlined,
            title: text.settingsScreenAppearanceTitle,
            subtitle: text.settingsScreenAppearanceSubtitle,
            onTap: () => go(const AppearanceScreen()),
          ),
          if (isAdmin) ...[
            _group(t, text.settingsScreenGroupAccess),
            SettingsRow(
              icon: Icons.devices,
              title: text.devicesTitle,
              subtitle: text.devicesSubtitle,
              onTap: () => go(const DevicesScreen()),
            ),
            const SizedBox(height: NbSpace.sm),
            SettingsRow(
              icon: Icons.alternate_email,
              title: text.onlineAccountsTitle,
              subtitle: text.onlineAccountsSubtitle,
              onTap: () => go(const OnlineAccountsScreen()),
            ),
            const SizedBox(height: NbSpace.sm),
            SettingsRow(
              icon: Icons.table_view,
              title: text.settingsScreenReportsTitle,
              subtitle: text.settingsScreenReportsSubtitle,
              onTap: () => go(const ReportsScreen()),
            ),
            const SizedBox(height: NbSpace.sm),
            SettingsRow(
              icon: Icons.save_alt,
              title: text.settingsScreenBackupTitle,
              subtitle: text.settingsScreenBackupSubtitle,
              onTap: () => go(const BackupScreen()),
            ),
          ],
          _group(t, text.settingsScreenGroupDevice),
          SettingsRow(
            icon: Icons.logout,
            title: text.settingsScreenSignOutTitle,
            subtitle: text.settingsScreenSignOutSubtitle,
            onTap: () => _confirmSignOut(context, ref),
          ),
          const SizedBox(height: NbSpace.sm),
          SettingsRow(
            icon: Icons.cloud_outlined,
            title: text.settingsScreenFirebaseTitle,
            subtitle: text.settingsScreenFirebaseSubtitle(project),
            onTap: () => _confirmChangeProject(context, ref),
          ),
          if (isAdmin) ...[
            const SizedBox(height: NbSpace.sm),
            SettingsRow(
              icon: Icons.delete_forever,
              title: text.settingsScreenResetDataTitle,
              subtitle: text.settingsScreenResetDataSubtitle,
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
    final text = AppText.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(text.settingsScreenSignOutDialogTitle),
        content: Text(text.settingsScreenSignOutDialogBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(text.settingsScreenCancelButton)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(text.settingsScreenSignOutTitle)),
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

  Future<void> _confirmChangeProject(
      BuildContext context, WidgetRef ref) async {
    final text = AppText.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(text.settingsScreenChangeFirebaseDialogTitle),
        content: Text(text.settingsScreenChangeFirebaseDialogBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(text.settingsScreenCancelButton)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(text.settingsScreenChangeButton)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(sessionMemoryProvider).signOut();
    await ref.read(firebaseConfigProvider.notifier).forget();
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
        () async {
          // Restoring an empty backup is exactly "delete every record": one
          // code path for wiping, and it refuses to run offline.
          await ref
              .read(backendProvider)
              .backups
              .restore(const BackupContents(collections: {}));
          await ref.read(sessionMemoryProvider).signOut();
          ref.invalidate(setupRequiredProvider);
        },
        successMessage: AppText.of(context).settingsScreenResetSuccessSnack,
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
    final text = AppText.of(context);
    final armed =
        confirmWordMatches(_field.text, text.confirmWordReset, 'RESET');
    return AlertDialog(
      title: Text(text.settingsScreenResetDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text.settingsScreenResetDialogBody),
          const SizedBox(height: NbSpace.sm),
          TextField(
            controller: _field,
            autofocus: true,
            decoration: InputDecoration(hintText: text.confirmWordReset),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(text.settingsScreenCancelButton)),
        TextButton(
          onPressed: armed ? () => Navigator.pop(context, true) : null,
          child: Text(text.settingsScreenDeleteEverythingButton),
        ),
      ],
    );
  }
}
