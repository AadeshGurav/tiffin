import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../scanner/scanner_screen.dart';
import '../shared_widgets/app_shell.dart';
import '../shared_widgets/motion.dart';
import '../shared_widgets/nb_group.dart';
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

/// Admin home. The two things done all day (scan, top up) are big tiles; the
/// rest is three short lists grouped by what they are about, so there is a
/// place to look rather than ten identical boxes to scan (Hick's Law, Von
/// Restorff). Settings owns the rare stuff — users, devices, reports, backup.
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = AppText.of(context);
    final username = ref.watch(sessionProvider)?.username ?? '';

    void open(Widget Function() screen) =>
        Navigator.of(context).push(tiffinRoute<void>(context, () => screen()));

    NbListRow row(String label, IconData icon, NbTone tone,
            Widget Function() screen) =>
        NbListRow(
            icon: icon, title: label, tone: tone, onTap: () => open(screen));

    return Scaffold(
      appBar: NbAppBar(
          title: text.adminDashboardAppBarTitle(username),
          showSettingsButton: false),
      body: ListView(
        padding: const EdgeInsets.all(NbSpace.md),
        children: [
          Entrance(
            index: 0,
            child: Row(
              children: [
                Expanded(
                  child: _PrimaryTile(
                    label: text.adminDashboardDestScan,
                    icon: Icons.qr_code_scanner,
                    onTap: () => open(() => const ScannerScreen()),
                  ),
                ),
                const SizedBox(width: NbSpace.md),
                Expanded(
                  child: _PrimaryTile(
                    label: text.adminDashboardDestTopup,
                    icon: Icons.payments,
                    onTap: () => open(() => const TopUpScreen()),
                  ),
                ),
              ],
            ),
          ),
          Entrance(
            index: 1,
            child: NbGroup(title: text.adminGroupPeople, children: [
              row(text.adminDashboardDestMembers, Icons.people, NbTone.members,
                  () => const MembersScreen()),
              row(text.adminDashboardDestScanLog, Icons.history, NbTone.members,
                  () => const ScanLogScreen()),
            ]),
          ),
          Entrance(
            index: 2,
            child: NbGroup(title: text.adminGroupMoney, children: [
              row(text.adminDashboardDestExpenses, Icons.receipt_long,
                  NbTone.money, () => const ExpensesScreen()),
              row(text.adminDashboardDestRefunds, Icons.undo, NbTone.money,
                  () => const RefundsScreen()),
            ]),
          ),
          Entrance(
            index: 3,
            child: NbGroup(title: text.adminGroupKitchen, children: [
              row(text.adminDashboardDestMenuCalendar, Icons.calendar_month,
                  NbTone.kitchen, () => const MenuScreen()),
              row(text.adminDashboardDestKitchenSetup, Icons.soup_kitchen,
                  NbTone.kitchen, () => const KitchenSetupScreen()),
              row(text.adminDashboardDestPurchaseSchedule, Icons.shopping_cart,
                  NbTone.kitchen, () => const PurchaseScheduleScreen()),
            ]),
          ),
          const SizedBox(height: NbSpace.lg),
          Entrance(
            index: 4,
            child: NbGroup(children: [
              row(text.adminDashboardDestSettings, Icons.settings,
                  NbTone.system, () => const SettingsScreen()),
            ]),
          ),
          SizedBox(height: t.shape.borderBase),
        ],
      ),
    );
  }
}

/// A big, equal-weight tile for the two daily actions. The only boxes with a
/// bold border on this screen, so they are what the eye lands on first.
class _PrimaryTile extends StatelessWidget {
  const _PrimaryTile(
      {required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NbSurface(
      intensity: NbIntensity.full,
      background: t.color.accent,
      padding: const EdgeInsets.symmetric(
          vertical: NbSpace.lg, horizontal: NbSpace.md),
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 36, color: t.color.onAccent),
          const SizedBox(height: NbSpace.sm),
          Text(label,
              textAlign: TextAlign.center,
              style: t.text.label.copyWith(color: t.color.onAccent)),
        ],
      ),
    );
  }
}
