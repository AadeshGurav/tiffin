import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/ledger.dart';
import '../../domain/member.dart';
import '../../domain/settings.dart';
import '../shared_widgets/member_picker.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/nb_surface.dart';
import '../theme/tokens.dart';
import 'topup_history_screen.dart';
import '../../l10n/app_localizations.dart';

final _membersProvider = FutureProvider.autoDispose<List<Member>>(
    (ref) => ref.watch(backendProvider).listMembers(status: 'active'));
final _settingsProvider = FutureProvider.autoDispose<SettingsSnapshot>(
    (ref) => ref.watch(backendProvider).getSettings());

/// Top-up & billing (PRD §6.3). Two tabs: **Charge** takes a payment, **History**
/// lists past top-ups and reverses them. History used to be its own dashboard
/// tile — it's the same subject, so it's a tab here now.
class TopUpScreen extends StatelessWidget {
  const TopUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppText.of(context).topupScreenTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: AppText.of(context).topupScreenChargeTab),
              Tab(text: AppText.of(context).topupScreenHistoryTab),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ChargeTab(), TopupHistoryTab()],
        ),
      ),
    );
  }
}

/// Pick a member, enter units, pick cash/UPI. The amount is computed from unit
/// prices — never typed. Submit is disabled while every unit is zero.
class _ChargeTab extends ConsumerStatefulWidget {
  const _ChargeTab();

  @override
  ConsumerState<_ChargeTab> createState() => _ChargeTabState();
}

class _ChargeTabState extends ConsumerState<_ChargeTab> {
  Member? _member;
  int _lunch = 0, _breakfast = 0, _brunch = 0;
  PaymentMethod _method = PaymentMethod.cash;
  bool _busy = false;

  double _amount(SettingsSnapshot s) =>
      _lunch * s.unitPrices.lunch +
      _breakfast * s.unitPrices.breakfast +
      _brunch * s.unitPrices.brunch;

  bool get _canSubmit =>
      _member != null && (_lunch + _breakfast + _brunch) > 0 && !_busy;

  Future<void> _submit(SettingsSnapshot s) async {
    setState(() => _busy = true);
    Topup? created;
    final ok = await runGuarded(context, () async {
      created = await ref.read(backendProvider).createTopup(TopupDraft(
            memberId: _member!.id,
            lunchUnits: _lunch,
            breakfastUnits: _breakfast,
            brunchUnits: _brunch,
            paymentMethod: _method,
            createdBy: '', // host/client backend fills this in
          ));
    }, successMessage: AppText.of(context).topupScreenBalancesCreditedMessage);
    if (mounted) setState(() => _busy = false);
    if (!ok || created == null || !mounted) return;
    await _showBillDialog(created!, s);
    if (mounted) {
      setState(() {
        _lunch = _breakfast = _brunch = 0;
        _member = null;
      });
      ref.invalidate(_membersProvider);
    }
  }

