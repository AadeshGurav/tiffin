import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/ops.dart';
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
        const _NotificationBell(),
        if (showSettingsButton)
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
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
          onPressed: () => _open(context, ref, notes),
        ),
        if (notes.isNotEmpty)
          Positioned(
            right: 6,
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
              Text('NOTIFICATIONS', style: t.text.heading),
              const SizedBox(height: NbSpace.md),
              if (notes.isEmpty)
                Text('Nothing right now.', style: t.text.body)
              else
                ...notes.map(
                  (n) => Padding(
                    padding: const EdgeInsets.only(bottom: NbSpace.sm),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                            color: t.color.ink, width: t.shape.borderBase),
                      ),
                      title: Text(n.title, style: t.text.label),
                      subtitle: Text(n.message, style: t.text.body),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
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
