import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      {super.key, required Device this.device, this.removed = false})
      : email = null;

  const WaitingScreen.onlineRefused({super.key, required String this.email})
      : device = null,
        removed = false;

  final Device? device;
  final bool removed;
  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(context);
    final access = ref.read(accessServiceProvider);
    final startOver = NbButton.secondary(
      label: email != null ? text.onlineSignOutButton : text.waitingStartOver,
      icon: Icons.restart_alt,
      onPressed: access.startOver,
    );

    if (email != null) {
      return NoticeScreen(
        icon: Icons.no_accounts_outlined,
        title: email!,
        body: text.onlineInactive,
        actions: [startOver],
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
            onPressed: () =>
                runGuarded(context, () => access.requestApproval(d.name)),
          ),
          startOver,
        ],
      );
    }
    return NoticeScreen(
      icon: Icons.hourglass_top,
      title: text.waitingTitle,
      body: '${text.waitingBody(d.name)}\n\n${text.waitingCode(d.code)}',
      actions: [startOver],
    );
  }
}
