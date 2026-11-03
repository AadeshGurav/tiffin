import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/canteen_book.dart';
import '../../app/providers.dart';
import '../../app/session_memory.dart';
import '../../data/canteens.dart';
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
import '../shared_widgets/nb_group.dart';
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
    final text = AppText.of(context);
    final isAdmin = ref.watch(sessionProvider)?.role.isAdmin ?? false;
    final canteen = ref.watch(canteenBookProvider).active;

    void go(Widget screen) =>
        Navigator.of(context).push(tiffinRoute<void>(context, () => screen));

    NbListRow row(IconData icon, String title, String subtitle, Widget screen,
            {NbTone tone = NbTone.system}) =>
        NbListRow(
            icon: icon,
            title: title,
            subtitle: subtitle,
            tone: tone,
            onTap: () => go(screen));

    // Grouped by what the row is about, one box per group. Sign-out and the
    // destructive reset are last and apart, so they are never a stray tap.
    return Scaffold(
      appBar: AppBar(title: Text(text.settingsScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(NbSpace.md),
        children: [
          if (isAdmin)
            NbGroup(title: text.settingsScreenGroupCanteen, children: [
              row(
                  Icons.tune,
                  text.settingsScreenCanteenConfigTitle,
                  text.settingsScreenCanteenConfigSubtitle,
                  const SettingsConfigScreen()),
              row(Icons.admin_panel_settings, text.settingsScreenUsersTitle,
                  text.settingsScreenUsersSubtitle, const UsersScreen()),
              row(
                  Icons.category,
                  text.settingsScreenMenuCategoriesTitle,
                  text.settingsScreenMenuCategoriesSubtitle,
                  const MenuCategoriesScreen()),
              row(Icons.table_view, text.settingsScreenReportsTitle,
                  text.settingsScreenReportsSubtitle, const ReportsScreen()),
              row(Icons.save_alt, text.settingsScreenBackupTitle,
                  text.settingsScreenBackupSubtitle, const BackupScreen()),
            ]),
          if (isAdmin)
            NbGroup(title: text.settingsScreenGroupAccess, children: [
              row(Icons.devices, text.devicesTitle, text.devicesSubtitle,
                  const DevicesScreen()),
              row(Icons.alternate_email, text.onlineAccountsTitle,
                  text.onlineAccountsSubtitle, const OnlineAccountsScreen()),
            ]),
          NbGroup(title: text.settingsScreenGroupDisplay, children: [
            row(
                Icons.palette_outlined,
                text.settingsScreenAppearanceTitle,
                text.settingsScreenAppearanceSubtitle,
                const AppearanceScreen()),
          ]),
          NbGroup(title: text.settingsScreenGroupDevice, children: [
            if (isAdmin && canteen != null)
              NbListRow(
                icon: Icons.key_outlined,
                title: text.settingsScreenCanteenCodeTitle,
                subtitle: text.settingsScreenCanteenCodeSubtitle(canteen.code),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: canteen.code));
                  if (context.mounted) {
                    showNbSnack(context, text.canteenCodeCopied);
                  }
                },
              ),
            NbListRow(
              icon: Icons.swap_horiz,
              title: text.settingsScreenSwitchTitle,
              subtitle: text.settingsScreenSwitchSubtitle(canteen?.name ?? ''),
              onTap: () => _switchCanteen(context, ref),
            ),
            if (_isOnlineIdentity(ref))
              NbListRow(
                icon: Icons.link,
                title: text.settingsScreenAddMethodTitle,
                subtitle: text.settingsScreenAddMethodSubtitle,
                onTap: () => _addMethod(context, ref),
              ),
            NbListRow(
              icon: Icons.logout,
              title: text.settingsScreenSignOutTitle,
              subtitle: text.settingsScreenSignOutSubtitle,
              onTap: () => _confirmSignOut(context, ref),
            ),
          ]),
          if (isAdmin) ...[
            const SizedBox(height: NbSpace.xl),
            NbGroup(children: [
              NbListRow(
                icon: Icons.delete_forever,
                title: text.settingsScreenResetDataTitle,
                subtitle: text.settingsScreenResetDataSubtitle,
                danger: true,
                onTap: () => _confirmReset(context, ref),
              ),
            ]),
          ],
          const SizedBox(height: NbSpace.xl),
        ],
      ),
    );
  }

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

  bool _isOnlineIdentity(WidgetRef ref) {
    final user = ref.watch(identityChangesProvider).asData?.value;
    return user != null && !user.isAnonymous;
  }

  Future<void> _addMethod(BuildContext context, WidgetRef ref) async {
    final text = AppText.of(context);
    final which = await showModalBottomSheet<SignInProvider>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.g_mobiledata),
            title: Text(text.addMethodGoogle),
            onTap: () => Navigator.pop(context, SignInProvider.google),
          ),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.window),
            title: Text(text.addMethodMicrosoft),
            onTap: () => Navigator.pop(context, SignInProvider.microsoft),
          ),
        ]),
      ),
    );
    if (which == null || !context.mounted) return;
    await runGuarded(context, () async {
      await ref.read(canteenServiceProvider).addSignInMethod(which);
      if (context.mounted) showNbSnack(context, text.addMethodDone);
    });
  }

  /// Nothing is lost by leaving a canteen's screen: the phone keeps its
  /// copy and saved logins and the canteen is one tap away on the Welcome list.
  Future<void> _switchCanteen(BuildContext context, WidgetRef ref) async {
    await ref.read(sessionMemoryProvider).signOut();
    await ref.read(canteenBookProvider.notifier).deactivate();
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
