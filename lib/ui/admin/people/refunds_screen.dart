import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/list_search.dart';
import '../../../core/number_input.dart';
import '../../../app/providers.dart';
import '../../../domain/ledger.dart';
import '../../../domain/member.dart';
import '../../shared_widgets/member_picker.dart';
import '../../shared_widgets/nb_button.dart';
import '../../shared_widgets/nb_feedback.dart';
import '../../shared_widgets/nb_group.dart';
import '../../shared_widgets/nb_text_field.dart';
import '../../shared_widgets/search_sort_list.dart';
import '../../theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/labels.dart';

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
    // Whose refund it was; members are cached, so this is instant.
    final nameById = {
      for (final m in ref.watch(_activeMembersProvider).asData?.value ??
          const <Member>[])
        m.id: m.name,
    };
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
        builder: (all) => SearchSortList<Refund>(
          items: all,
          searchLabel: AppText.of(context).refundsScreenSearchLabel,
          searchFields: (r) => [nameById[r.memberId], r.processedBy, r.reason],
          sorts: [
            SortOption(AppText.of(context).searchSortNewest,
                (a, b) => b.createdAt.compareTo(a.createdAt)),
            SortOption(AppText.of(context).searchSortOldest,
                (a, b) => a.createdAt.compareTo(b.createdAt)),
            SortOption(AppText.of(context).searchSortAmount,
                (a, b) => b.refundAmount.compareTo(a.refundAmount)),
            SortOption(
                AppText.of(context).searchSortNameAz,
                (a, b) => compareNames(
                    nameById[a.memberId] ?? '', nameById[b.memberId] ?? '')),
          ],
          builder: (context, list) => ListView.separated(
            itemCount: list.length,
            separatorBuilder: nbRowSeparator,
            itemBuilder: (_, i) {
              final r = list[i];
              return NbRow(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        nameById[r.memberId] ??
                            AppText.of(context).topupHistoryUnknownMember(
                                shortCode(r.memberId)),
                        style: t.text.body),
                    Text(
                        AppText.of(context).refundsScreenLineSummary(
                            r.lunchUnits,
                            r.breakfastUnits,
                            r.brunchUnits,
                            AppText.of(context).money(r.refundAmount)),
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

    // A meal on grace is below zero: there is nothing of it to refund.
    void prefill() {
      lunch.text = '${max(0, selected.balances.lunch)}';
      breakfast.text = '${max(0, selected.balances.breakfast)}';
      brunch.text = '${max(0, selected.balances.brunch)}';
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
                    label: AppText.of(context).refundsScreenBreakfastUnitsLabel,
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
            lunchUnits: parseWholeNumber(lunch.text),
            breakfastUnits: parseWholeNumber(breakfast.text),
            brunchUnits: parseWholeNumber(brunch.text),
            reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
            processedBy: '',
          )),
      successMessage: AppText.of(context).refundsScreenSuccessMessage,
    );
    if (saved) ref.invalidate(_refundsProvider);
  }
}