  Future<void> _showBillDialog(Topup topup, SettingsSnapshot s) async {
    Uint8List? upiQr;
    if (topup.paymentMethod == PaymentMethod.upi && topup.hasUpiQr) {
      try {
        upiQr = Uint8List.fromList(
            await ref.read(backendProvider).topupUpiQrPng(topup.id));
      } catch (_) {/* fall through — show without the QR */}
    }
    if (!mounted) return;
    final t = context.tokens;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppText.of(context).topupScreenBillDialogTitle(topup.id),
            style: t.text.heading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppText.of(context).topupScreenBillAmount(
                topup.amount.toStringAsFixed(2),
                topup.paymentMethod.wire.toUpperCase())),
            Text(AppText.of(context).topupScreenBillStatus(topup.paymentStatus)),
            if (upiQr != null) ...[
              const SizedBox(height: NbSpace.md),
              Text(AppText.of(context).topupScreenScanQrPrompt),
              const SizedBox(height: NbSpace.sm),
              Image.memory(upiQr, width: 220, height: 220),
            ],
          ],
        ),
        actions: [
          if (topup.paymentMethod == PaymentMethod.upi)
            NbButton.secondary(
              label: AppText.of(context).topupScreenMarkReceivedButton,
              onPressed: () async {
                final navigator = Navigator.of(context);
                final ok = await runGuarded(
                  context,
                  () => ref.read(backendProvider).confirmTopupPayment(topup.id),
                  successMessage:
                      AppText.of(context).topupScreenPaymentConfirmedMessage,
                );
                if (ok) navigator.pop();
              },
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppText.of(context).topupScreenDoneButton)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final members = ref.watch(_membersProvider);
    final settings = ref.watch(_settingsProvider);

    return AsyncView<SettingsSnapshot>(
      value: settings,
      onRetry: () => ref.invalidate(_settingsProvider),
      loadingLabel: AppText.of(context).topupScreenLoadingPrices,
      builder: (s) => AsyncView<List<Member>>(
        value: members,
        onRetry: () => ref.invalidate(_membersProvider),
        loadingLabel: AppText.of(context).topupScreenLoadingMembers,
        empty: NbEmpty(
          icon: Icons.person_off_outlined,
          title: AppText.of(context).topupScreenEmptyTitle,
          quips: [
            AppText.of(context).topupScreenEmptyQuip,
          ],
        ),
        builder: (list) => ListView(
          padding: const EdgeInsets.all(NbSpace.lg),
          children: [
            NbMemberField(
              label: AppText.of(context).topupScreenMemberLabel,
              value: _member,
              members: list,
              onSelected: (m) {
                setState(() => _member = m);
                if (list.every((x) => x.id != m.id)) {
                  ref.invalidate(_membersProvider);
                }
              },
              onCreate: ref.read(backendProvider).createMember,
              categories: ref
                      .watch(menuCategoriesProvider)
                      .asData
                      ?.value
                      .map((c) => c.name)
                      .toList() ??
                  const [],
            ),
            const SizedBox(height: NbSpace.md),
            _UnitRow(
              label: AppText.of(context)
                  .topupScreenLunchLabel(s.unitPrices.lunch.toStringAsFixed(0)),
              value: _lunch,
              onChanged: (v) => setState(() => _lunch = v),
            ),
            _UnitRow(
              label: AppText.of(context).topupScreenBreakfastLabel(
                  s.unitPrices.breakfast.toStringAsFixed(0)),
              value: _breakfast,
              onChanged: (v) => setState(() => _breakfast = v),
            ),
            _UnitRow(
              label: AppText.of(context).topupScreenBrunchLabel(
                  s.unitPrices.brunch.toStringAsFixed(0)),
              value: _brunch,
              onChanged: (v) => setState(() => _brunch = v),
            ),
            const SizedBox(height: NbSpace.md),
            SegmentedButton<PaymentMethod>(
              segments: [
                ButtonSegment(
                    value: PaymentMethod.cash,
                    label: Text(AppText.of(context).topupScreenPaymentCash)),
                ButtonSegment(
                    value: PaymentMethod.upi,
                    label: Text(AppText.of(context).topupScreenPaymentUpi)),
              ],
              selected: {_method},
              onSelectionChanged: (v) => setState(() => _method = v.first),
            ),
            const SizedBox(height: NbSpace.lg),
            NbSurface(
              intensity: NbIntensity.full,
              background: t.color.surfaceMuted,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppText.of(context).topupScreenTotalLabel,
                      style: t.text.label),
                  Text('Rs. ${_amount(s).toStringAsFixed(2)}',
                      style: t.text.heading),
                ],
              ),
            ),
            const SizedBox(height: NbSpace.md),
            NbButton(
              label: AppText.of(context).topupScreenChargeButton,
              busy: _busy,
              onPressed: _canSubmit ? () => _submit(s) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: NbSpace.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t.text.body)),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
          ),
          Text('$value', style: t.text.heading),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}
