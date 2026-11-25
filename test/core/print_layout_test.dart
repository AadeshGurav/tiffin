import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/core/print_layout.dart';

void main() {
  SheetPlan plan(PrintSettings s) => SheetPlan.from(s);

  group('grid', () {
    test('A4 portrait, 40x60 cards, 8 mm margin, 4 mm gap -> 4 x 4', () {
      // width: (210-16+4)/44 = 4.5 -> 4; height: (297-16+4)/64 = 4.45 -> 4
      final p = plan(const PrintSettings());
      expect((p.columns, p.rows, p.cardsPerPage), (4, 4, 16));
      expect(p.fits, isTrue);
    });

    test('landscape swaps the paper sides', () {
      final p = plan(const PrintSettings(landscape: true));
      expect((p.pageWidth, p.pageHeight), (297, 210));
      // (297-16+4)/44 = 6.47 -> 6; (210-16+4)/64 = 3.09 -> 3
      expect((p.columns, p.rows), (6, 3));
    });

    test('a custom paper typed wide-first is still portrait when asked', () {
      final p = plan(const PrintSettings(
        paper: PaperPreset.custom,
        customPaperWidth: 300,
        customPaperHeight: 200,
      ));
      expect((p.pageWidth, p.pageHeight), (200, 300));
    });

    test('pagesFor rounds up and is zero when nothing prints', () {
      final p = plan(const PrintSettings()); // 16 per page
      expect(p.pagesFor(0), 0);
      expect(p.pagesFor(1), 1);
      expect(p.pagesFor(16), 1);
      expect(p.pagesFor(17), 2);
      expect(p.pagesFor(100), 7);
    });

    test('exact fits are not lost to float error', () {
      // Three 63.3 mm cards + two 0.1 mm gaps + no margins on A4 width 210.
      final p = plan(const PrintSettings(
        card: CardPreset.custom,
        customCardWidth: 69.9,
        customCardHeight: 100,
        margin: 0,
        gap: 0.1,
      ));
      expect(p.columns, 3);
    });

    test('a zero gap and zero margin pack edge to edge', () {
      final p = plan(const PrintSettings(margin: 0, gap: 0));
      expect((p.columns, p.rows), (5, 4)); // 210/40, 297/60
    });
  });

  group('rolls and ID-card stock', () {
    test('a roll is one row per page, as long as the card needs', () {
      final p = plan(const PrintSettings(paper: PaperPreset.roll80, margin: 4));
      // (80-8+4)/44 = 1.7 -> 1 column
      expect((p.columns, p.rows), (1, 1));
      expect(p.pageWidth, 80);
      expect(p.pageHeight, 60 + 8);
      expect(p.pagesFor(5), 5);
    });

    test('a 58 mm roll holds one 40 mm card but not an 85.6 mm one', () {
      expect(
          plan(const PrintSettings(paper: PaperPreset.roll58, margin: 4)).fits,
          isTrue);
      final wide = plan(const PrintSettings(
          paper: PaperPreset.roll58, card: CardPreset.id, margin: 4));
      expect(wide.problem, LayoutProblem.cardTooLarge);
    });

    test('CR80 stock takes one ID card when the margin is zero', () {
      final p = plan(const PrintSettings(
        paper: PaperPreset.cr80,
        landscape: true,
        card: CardPreset.id,
        margin: 0,
        gap: 0,
      ));
      expect((p.pageWidth, p.pageHeight), (85.6, 54));
      expect(p.cardsPerPage, 1);
    });
  });

  group('impossible combinations', () {
    test('a card bigger than the page', () {
      final p = plan(const PrintSettings(
          paper: PaperPreset.a5,
          card: CardPreset.large,
          landscape: true,
          margin: 20));
      // A5 landscape is 210 x 148; with 20 mm margins only 108 mm of height
      // is left for a 120 mm card.
      expect(p.problem, LayoutProblem.cardTooLarge);
      expect(p.cardsPerPage, 0);
      expect(p.pagesFor(10), 0);
    });

    test('margins that eat the whole page', () {
      final p = plan(const PrintSettings(margin: 110));
      expect(p.problem, LayoutProblem.cardTooLarge);
    });

    test('a zero or blank size is reported as missing, not as a crash', () {
      expect(
          plan(const PrintSettings(card: CardPreset.custom, customCardWidth: 0))
              .problem,
          LayoutProblem.missingSize);
      expect(
          plan(const PrintSettings(
                  paper: PaperPreset.custom, customPaperHeight: 0))
              .problem,
          LayoutProblem.missingSize);
    });
  });

  group('placement', () {
    test('cards sit in reading order and the grid is centred sideways', () {
      final p = plan(const PrintSettings()); // 4 x 4 on A4, 8 / 4 mm
      // grid width = 4*40 + 3*4 = 172 -> left = (210-172)/2 = 19
      expect(p.cellOrigin(0), (x: 19.0, y: 8.0));
      expect(p.cellOrigin(1), (x: 63.0, y: 8.0));
      expect(p.cellOrigin(4), (x: 19.0, y: 72.0));
    });

    test('the slot wraps to the next page', () {
      final p = plan(const PrintSettings());
      expect(p.cellOrigin(16), p.cellOrigin(0));
    });

    test('every card stays inside the margins', () {
      final p = plan(const PrintSettings());
      for (var slot = 0; slot < p.cardsPerPage; slot++) {
        final c = p.cellOrigin(slot);
        expect(c.x, greaterThanOrEqualTo(p.margin));
        expect(c.y, greaterThanOrEqualTo(p.margin));
        expect(c.x + p.cardWidth, lessThanOrEqualTo(p.pageWidth - p.margin));
        expect(c.y + p.cardHeight, lessThanOrEqualTo(p.pageHeight - p.margin));
      }
    });
  });

  group('cut marks', () {
    test('are capped at 3 mm and fit in half a gap', () {
      expect(plan(const PrintSettings(gap: 10)).cutMarkLength, 3);
      expect(plan(const PrintSettings(gap: 4)).cutMarkLength, 2);
    });

    test('vanish when off or when there is no room', () {
      expect(plan(const PrintSettings(cutMarks: false)).cutMarkLength, 0);
      expect(plan(const PrintSettings(gap: 0)).cutMarkLength, 0);
      expect(plan(const PrintSettings(margin: 0)).cutMarkLength, 0);
    });
  });

  group('saved settings', () {
    test('survive a JSON round trip', () {
      const s = PrintSettings(
        paper: PaperPreset.custom,
        customPaperWidth: 100.5,
        customPaperHeight: 150,
        landscape: true,
        card: CardPreset.custom,
        customCardWidth: 33.3,
        customCardHeight: 44,
        margin: 5,
        gap: 0,
        cutMarks: false,
      );
      expect(PrintSettings.fromJson(s.toJson()).toJson(), s.toJson());
    });

    test('fall back to defaults for missing, unknown or negative values', () {
      final s = PrintSettings.fromJson({
        'paper': 'tabloid',
        'margin': -3,
        'card': 7,
      });
      const d = PrintSettings();
      expect((s.paper, s.margin, s.card), (d.paper, d.margin, d.card));
    });
  });

  test('formatMm drops a pointless decimal', () {
    expect(formatMm(210), '210');
    expect(formatMm(85.6), '85.6');
    expect(formatMm(215.9), '215.9');
    expect(formatMm(40.04), '40');
  });
}
