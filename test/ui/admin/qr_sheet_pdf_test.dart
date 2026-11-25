import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/core/print_layout.dart';
import 'package:tiffin/ui/admin/people/qr_sheet_pdf.dart';
import 'package:tiffin/ui/shared_widgets/qr_card.dart';

void main() {
  const card = QrCardData(
    qrData: '3fa91c0be2d4',
    memberName: 'Asha',
    categoryName: 'Jain',
    canteenName: 'Tiffin',
    color: Color(0xFF00696B),
  );

  int pageCount(List<int> pdf) => RegExp(r'/Type\s*/Page(?!s)')
      .allMatches(latin1.decode(pdf, allowInvalid: true))
      .length;

  testWidgets('a PDF has one page per full grid of cards', (tester) async {
    await tester.runAsync(() async {
      final png = await renderQrCardPng(card,
          sizeMm: const Size(40, 60), pixelsPerMm: 4);
      // 4 x 4 = 16 per page on A4, so 17 cards need two pages.
      final plan = SheetPlan.from(const PrintSettings());
      final pdf = await buildQrSheetPdf(
          cardPngs: List.filled(17, png), plan: plan, compress: false);
      expect(pageCount(pdf), 2);
      expect(plan.pagesFor(17), 2);
    });
  });

  testWidgets('cut marks and a roll layout build without error',
      (tester) async {
    await tester.runAsync(() async {
      final png = await renderQrCardPng(card,
          sizeMm: const Size(40, 60), pixelsPerMm: 4);
      final roll = SheetPlan.from(
          const PrintSettings(paper: PaperPreset.roll80, margin: 4, gap: 6));
      expect(roll.cutMarkLength, greaterThan(0));
      final pdf = await buildQrSheetPdf(
          cardPngs: List.filled(3, png), plan: roll, compress: false);
      expect(pageCount(pdf), 3);
    });
  });
}
