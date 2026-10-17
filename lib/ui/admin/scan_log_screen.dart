import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../domain/ledger.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/nb_surface.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/labels.dart';
import '../../l10n/messages.dart';

final _scansProvider = FutureProvider.autoDispose<List<ScanRecord>>(
    (ref) => ref.watch(backendProvider).recentScans(limit: 300));

/// Scan audit log + reversal (PRD §6.4). Reversal is only offered on an
/// accepted, not-yet-reversed scan; the host still enforces the time window.
class ScanLogScreen extends ConsumerWidget {
  const ScanLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final scans = ref.watch(_scansProvider);
    final fmt = DateFormat('MMM d, HH:mm');

    return Scaffold(
      appBar: AppBar(title: Text(AppText.of(context).scanLogScreenTitle)),
      body: AsyncView<List<ScanRecord>>(
        value: scans,
        onRetry: () => ref.invalidate(_scansProvider),
        loadingLabel: AppText.of(context).scanLogScreenLoading,
        empty: NbEmpty(
          icon: Icons.qr_code_scanner,
          title: AppText.of(context).scanLogScreenEmptyTitle,
          quips: EmptyQuips.scans(context),
        ),
        builder: (list) => ListView.separated(
          padding: const EdgeInsets.all(NbSpace.md),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: NbSpace.sm),
          itemBuilder: (_, i) {
            final s = list[i];
            final reversible = s.result == 'accepted' && !s.reversed;
            return NbSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            '${s.memberName} · ${AppText.of(context).mealLabel(s.mealType)}',
                            style: t.text.body),
                      ),
                      if (s.reversed)
                        Text(AppText.of(context).scanLogScreenReversedLabel,
                            style: t.text.label.copyWith(color: t.color.reject))
                      else if (s.viaGrace)
                        Text(AppText.of(context).scanLogScreenGraceLabel,
                            style: t.text.label.copyWith(color: t.color.warn)),
                    ],
                  ),
                  Text(fmt.format(s.scannedAt.toLocal()), style: t.text.label),
                  if (reversible) ...[
                    const SizedBox(height: NbSpace.sm),
                    NbButton.secondary(
                      label: AppText.of(context).scanLogScreenReverseButton,
                      onPressed: () async {
                        ReversalResult? r;
                        final ran = await runGuarded(context, () async {
                          r = await ref.read(backendProvider).reverseScan(s.id);
                        });
                        if (!ran || r == null || !context.mounted) return;
                        // Refused reversals are answers, not crashes: say why.
                        showNbSnack(
                            context, AppText.of(context).reversalText(r!),
                            ok: r!.success);
                        if (r!.success) ref.invalidate(_scansProvider);
                      },
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
}
