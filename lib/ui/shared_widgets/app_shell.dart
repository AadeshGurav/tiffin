import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/ops.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/messages.dart';
import '../settings/settings_screen.dart';
import '../theme/tokens.dart';
import 'frosted_panel.dart';
import 'nb_feedback.dart';
import 'motion.dart';

/// App bar shared by every signed-in home screen: the branding title, the
/// notification bell (PRD §6.5.2), and — for roles without a Settings tile on
/// their home — a Settings button.
class NbAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const NbAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showSettingsButton = true,
  });

  final String title;
  final List<Widget>? actions;

  /// The admin turns this off — its dashboard already has a Settings tile.
  /// Counter and scanner don't, so they get the button here; it opens the
  /// same [SettingsScreen], which shows only Appearance and Sign out for
  /// their role.
  final bool showSettingsButton;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: Text(title),
      actions: [
        ...?actions,
        const _SyncIndicator(),
        const _NotificationBell(),
        if (showSettingsButton)
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: AppText.of(context).appShellSettingsTooltip,
            onPressed: () => Navigator.of(context).push(
              tiffinRoute<void>(context, () => const SettingsScreen()),
            ),
          ),
      ],
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final notes = ref.watch(notificationsProvider).asData?.value ?? const [];
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none),
          tooltip: AppText.of(context).tooltipNotifications,
          onPressed: () => _open(context, ref, notes),
        ),
        if (notes.isNotEmpty)
          PositionedDirectional(
            // Directional, so the badge sits on the icon's trailing edge in
            // either reading direction.
            end: 6,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: t.color.reject,
                border: Border.fromBorderSide(
                    BorderSide(color: t.color.ink, width: 1.5)),
              ),
              child: Text('${notes.length}',
                  style: t.text.label
                      .copyWith(color: t.color.onReject, fontSize: 10)),
            ),
          ),
      ],
    );
  }

  void _open(BuildContext context, WidgetRef ref, List<AppNotification> notes) {
    final t = context.tokens;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetBackground(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: t.shape.radius.topLeft),
        side: BorderSide(color: t.color.border, width: t.shape.borderBold),
      ),
      builder: (_) => FrostedPanel(
          child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NbSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppText.of(context).appShellNotificationsTitle,
                  style: t.text.heading),
              const SizedBox(height: NbSpace.md),
              if (notes.isEmpty)
                Text(AppText.of(context).appShellNotificationsEmpty,
                    style: t.text.body)
              else
                ...notes.map(
                  (n) => Padding(
                    padding: const EdgeInsets.only(bottom: NbSpace.sm),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                            color: t.color.ink, width: t.shape.borderBase),
                      ),
                      title: Text(AppText.of(context).notificationText(n).title,
                          style: t.text.label),
                      subtitle: Text(
                          AppText.of(context).notificationText(n).body,
                          style: t.text.body),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: AppText.of(context).tooltipDismiss,
                        onPressed: () async {
                          await runGuarded(
                            context,
                            () => ref
                                .read(backendProvider)
                                .dismissNotification(n.id),
                          );
                          ref.invalidate(notificationsProvider);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      )),
    );
  }
}

/// "Offline — changes will sync": shown only while this phone can't reach
/// Firestore, so the operator knows scans are being kept and will go up
/// later rather than wondering whether they counted (Nielsen #1).
class _SyncIndicator extends ConsumerWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncStateProvider).asData?.value;
    if (sync == null || sync.online) return const SizedBox.shrink();
    final label = AppText.of(context).syncOffline;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: NbSpace.sm),
          child: Icon(Icons.cloud_off),
        ),
      ),
    );
  }
}
