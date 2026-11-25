import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/print_layout.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared_widgets/nb_text_field.dart';
import '../../theme/tokens.dart';

/// Paper, card and spacing controls, plus the computed grid. Stateless about
/// the layout itself: it shows [settings] and reports every edit through
/// [onChanged], so the screen owns saving it.
class QrPrintSettingsForm extends StatelessWidget {
  const QrPrintSettingsForm({
    super.key,
    required this.settings,
    required this.cardCount,
    required this.onChanged,
  });

  final PrintSettings settings;
  final int cardCount;
  final ValueChanged<PrintSettings> onChanged;

  /// Paper names that are the same in every language.
  static const _paperNames = {
    PaperPreset.a4: 'A4',
    PaperPreset.letter: 'Letter',
    PaperPreset.a5: 'A5',
    PaperPreset.legal: 'Legal',
  };

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final s = settings;
    const gap = SizedBox(height: NbSpace.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<PaperPreset>(
          initialValue: s.paper,
          isExpanded: true,
          decoration: InputDecoration(labelText: text.qrPrintPaperSizeLabel),
          items: [
            for (final p in PaperPreset.values)
              DropdownMenuItem(value: p, child: Text(_paperLabel(text, p))),
          ],
          onChanged: (p) => onChanged(s.copyWith(paper: p)),
        ),
        if (s.paper == PaperPreset.custom) ...[
          gap,
          _SizePair(
            width: s.customPaperWidth,
            height: s.customPaperHeight,
            onChanged: (w, h) => onChanged(
                s.copyWith(customPaperWidth: w, customPaperHeight: h)),
          ),
        ],
        if (!s.paper.isRoll) ...[
          gap,
          // A segmented control keeps both options visible (recognition over
          // recall) and each segment is a full-height touch target.
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.crop_portrait),
                  label: Text(text.qrPrintPortrait)),
              ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.crop_landscape),
                  label: Text(text.qrPrintLandscape)),
            ],
            selected: {s.landscape},
            onSelectionChanged: (v) =>
                onChanged(s.copyWith(landscape: v.first)),
          ),
        ],
        gap,
        DropdownButtonFormField<CardPreset>(
          initialValue: s.card,
          isExpanded: true,
          decoration: InputDecoration(labelText: text.qrPrintCardSizeLabel),
          items: [
            for (final c in CardPreset.values)
              DropdownMenuItem(value: c, child: Text(_cardLabel(text, c))),
          ],
          onChanged: (c) => onChanged(s.copyWith(card: c)),
        ),
        if (s.card == CardPreset.custom) ...[
          gap,
          _SizePair(
            width: s.customCardWidth,
            height: s.customCardHeight,
            onChanged: (w, h) =>
                onChanged(s.copyWith(customCardWidth: w, customCardHeight: h)),
          ),
        ],
        gap,
        _MmField(
          label: text.qrPrintMarginLabel,
          value: s.margin,
          onChanged: (v) => onChanged(s.copyWith(margin: v)),
        ),
        gap,
        _MmField(
          label: text.qrPrintGapLabel,
          value: s.gap,
          onChanged: (v) => onChanged(s.copyWith(gap: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: s.cutMarks,
          title: Text(text.qrPrintCutMarks),
          subtitle: Text(text.qrPrintCutMarksHint),
          onChanged: (v) => onChanged(s.copyWith(cutMarks: v)),
        ),
        gap,
        QrPrintFitSummary(plan: SheetPlan.from(s), cardCount: cardCount),
      ],
    );
  }

  String _paperLabel(AppText text, PaperPreset p) => switch (p) {
        PaperPreset.roll58 ||
        PaperPreset.roll80 =>
          text.qrPrintPaperRoll(formatMm(p.width)),
        PaperPreset.cr80 => text.qrPrintPresetWithSize(
            text.qrPrintPaperCr80, formatMm(p.width), formatMm(p.length!)),
        PaperPreset.custom => text.qrPrintCustom,
        _ => text.qrPrintPresetWithSize(
            _paperNames[p]!, formatMm(p.width), formatMm(p.length!)),
      };

  String _cardLabel(AppText text, CardPreset c) {
    final name = switch (c) {
      CardPreset.small => text.qrPrintCardSmall,
      CardPreset.id => text.qrPrintCardId,
      CardPreset.large => text.qrPrintCardLarge,
      CardPreset.custom => null,
    };
    return name == null
        ? text.qrPrintCustom
        : text.qrPrintPresetWithSize(
            name, formatMm(c.width), formatMm(c.height));
  }
}

/// The result of the maths, in words: "12 cards per page (3 × 4), 3 pages", or
/// why the combination can't be printed.
class QrPrintFitSummary extends StatelessWidget {
  const QrPrintFitSummary(
      {super.key, required this.plan, required this.cardCount});

  final SheetPlan plan;
  final int cardCount;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = AppText.of(context);
    final problem = plan.problem;
    final String message;
    if (problem == null) {
      message =
          '${text.qrPrintFitPerPage(plan.cardsPerPage, plan.columns, plan.rows)}\n'
          '${text.qrPrintFitPages(plan.pagesFor(cardCount))}';
    } else {
      message = switch (problem) {
        LayoutProblem.missingSize => text.qrPrintProblemMissingSize,
        LayoutProblem.cardTooLarge => text.qrPrintProblemCardTooLarge(
            formatMm(plan.cardWidth),
            formatMm(plan.cardHeight),
            formatMm(plan.printableWidth),
            formatMm(plan.printableHeight),
          ),
      };
    }
    // Icon + words, so a problem is never signalled by colour alone (§12.2).
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(NbSpace.md),
        decoration: BoxDecoration(
          color: t.color.surfaceMuted,
          border: Border.all(
            color: problem == null ? t.color.border : t.color.reject,
            width: t.shape.borderBase,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              problem == null ? Icons.grid_view : Icons.error_outline,
              color: problem == null ? t.color.ink : t.color.reject,
            ),
            const SizedBox(width: NbSpace.sm),
            Expanded(child: Text(message, style: t.text.body)),
          ],
        ),
      ),
    );
  }
}

class _SizePair extends StatelessWidget {
  const _SizePair({
    required this.width,
    required this.height,
    required this.onChanged,
  });

  final double width;
  final double height;
  final void Function(double width, double height) onChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    // Stacked, not side by side: one column keeps tab order and reflow simple
    // (CLAUDE.md §11.6.7).
    return Column(
      children: [
        _MmField(
          label: text.qrPrintWidthMmLabel,
          value: width,
          onChanged: (w) => onChanged(w, height),
        ),
        const SizedBox(height: NbSpace.md),
        _MmField(
          label: text.qrPrintHeightMmLabel,
          value: height,
          onChanged: (h) => onChanged(width, h),
        ),
      ],
    );
  }
}

/// A millimetre input. Keeps its own controller so typing "8." doesn't get
/// rewritten to "8" under the cursor; blank counts as 0.
class _MmField extends StatefulWidget {
  const _MmField(
      {required this.label, required this.value, required this.onChanged});

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_MmField> createState() => _MmFieldState();
}

class _MmFieldState extends State<_MmField> {
  late final _controller = TextEditingController(text: formatMm(widget.value));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NbTextField(
        label: widget.label,
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        onChanged: (v) => widget.onChanged(double.tryParse(v) ?? 0),
      );
}
