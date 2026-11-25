import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/ui/shared_widgets/qr_card.dart';
import 'package:tiffin/ui/theme/category_palette.dart';

void main() {
  final teal = CategoryColor.teal.color;
  final card = QrCardData(
    qrData: '3fa91c0be2d4',
    memberName: 'आशा पाटील',
    categoryName: 'जैन',
    canteenName: 'Tiffin',
    color: teal,
  );

  /// Decodes [png] and returns the pixel at ([x], [y]).
  Future<Color> pixelAt(List<int> png, int x, int y) async {
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(png));
    final image = (await codec.getNextFrame()).image;
    final bytes = (await image.toByteData())!;
    final i = (y * image.width + x) * 4;
    final c = Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i),
        bytes.getUint8(i + 1), bytes.getUint8(i + 2));
    image.dispose();
    return c;
  }

  testWidgets('a stacked card is a PNG framed in the category colour',
      (tester) async {
    await tester.runAsync(() async {
      const mm = Size(40, 60);
      final png = await renderQrCardPng(card, sizeMm: mm);
      expect(png.sublist(1, 4), 'PNG'.codeUnits);
      // Mid-left edge, inside the frame stroke.
      final w = (mm.width * 11.8).round(), h = (mm.height * 11.8).round();
      final edge = await pixelAt(png, (w * 0.02).round(), h ~/ 2);
      expect(edge.toARGB32(), teal.toARGB32());
    });
  });

  testWidgets('a wide ID-card layout renders too', (tester) async {
    await tester.runAsync(() async {
      final png = await renderQrCardPng(card, sizeMm: const Size(85.6, 54));
      expect(png, isNotEmpty);
    });
  });

  testWidgets('an overlong name is cut, not thrown', (tester) async {
    await tester.runAsync(() async {
      final long = QrCardData(
        qrData: card.qrData,
        memberName: 'A very long member name ' * 12,
        categoryName: 'Category ' * 10,
        canteenName: 'Canteen ' * 10,
        color: kNeutralCardColor,
      );
      expect(
          await renderQrCardPng(long, sizeMm: const Size(40, 60)), isNotEmpty);
    });
  });
}
