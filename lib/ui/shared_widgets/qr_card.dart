import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/member.dart';
import '../theme/category_palette.dart';

/// Everything one printed member card says.
@immutable
class QrCardData {
  const QrCardData({
    required this.qrData,
    required this.memberName,
    required this.categoryName,
    required this.canteenName,
    required this.color,
  });

  final String qrData;
  final String memberName;
  final String categoryName;
  final String canteenName;

  /// The category colour: the frame and the category label. The QR itself is
  /// always black on white, because a coloured code scans less reliably.
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is QrCardData &&
      other.qrData == qrData &&
      other.memberName == memberName &&
      other.categoryName == categoryName &&
      other.canteenName == canteenName &&
      other.color == color;

  @override
  int get hashCode =>
      Object.hash(qrData, memberName, categoryName, canteenName, color);
}

/// Draws one member card at any size: a coloured frame, the QR, the member's
/// name, then the category name in the frame's colour.
///
/// Drawn with Flutter's own text engine (not the `pdf` package's) so Hindi and
/// Marathi names are shaped correctly — see BillView for the same reason. One
/// painter serves the on-screen card and the printed PNG, so they cannot drift.
///
/// Fixed ink-on-white on purpose: it is a printable object, not a themed
/// surface.
class QrCardPainter extends CustomPainter {
  const QrCardPainter(this.card);

  final QrCardData card;

  static const _ink = Color(0xFF111111);

  /// Cards wider than this ratio put the text beside the QR, not under it.
  static const _wideRatio = 1.25;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide;
    final frame = u * 0.05;
    final radius = Radius.circular(u * 0.06);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius((Offset.zero & size).deflate(frame / 2), radius),
      Paint()
        ..color = card.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = frame,
    );

    final inner = (Offset.zero & size).deflate(frame + u * 0.06);
    if (size.width > size.height * _wideRatio) {
      _paintWide(canvas, inner, u);
    } else {
      _paintStacked(canvas, inner, u);
    }
  }

  void _paintStacked(Canvas canvas, Rect inner, double u) {
    final canteen = _text(card.canteenName, u * 0.06, _ink, inner.width, 1);
    final name =
        _text(card.memberName, u * 0.085, _ink, inner.width, 2, bold: true);
    final category = _text(
        card.categoryName, u * 0.075, card.color, inner.width, 1,
        bold: true);
    final gap = u * 0.03;
    final textHeight = canteen.height + name.height + category.height + gap * 4;
    final qrSide = (inner.height - textHeight).clamp(0.0, inner.width);

    var y = inner.top;
    _paintCentered(canvas, canteen, inner, y);
    y += canteen.height + gap;
    _paintQr(
        canvas, Rect.fromLTWH(inner.center.dx - qrSide / 2, y, qrSide, qrSide));
    y += qrSide + gap;
    _paintCentered(canvas, name, inner, y);
    y += name.height + gap;
    _paintCentered(canvas, category, inner, y);
  }

  void _paintWide(Canvas canvas, Rect inner, double u) {
    final qrSide = inner.height.clamp(0.0, inner.width * 0.5);
    _paintQr(canvas, Rect.fromLTWH(inner.left, inner.top, qrSide, qrSide));

    final column = Rect.fromLTRB(
        inner.left + qrSide + u * 0.06, inner.top, inner.right, inner.bottom);
    final canteen = _text(card.canteenName, u * 0.07, _ink, column.width, 1);
    final name =
        _text(card.memberName, u * 0.11, _ink, column.width, 2, bold: true);
    final category = _text(
        card.categoryName, u * 0.09, card.color, column.width, 1,
        bold: true);
    final gap = u * 0.04;
    final block = canteen.height + name.height + category.height + gap * 2;
    var y =
        column.top + (column.height - block).clamp(0.0, double.infinity) / 2;
    for (final line in [canteen, name, category]) {
      line.paint(canvas, Offset(column.left, y));
      y += line.height + gap;
    }
  }

  void _paintQr(Canvas canvas, Rect box) {
    // Extra quiet zone inside the box: scanners need empty space round a code.
    final area = box.deflate(box.width * 0.06);
    canvas.save();
    canvas.translate(area.left, area.top);
    QrPainter(
      data: card.qrData,
      version: QrVersions.auto,
      gapless: true,
      // High correction so a scuffed card still scans (as QrService does).
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      eyeStyle:
          const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
      dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square, color: Colors.black),
    ).paint(canvas, area.size);
    canvas.restore();
  }

  void _paintCentered(Canvas canvas, TextPainter text, Rect inner, double y) =>
      text.paint(canvas, Offset(inner.center.dx - text.width / 2, y));

  TextPainter _text(
    String value,
    double fontSize,
    Color color,
    double maxWidth,
    int maxLines, {
    bool bold = false,
  }) =>
      TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            height: 1.15,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);

  @override
  bool shouldRepaint(QrCardPainter old) => old.card != card;
}

/// The card as it appears on screen, at the given width/height ratio.
class QrCardView extends StatelessWidget {
  const QrCardView({super.key, required this.card, this.aspectRatio = 2 / 3});

  final QrCardData card;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '${card.memberName}, ${card.categoryName}',
        image: true,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: CustomPaint(painter: QrCardPainter(card)),
        ),
      );
}

/// Renders [card] to a PNG at [sizeMm] and [pixelsPerMm] (300 dpi ≈ 11.8).
Future<Uint8List> renderQrCardPng(
  QrCardData card, {
  required Size sizeMm,
  double pixelsPerMm = 11.8,
}) async {
  final size = sizeMm * pixelsPerMm;
  final recorder = ui.PictureRecorder();
  QrCardPainter(card).paint(Canvas(recorder), size);
  final image = await recorder
      .endRecording()
      .toImage(size.width.round(), size.height.round());
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError(
          'Rendering the QR card for ${card.memberName} gave no image');
    }
    return bytes.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// The card for [member], framed in the colour of their category (neutral when
/// the category has none or no longer exists).
QrCardData qrCardFor(
  Member member, {
  required String canteenName,
  required Map<String, int?> categoryColors,
}) =>
    QrCardData(
      qrData: member.qrCodeId,
      memberName: member.name,
      categoryName: member.category,
      canteenName: canteenName,
      color: cardColorFor(categoryColors[member.category]),
    );
