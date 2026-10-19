import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../scanner/scanner_screen.dart';
import '../shared_widgets/app_shell.dart';
import '../shared_widgets/motion.dart';
import '../shared_widgets/nb_surface.dart';
import '../theme/tokens.dart';
import 'expenses_screen.dart';
import 'kitchen_setup_screen.dart';
import 'members_screen.dart';
import 'menu_screen.dart';
import 'purchase_schedule_screen.dart';
import 'refunds_screen.dart';
import 'scan_log_screen.dart';
import 'topup_screen.dart';
import '../settings/settings_screen.dart';
import '../../l10n/app_localizations.dart';

/// Admin home — a flat grid of destinations (Hick's Law: staged, not one long
/// menu). Restrained neobrutalism intensity, this is a navigation surface not
/// an action moment (PRD §14.2).
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final username = ref.watch(sessionProvider)?.username ?? '';
    // Grouped by domain, and coloured by it: a dozen identical boxes are a
    // wall to scan, four colour families are four places to look. The tone
    // never carries state, so nothing is lost if it isn't seen (§12.2).
    // Settings owns the rare stuff — users, devices, reports, backup.
    final destinations = <_Dest>[
      _Dest(AppText.of(context).adminDashboardDestScan, Icons.qr_code_scanner,
          NbTone.members, () => const ScannerScreen()),
      _Dest(AppText.of(context).adminDashboardDestMembers, Icons.people,
          NbTone.members, () => const MembersScreen()),
      _Dest(AppText.of(context).adminDashboardDestScanLog, Icons.history,
          NbTone.members, () => const ScanLogScreen()),
      _Dest(AppText.of(context).adminDashboardDestTopup, Icons.payments,
          NbTone.money, () => const TopUpScreen()),
      _Dest(AppText.of(context).adminDashboardDestExpenses, Icons.receipt_long,
          NbTone.money, () => const ExpensesScreen()),
      _Dest(AppText.of(context).adminDashboardDestRefunds, Icons.undo,
          NbTone.money, () => const RefundsScreen()),
      _Dest(AppText.of(context).adminDashboardDestMenuCalendar,
          Icons.calendar_month, NbTone.kitchen, () => const MenuScreen()),
      _Dest(AppText.of(context).adminDashboardDestKitchenSetup,
          Icons.soup_kitchen, NbTone.kitchen, () => const KitchenSetupScreen()),
      _Dest(
          AppText.of(context).adminDashboardDestPurchaseSchedule,
          Icons.shopping_cart,
          NbTone.kitchen,
          () => const PurchaseScheduleScreen()),
      _Dest(AppText.of(context).adminDashboardDestSettings, Icons.settings,
          NbTone.system, () => const SettingsScreen()),
    ];

    return Scaffold(
      appBar: NbAppBar(
          title: AppText.of(context).adminDashboardAppBarTitle(username),
          showSettingsButton: false),
      body: Column(
        children: [
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(NbSpace.md),
              crossAxisCount: 2,
              mainAxisSpacing: NbSpace.md,
              crossAxisSpacing: NbSpace.md,
              childAspectRatio: 1.3,
              children: [
                for (final (i, d) in destinations.indexed)
                  Entrance(
                    index: i,
                    child: NbSurface(
                      tone: d.tone,
                      onTap: () => Navigator.of(context)
                          .push(tiffinRoute<void>(context, () => d.build())),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(d.icon,
                              size: 36,
                              color: t.color.on(t.color.tone(d.tone))),
                          const SizedBox(height: NbSpace.sm),
                          Text(d.label,
                              textAlign: TextAlign.center, style: t.text.label),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dest {
  _Dest(this.label, this.icon, this.tone, this.build);
  final String label;
  final IconData icon;

  /// Which domain this destination belongs to — members, money, kitchen or
  /// system. Drives the tile colour only.
  final NbTone tone;
  final Widget Function() build;
}
