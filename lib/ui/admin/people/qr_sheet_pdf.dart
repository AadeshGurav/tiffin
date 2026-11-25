import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/print_layout.dart';

/// Lays pre-rendered card images onto pages of [plan]'s size.
///
/// The cards arrive as PNGs (drawn by Flutter so Devanagari names shape
/// correctly); this only places them, so it stays small and has no text.
Future<Uint8List> buildQrSheetPdf({
  required List<Uint8List> cardPngs,
  required SheetPlan plan,
  // Off only in tests, so a page can be counted in the raw bytes.
  bool compress = true,
}) {
  const mm = PdfPageFormat.mm;
  final format = PdfPageFormat(plan.pageWidth * mm, plan.pageHeight * mm);
  final perPage = plan.cardsPerPage;
  final doc = pw.Document(compress: compress);

  for (var first = 0; first < cardPngs.length; first += perPage) {
    final onPage = cardPngs.skip(first).take(perPage).toList();
    final origins = [
      for (var i = 0; i < onPage.length; i++) plan.cellOrigin(i)
    ];
    doc.addPage(pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(children: [
        for (var i = 0; i < onPage.length; i++)
          pw.Positioned(
            left: origins[i].x * mm,
            top: origins[i].y * mm,
            child: pw.Image(
              pw.MemoryImage(onPage[i]),
              width: plan.cardWidth * mm,
              height: plan.cardHeight * mm,
              fit: pw.BoxFit.fill,
            ),
          ),
        if (plan.cutMarkLength > 0)
          pw.Positioned(
            left: 0,
            top: 0,
            child: pw.CustomPaint(
              size: PdfPoint(format.width, format.height),
              painter: (canvas, size) =>
                  _drawCutMarks(canvas, size, plan, origins),
            ),
          ),
      ]),
    ));
  }
  return doc.save();
}

/// Short lines continuing each card edge outwards from its four corners, so
/// the admin can cut along them. They sit in the gap and margin, never on a card.
void _drawCutMarks(
  PdfGraphics canvas,
  PdfPoint size,
  SheetPlan plan,
  List<({double x, double y})> origins,
) {
  const mm = PdfPageFormat.mm;
  final length = plan.cutMarkLength * mm;
  canvas
    ..setStrokeColor(PdfColors.grey700)
    ..setLineWidth(0.4);
  for (final o in origins) {
    final left = o.x * mm;
    final right = (o.x + plan.cardWidth) * mm;
    // The page's y axis points up; the plan's points down.
    final top = size.y - o.y * mm;
    final bottom = size.y - (o.y + plan.cardHeight) * mm;
    for (final (cx, cy, sx, sy) in [
      (left, top, -1.0, 1.0),
      (right, top, 1.0, 1.0),
      (left, bottom, -1.0, -1.0),
      (right, bottom, 1.0, -1.0),
    ]) {
      canvas
        ..moveTo(cx, cy)
        ..lineTo(cx + sx * length, cy)
        ..moveTo(cx, cy)
        ..lineTo(cx, cy + sy * length)
        ..strokePath();
    }
  }
}
