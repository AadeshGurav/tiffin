import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../domain/ledger.dart';
import '../../domain/member.dart';
import '../shared_widgets/member_picker.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/nb_surface.dart';
import '../shared_widgets/nb_text_field.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';

final _refundsProvider = FutureProvider.autoDispose<List<Refund>>(
    (ref) => ref.watch(backendProvider).listRefunds());
final _activeMembersProvider = FutureProvider.autoDispose<List<Member>>(
    (ref) => ref.watch(backendProvider).listMembers());

/// Refunds (PRD §6.7): deduct units from a member's balance and record it. The
/// money movement is outside the app. Units pre-fill from the current balance
/// and can't exceed it (the host enforces this too).
class RefundsScreen extends ConsumerWidget {
  const RefundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final refunds = ref.watch(_refundsProvider);
    final fmt = DateFormat('MMM d, y');
    return Scaffold(
      appBar: AppBar(title: Text(AppText.of(context).refundsScreenTitle)),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: t.color.accent,
        foregroundColor: t.color.onAccent,
        icon: const Icon(Icons.undo),
        label: Text(AppText.of(context).refundsScreenNewButton),
        onPressed: () => _form(context, ref),
      ),
      body: AsyncView<List<Refund>>(
        value: refunds,
        onRetry: () => ref.invalidate(_refundsProvider),
        loadingLabel: AppText.of(context).refundsScreenLoading,
        empty: NbEmpty(
          icon: Icons.undo,
          title: AppText.of(context).refundsScreenEmptyTitle,
          quips: EmptyQuips.refunds(context),
          actionLabel: AppText.of(context).refundsScreenProcessButton,
          onAction: () => _form(context, ref),
        ),
        builder: (list) => ListView.separated(
          padding: const EdgeInsets.all(NbSpace.md),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: NbSpace.sm),
          itemBuilder: (_, i) {
            final r = list[i];
            return NbSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      AppText.of(context).refundsScreenLineSummary(
                          r.lunchUnits,
                          r.breakfastUnits,
                          r.brunchUnits,
                          r.refundAmount.toStringAsFixed(2)),
                      style: t.text.body),
                  Text(
                      AppText.of(context).refundsScreenLineInfo(
                          fmt.format(r.createdAt.toLocal()),
                          r.processedBy,
                          (r.reason != null).toString(),
                          r.reason ?? ''),
                      style: t.text.label),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _form(BuildContext context, WidgetRef ref) async {
    final t = context.tokens;
    final members = [...await ref.read(_activeMembersProvider.future)];
    final categories = (await ref.read(menuCategoriesProvider.future))
        .map((c) => c.name)
        .toList();
    if (!context.mounted || members.isEmpty) return;
    Member selected = members.first;
    final lunch = TextEditingController();
    final breakfast = TextEditingController();
    final brunch = TextEditingController();
    final reason = TextEditingController();

    void prefill() {
      lunch.text = '${selected.balances.lunch}';
      breakfast.text = '${selected.balances.breakfast}';
      brunch.text = '${selected.balances.brunch}';
    }

    prefill();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(AppText.of(context).refundsScreenDialogTitle,
              style: t.text.heading),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NbMemberField(
                  label: AppText.of(context).refundsScreenMemberLabel,
                  value: selected,
                  members: members,
                  onSelected: (m) => setLocal(() {
                    if (members.every((x) => x.id != m.id)) {
                      members.add(m);
                      ref.invalidate(_activeMembersProvider);
                    }
                    selected = m;
                    prefill();
                  }),
                  onCreate: ref.read(backendProvider).createMember,
                  categories: categories,
                ),
                const SizedBox(height: NbSpace.sm),
                NbTextField(
                    label: AppText.of(context).refundsScreenLunchUnitsLabel,
                    controller: lunch,
                    keyboardType: TextInputType.number),
                const SizedBox(height: NbSpace.sm),
                NbTextField(
                    label:
                        AppText.of(context).refundsScreenBreakfastUnitsLabel,
                    controller: breakfast,
                    keyboardType: TextInputType.number),
                const SizedBox(height: NbSpace.sm),
                NbTextField(
                    label: AppText.of(context).refundsScreenBrunchUnitsLabel,
                    controller: brunch,
                    keyboardType: TextInputType.number),
                const SizedBox(height: NbSpace.sm),
                NbTextField(
                    label: AppText.of(context).refundsScreenReasonLabel,
                    controller: reason),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppText.of(context).refundsScreenCancelButton)),
            NbButton(
                label: AppText.of(context).refundsScreenProcessConfirmButton,
                onPressed: () => Navigator.pop(context, true)),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final saved = await runGuarded(
      context,
      () => ref.read(backendProvider).createRefund(RefundDraft(
            memberId: selected.id,
            lunchUnits: int.tryParse(lunch.text) ?? 0,
            breakfastUnits: int.tryParse(breakfast.text) ?? 0,
            brunchUnits: int.tryParse(brunch.text) ?? 0,
            reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
            processedBy: '',
          )),
      successMessage: AppText.of(context).refundsScreenSuccessMessage,
    );
    if (saved) ref.invalidate(_refundsProvider);
  }
}
