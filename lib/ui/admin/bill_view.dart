import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/ledger.dart';
import '../../domain/member.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/labels.dart';

/// A top-up's bill (PRD §6.3), drawn by Flutter so Hindi and Marathi — names
/// included — are shaped correctly. The `pdf` package lays text out itself
/// and doesn't join Devanagari conjuncts, so the shared PDF carries a picture
/// of this widget rather than PDF text.
///
/// Fixed ink-on-paper colours on purpose: it is a printable page, not a
/// themed surface.
class BillView extends StatelessWidget {
  const BillView({
    super.key,
    required this.topup,
    required this.member,
    required this.appName,
  });

  final Topup topup;
  final Member member;
  final String appName;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    const ink = Color(0xFF1A1A1A);
    const body = TextStyle(color: ink, fontSize: 14, height: 1.4);
    final bold = body.copyWith(fontWeight: FontWeight.w700);
    String units(int l, int b, int br) => '${text.mealLunch}: $l   '
        '${text.mealBreakfast}: $b   ${text.mealBrunch}: $br';
    final after = topup.balancesAfter;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(appName, style: bold.copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          Text('${text.billId}: ${shortCode(topup.id)}', style: body),
          Text(
              '${text.billMember}: ${member.name} '
              '(${text.memberTypeLabel(member.type)})',
              style: body),
          const SizedBox(height: 12),
          Text(text.billUnitsPurchased, style: bold),
          Text(units(topup.lunchUnits, topup.breakfastUnits, topup.brunchUnits),
              style: body),
          const SizedBox(height: 8),
          Text(
              '${text.billAmount}: ${text.money(topup.amount)} '
              '(${text.paymentMethodLabel(topup.paymentMethod)})',
              style: bold),
          if (after != null) ...[
            const SizedBox(height: 12),
            Text(text.billNewBalances, style: bold),
            Text(units(after.lunch, after.breakfast, after.brunch),
                style: body),
          ],
        ],
      ),
    );
  }
}

/// Captures what [boundary] currently shows into a one-page A5 PDF.
Future<Uint8List> billPdfFrom(GlobalKey boundary) async {
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await render.toImage(pixelRatio: 3);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final doc = pw.Document()
    ..addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      build: (_) => pw.Align(
        alignment: pw.Alignment.topLeft,
        child: pw.Image(pw.MemoryImage(png!.buffer.asUint8List())),
      ),
    ));
  return doc.save();
}
