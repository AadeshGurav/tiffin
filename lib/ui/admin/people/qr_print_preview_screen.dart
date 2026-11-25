import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/print_layout.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared_widgets/nb_feedback.dart';
import '../../shared_widgets/qr_card.dart';
import '../../theme/tokens.dart';
import 'qr_sheet_pdf.dart';

/// Draws every card, assembles the PDF, and shows it with the platform's own
/// Print and Share actions — so it works with any printer, or as a file.
class QrPrintPreviewScreen extends StatefulWidget {
  const QrPrintPreviewScreen({
    super.key,
    required this.cards,
    required this.settings,
  });

  final List<QrCardData> cards;
  final PrintSettings settings;

  @override
  State<QrPrintPreviewScreen> createState() => _QrPrintPreviewScreenState();
}

class _QrPrintPreviewScreenState extends State<QrPrintPreviewScreen> {
  /// How many cards are drawn so far, for the progress line.
  final _done = ValueNotifier<int>(0);
  late final Future<Uint8List> _pdf = _buildPdf();

  /// 300 dpi: sharp enough that a small QR module still scans from paper.
  static const _pixelsPerMm = 11.8;

  Future<Uint8List> _buildPdf() async {
    final plan = SheetPlan.from(widget.settings);
    final pngs = <Uint8List>[];
    for (final card in widget.cards) {
      pngs.add(await renderQrCardPng(
        card,
        sizeMm: Size(plan.cardWidth, plan.cardHeight),
        pixelsPerMm: _pixelsPerMm,
      ));
      _done.value = pngs.length;
    }
    return buildQrSheetPdf(cardPngs: pngs, plan: plan);
  }

  @override
  void dispose() {
    _done.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final plan = SheetPlan.from(widget.settings);
    const mm = PdfPageFormat.mm;
    return Scaffold(
      appBar: AppBar(title: Text(text.qrPrintPreviewTitle)),
      body: FutureBuilder<Uint8List>(
        future: _pdf,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(NbSpace.lg),
                child: ErrorPanel(
                    error: snapshot.error!, stack: snapshot.stackTrace),
              ),
            );
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return ValueListenableBuilder<int>(
              valueListenable: _done,
              builder: (_, done, __) => NbLoading(
                  label: text.qrPrintBuilding(done, widget.cards.length)),
            );
          }
          return PdfPreview(
            build: (_) async => bytes,
            // The layout was chosen on the previous screen; the preview's own
            // paper pickers would silently disagree with it.
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            initialPageFormat:
                PdfPageFormat(plan.pageWidth * mm, plan.pageHeight * mm),
            pdfFileName: 'qr-cards.pdf',
          );
        },
      ),
    );
  }
}
