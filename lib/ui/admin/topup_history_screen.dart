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

typedef _History = ({List<Topup> topups, Map<int, Member> membersById});

final _historyProvider = FutureProvider.autoDispose<_History>((ref) async {
  final backend = ref.watch(backendProvider);
  final topups = await backend.listTopups(limit: 300);
  final members = await backend.listMembers();
  return (
    topups: topups,
    membersById: {for (final m in members) m.id: m},
  );
});

/// Top-up history + reversal (client's point 2). A reversal restores the
/// member's balance and flags the row; the row is kept for audit, never
/// deleted — the same treatment as a reversed scan.
class TopupHistoryScreen extends ConsumerWidget {
  const TopupHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final history = ref.watch(_historyProvider);
    final fmt = DateFormat('MMM d, y · HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Top-up history')),
      body: AsyncView<_History>(
        value: history,
        onRetry: () => ref.invalidate(_historyProvider),
        loadingLabel: 'Loading top-ups…',
        empty: const NbEmpty(
          icon: Icons.payments_outlined,
          title: 'No top-ups yet',
          quips: ['Charge a member on the Top-up & bill screen first.'],
        ),
        builder: (data) => ListView.separated(
          padding: const EdgeInsets.all(NbSpace.md),
          itemCount: data.topups.length,
          separatorBuilder: (_, __) => const SizedBox(height: NbSpace.sm),
          itemBuilder: (_, i) {
            final tp = data.topups[i];
            final name =
                data.membersById[tp.memberId]?.name ?? 'Member #${tp.memberId}';
            return NbSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name, style: t.text.body)),
                      if (tp.reversed)
                        Text('REVERSED',
                            style:
                                t.text.label.copyWith(color: t.color.reject)),
                    ],
                  ),
                  Text(
                      'L${tp.lunchUnits} B${tp.breakfastUnits} '
                      'Br${tp.brunchUnits}  ·  Rs. ${tp.amount.toStringAsFixed(2)}'
                      '  ·  ${tp.paymentMethod.wire.toUpperCase()} '
                      '(${tp.paymentStatus})',
                      style: t.text.label),
                  Text(
                      '${fmt.format(tp.createdAt.toLocal())} · by ${tp.createdBy}',
                      style: t.text.label),
                  if (tp.reversed && tp.reversedAt != null)
                    Text(
                        'Reversed ${fmt.format(tp.reversedAt!.toLocal())}'
                        '${tp.reversedBy == null ? '' : ' · by ${tp.reversedBy}'}',
                        style: t.text.label.copyWith(color: t.color.reject)),
                  if (!tp.reversed) ...[
                    const SizedBox(height: NbSpace.sm),
                    NbButton.secondary(
                      label: 'Reverse',
                      onPressed: () => _confirmReverse(context, ref, tp, name),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmReverse(
      BuildContext context, WidgetRef ref, Topup tp, String name) async {
    final t = context.tokens;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reverse this top-up?', style: t.text.heading),
        content: Text(
          'This subtracts L${tp.lunchUnits} B${tp.breakfastUnits} '
          'Br${tp.brunchUnits} back off $name and records the reversal. '
          'It cannot be undone. If those units have already been used, '
          'process a refund instead.',
          style: t.text.body,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          NbButton(
            label: 'Reverse',
            background: t.color.reject,
            foreground: t.color.onReject,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = await runGuarded(
      context,
      () async {
        final r = await ref.read(backendProvider).reverseTopup(tp.id);
        if (!r.success) throw _Msg(r.message);
      },
      successMessage: 'Top-up reversed.',
    );
    if (done) ref.invalidate(_historyProvider);
  }
}

class _Msg implements Exception {
  _Msg(this.message);
  final String message;
  @override
  String toString() => message;
}
