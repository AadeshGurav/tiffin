import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../domain/ledger.dart';
import '../../domain/member.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/nb_surface.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/messages.dart';
import '../../l10n/labels.dart';

typedef _History = ({List<Topup> topups, Map<String, Member> membersById});

final _historyProvider = FutureProvider.autoDispose<_History>((ref) async {
  final backend = ref.watch(backendProvider);
  final topups = await backend.listTopups(limit: 300);
  final members = await backend.listMembers();
  return (
    topups: topups,
    membersById: {for (final m in members) m.id: m},
  );
});

/// Top-up history + reversal (client's point 2), the "History" tab of the
/// Top-up & bill screen. A reversal restores the member's balance and flags
/// the row; the row is kept for audit, never deleted — the same treatment as
/// a reversed scan.
class TopupHistoryTab extends ConsumerWidget {
  const TopupHistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final history = ref.watch(_historyProvider);
    final fmt = DateFormat('MMM d, y · HH:mm');

    return AsyncView<_History>(
      value: history,
      onRetry: () => ref.invalidate(_historyProvider),
      loadingLabel: AppText.of(context).topupHistoryLoading,
      empty: NbEmpty(
        icon: Icons.payments_outlined,
        title: AppText.of(context).topupHistoryEmptyTitle,
        quips: [AppText.of(context).topupHistoryEmptyQuip],
      ),
      builder: (data) => ListView.separated(
        padding: const EdgeInsets.all(NbSpace.md),
        itemCount: data.topups.length,
        separatorBuilder: (_, __) => const SizedBox(height: NbSpace.sm),
        itemBuilder: (_, i) {
          final tp = data.topups[i];
          final name = data.membersById[tp.memberId]?.name ??
              AppText.of(context)
                  .topupHistoryUnknownMember(shortCode(tp.memberId));
          return NbSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: t.text.body)),
                    if (tp.reversed)
                      Text(AppText.of(context).topupHistoryReversedBadge,
                          style: t.text.label.copyWith(color: t.color.reject)),
                  ],
                ),
                Text(
                    AppText.of(context).topupHistoryLineSummary(
                        tp.lunchUnits,
                        tp.breakfastUnits,
                        tp.brunchUnits,
                        AppText.of(context).money(tp.amount),
                        AppText.of(context)
                            .paymentMethodLabel(tp.paymentMethod),
                        AppText.of(context)
                            .paymentStatusLabel(tp.paymentStatus)),
                    style: t.text.label),
                Text(
                    AppText.of(context).topupHistoryCreatedInfo(
                        fmt.format(tp.createdAt.toLocal()), tp.createdBy),
                    style: t.text.label),
                if (tp.reversed && tp.reversedAt != null)
                  Text(
                      AppText.of(context).topupHistoryReversedInfo(
                          fmt.format(tp.reversedAt!.toLocal()),
                          (tp.reversedBy != null).toString(),
                          tp.reversedBy ?? ''),
                      style: t.text.label.copyWith(color: t.color.reject)),
                if (!tp.reversed) ...[
                  const SizedBox(height: NbSpace.sm),
                  NbButton.secondary(
                    label: AppText.of(context).topupHistoryReverseButton,
                    onPressed: () => _confirmReverse(context, ref, tp, name),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmReverse(
      BuildContext context, WidgetRef ref, Topup tp, String name) async {
    final t = context.tokens;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppText.of(context).topupHistoryReverseDialogTitle,
            style: t.text.heading),
        content: Text(
          AppText.of(context).topupHistoryReverseDialogBody(
              tp.lunchUnits, tp.breakfastUnits, tp.brunchUnits, name),
          style: t.text.body,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppText.of(context).topupHistoryCancelButton)),
          NbButton(
            label: AppText.of(context).topupHistoryReverseButton,
            background: t.color.reject,
            foreground: t.color.onReject,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    ReversalResult? r;
    final ran = await runGuarded(context, () async {
      r = await ref.read(backendProvider).reverseTopup(tp.id);
    });
    if (!ran || r == null || !context.mounted) return;
    showNbSnack(context, AppText.of(context).reversalText(r!), ok: r!.success);
    if (r!.success) ref.invalidate(_historyProvider);
  }
}
