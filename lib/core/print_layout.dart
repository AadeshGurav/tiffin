// Pure layout maths for printing member QR cards on any paper.
//
// No Flutter, no PDF: everything is millimetres in, millimetres out, so the
// "how many cards fit?" question is unit-testable and the screen, the PDF and
// the cut marks all agree because they ask the same SheetPlan.

/// Paper the canteen might print on. Sizes are the short and long side in mm;
/// a roll has a fixed width and no length (its pages are cut to the card).
enum PaperPreset {
  a4(210, 297),
  letter(215.9, 279.4),
  a5(148, 210),
  legal(215.9, 355.6),
  roll58(58, null),
  roll80(80, null),
  cr80(54, 85.6),
  custom(0, 0);

  const PaperPreset(this.width, this.length);

  final double width;

  /// Null for a continuous roll.
  final double? length;

  bool get isRoll => length == null;
}

/// Card sizes, as printed (width × height in mm).
enum CardPreset {
  small(40, 60),
  id(85.6, 54),
  large(90, 120),
  custom(0, 0);

  const CardPreset(this.width, this.height);

  final double width;
  final double height;
}

/// Why a combination of paper, card and spacing can't be printed.
enum LayoutProblem {
  /// A paper or card side is zero or missing.
  missingSize,

  /// The card is bigger than the printable area (paper minus margins).
  cardTooLarge,
}

/// Everything the admin can adjust, as stored on the device between sessions.
class PrintSettings {
  const PrintSettings({
    this.paper = PaperPreset.a4,
    this.customPaperWidth = 210,
    this.customPaperHeight = 297,
    this.landscape = false,
    this.card = CardPreset.small,
    this.customCardWidth = 40,
    this.customCardHeight = 60,
    this.margin = 8,
    this.gap = 4,
    this.cutMarks = true,
  });

  factory PrintSettings.fromJson(Map<String, dynamic> j) {
    const d = PrintSettings();
    double mm(String key, double fallback) {
      final v = (j[key] as num?)?.toDouble();
      return v == null || v < 0 || v.isNaN ? fallback : v;
    }

    T pick<T extends Enum>(List<T> values, String key, T fallback) {
      for (final v in values) {
        if (v.name == j[key]) return v;
      }
      return fallback;
    }

    return PrintSettings(
      paper: pick(PaperPreset.values, 'paper', d.paper),
      customPaperWidth: mm('customPaperWidth', d.customPaperWidth),
      customPaperHeight: mm('customPaperHeight', d.customPaperHeight),
      landscape: j['landscape'] as bool? ?? d.landscape,
      card: pick(CardPreset.values, 'card', d.card),
      customCardWidth: mm('customCardWidth', d.customCardWidth),
      customCardHeight: mm('customCardHeight', d.customCardHeight),
      margin: mm('margin', d.margin),
      gap: mm('gap', d.gap),
      cutMarks: j['cutMarks'] as bool? ?? d.cutMarks,
    );
  }

  final PaperPreset paper;
  final double customPaperWidth;
  final double customPaperHeight;
  final bool landscape;
  final CardPreset card;
  final double customCardWidth;
  final double customCardHeight;
  final double margin;
  final double gap;
  final bool cutMarks;

  PrintSettings copyWith({
    PaperPreset? paper,
    double? customPaperWidth,
    double? customPaperHeight,
    bool? landscape,
    CardPreset? card,
    double? customCardWidth,
    double? customCardHeight,
    double? margin,
    double? gap,
    bool? cutMarks,
  }) =>
      PrintSettings(
        paper: paper ?? this.paper,
        customPaperWidth: customPaperWidth ?? this.customPaperWidth,
        customPaperHeight: customPaperHeight ?? this.customPaperHeight,
        landscape: landscape ?? this.landscape,
        card: card ?? this.card,
        customCardWidth: customCardWidth ?? this.customCardWidth,
        customCardHeight: customCardHeight ?? this.customCardHeight,
        margin: margin ?? this.margin,
        gap: gap ?? this.gap,
        cutMarks: cutMarks ?? this.cutMarks,
      );

  Map<String, dynamic> toJson() => {
        'paper': paper.name,
        'customPaperWidth': customPaperWidth,
        'customPaperHeight': customPaperHeight,
        'landscape': landscape,
        'card': card.name,
        'customCardWidth': customCardWidth,
        'customCardHeight': customCardHeight,
        'margin': margin,
        'gap': gap,
        'cutMarks': cutMarks,
      };

