import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../admin/purchase_schedule_screen.dart';
import '../admin/topup_screen.dart';
import '../scanner/scanner_screen.dart';
import '../shared_widgets/app_shell.dart';
import '../shared_widgets/nb_group.dart';
import '../shared_widgets/nb_surface.dart';
import '../theme/tokens.dart';
import '../shared_widgets/motion.dart';
import '../../l10n/app_localizations.dart';

/// Counter-role home (PRD §4): scan and top-ups are the daily work, so they
/// are the big tiles; the shared purchase schedule is a quieter row below.
class CounterHome extends ConsumerWidget {
  const CounterHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = AppText.of(context);
    final username = ref.watch(sessionProvider)?.username ?? '';

    void open(Widget Function() screen) =>
        Navigator.of(context).push(tiffinRoute<void>(context, () => screen()));

    Widget tile(String label, IconData icon, Widget Function() screen) =>
        NbSurface(
          intensity: NbIntensity.full,
          background: t.color.accent,
          padding: const EdgeInsets.all(NbSpace.lg),
          onTap: () => open(screen),
          child: Row(
            children: [
              Icon(icon, size: 36, color: t.color.onAccent),
              const SizedBox(width: NbSpace.md),
              Expanded(
                child: Text(label,
                    style: t.text.heading.copyWith(color: t.color.onAccent)),
              ),
            ],
          ),
        );

    return Scaffold(
      appBar: NbAppBar(title: text.counterHomeAppBarTitle(username)),
      body: ListView(
        padding: const EdgeInsets.all(NbSpace.md),
        children: [
          tile(text.counterHomeScanItem, Icons.qr_code_scanner,
              () => const ScannerScreen()),
          const SizedBox(height: NbSpace.md),
          tile(text.counterHomeTopUpItem, Icons.payments,
              () => const TopUpScreen()),
          const SizedBox(height: NbSpace.lg),
          NbGroup(children: [
            NbListRow(
              icon: Icons.shopping_cart,
              title: text.counterHomePurchaseScheduleItem,
              tone: NbTone.kitchen,
              onTap: () => open(() => const PurchaseScheduleScreen()),
            ),
          ]),
        ],
      ),
    );
  }
}
