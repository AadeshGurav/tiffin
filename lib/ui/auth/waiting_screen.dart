import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/canteen_book.dart';
import '../../app/providers.dart';
import '../../data/access.dart';
import '../../l10n/app_localizations.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/notice_screen.dart';

/// This phone asked to join and is waiting for the admin — or was removed,
/// or is signed in with an online account that has been turned off. The
/// access stream is live, so approval elsewhere moves this screen on by itself.
class WaitingScreen extends ConsumerWidget {
  const WaitingScreen(
      {super.key,
      required Device this.device,
      this.removed = false,
      this.delivered = true})
      : email = null,
        pending = false;

  const WaitingScreen.onlineRefused(
      {super.key, required String this.email, this.pending = false})
      : device = null,
        removed = false,
        delivered = true;

  final Device? device;
  final bool removed;

  /// False while the request has not reached the server, so the admin
  /// cannot see it yet — said plainly rather than left to look like waiting.
  final bool delivered;
  final String? email;

  /// Online account that asked to join and awaits approval (vs turned off).
  final bool pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(context);
    final startOver = NbButton.secondary(
      label: email != null ? text.onlineSignOutButton : text.waitingStartOver,
      icon: Icons.restart_alt,
      onPressed: () => ref.read(accessServiceProvider).startOver(),
    );

    // Always offered: a phone waiting on the wrong canteen is otherwise stuck.
    final switchCanteen = NbButton.secondary(
      label: text.switchCanteenButton,
      icon: Icons.swap_horiz,
      onPressed: () => ref.read(canteenBookProvider.notifier).deactivate(),
    );

    if (email != null) {
      return NoticeScreen(
        icon: pending ? Icons.hourglass_top : Icons.no_accounts_outlined,
        title: email!,
        body: pending ? text.onlinePendingBody : text.onlineInactive,
        actions: [switchCanteen, startOver],
      );
    }
    final d = device!;
    if (removed) {
      return NoticeScreen(
        icon: Icons.phonelink_erase,
        title: d.name,
        body: text.waitingRevoked,
        actions: [
          NbButton(
            label: text.waitingRequestAgain,
            icon: Icons.send,
            onPressed: () => runGuarded(context,
                () => ref.read(accessServiceProvider).requestApproval(d.name)),
          ),
          switchCanteen,
          startOver,
        ],
      );
    }
    return NoticeScreen(
      icon: Icons.hourglass_top,
      title: text.waitingTitle,
      body: [
        if (!delivered) text.waitingNotSent,
        text.waitingBody(d.name),
        text.waitingCode(d.code),
      ].join('\n\n'),
      actions: [switchCanteen, startOver],
    );
  }
}