  double get cardWidth =>
      card == CardPreset.custom ? customCardWidth : card.width;
  double get cardHeight =>
      card == CardPreset.custom ? customCardHeight : card.height;
}

/// How cards land on pages for one [PrintSettings].
class SheetPlan {
  const SheetPlan._({
    required this.pageWidth,
    required this.pageHeight,
    required this.cardWidth,
    required this.cardHeight,
    required this.margin,
    required this.gap,
    required this.cutMarks,
    required this.columns,
    required this.rows,
    required this.problem,
  });

  /// Length of one cut mark, mm. Short enough to stay inside a normal gap.
  static const _maxCutMark = 3.0;

  /// Tolerance so 190 mm of space still fits 4 × 47.5 mm despite float error.
  static const _epsilon = 1e-9;

  factory SheetPlan.from(PrintSettings s) {
    final isRoll = s.paper.isRoll;
    final paperW =
        s.paper == PaperPreset.custom ? s.customPaperWidth : s.paper.width;
    final paperL = s.paper == PaperPreset.custom
        ? s.customPaperHeight
        : (s.paper.length ?? 0);
    final cardW = s.cardWidth;
    final cardH = s.cardHeight;

    // Orientation just says which side is long, so the order the admin typed a
    // custom size in doesn't matter. A roll has no orientation: its pages are
    // as wide as the roll and as long as one row of cards.
    var pageW = paperW;
    var pageH = isRoll ? cardH + 2 * s.margin : paperL;
    if (!isRoll) {
      final short = paperW < paperL ? paperW : paperL;
      final long = paperW < paperL ? paperL : paperW;
      pageW = s.landscape ? long : short;
      pageH = s.landscape ? short : long;
    }

    SheetPlan make(int cols, int rows, LayoutProblem? problem) => SheetPlan._(
          pageWidth: pageW,
          pageHeight: pageH,
          cardWidth: cardW,
          cardHeight: cardH,
          margin: s.margin,
          gap: s.gap,
          cutMarks: s.cutMarks,
          columns: cols,
          rows: rows,
          problem: problem,
        );

    if (pageW <= 0 || pageH <= 0 || cardW <= 0 || cardH <= 0) {
      return make(0, 0, LayoutProblem.missingSize);
    }
    final cols =
        ((pageW - 2 * s.margin + s.gap + _epsilon) / (cardW + s.gap)).floor();
    final rows = isRoll
        ? 1
        : ((pageH - 2 * s.margin + s.gap + _epsilon) / (cardH + s.gap)).floor();
    if (cols < 1 || rows < 1) return make(0, 0, LayoutProblem.cardTooLarge);
    return make(cols, rows, null);
  }

  final double pageWidth;
  final double pageHeight;
  final double cardWidth;
  final double cardHeight;
  final double margin;
  final double gap;
  final bool cutMarks;
  final int columns;
  final int rows;
  final LayoutProblem? problem;

  bool get fits => problem == null;

  int get cardsPerPage => columns * rows;

  /// The area cards may occupy, after margins.
  double get printableWidth => pageWidth - 2 * margin;
  double get printableHeight => pageHeight - 2 * margin;

  /// Pages needed for [cardCount] cards (0 when there is nothing to print or
  /// the layout does not fit).
  int pagesFor(int cardCount) =>
      !fits || cardCount <= 0 ? 0 : (cardCount / cardsPerPage).ceil();

  /// Top-left of the card in [slot] (0-based, row by row) on its page, mm. The
  /// grid is centred sideways so leftover width is split, not piled on one side.
  ({double x, double y}) cellOrigin(int slot) {
    final gridWidth = columns * cardWidth + (columns - 1) * gap;
    final left = (pageWidth - gridWidth) / 2;
    final column = slot % columns;
    final row = (slot ~/ columns) % rows;
    return (
      x: left + column * (cardWidth + gap),
      y: margin + row * (cardHeight + gap),
    );
  }

  /// Length of each cut mark, mm: zero when marks are off or there is no room
  /// (a mark must fit in half a gap, and in the margin at the page edge).
  double get cutMarkLength {
    if (!cutMarks) return 0;
    final room = [_maxCutMark, gap / 2, margin].reduce((a, b) => a < b ? a : b);
    return room < 0.5 ? 0 : room;
  }
}

/// A millimetre value for display: "85.6", "210" (no trailing ".0").
String formatMm(double mm) {
  final rounded = (mm * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}
