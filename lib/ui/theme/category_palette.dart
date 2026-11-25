import 'dart:ui' show Color;

import 'oklch.dart';

/// The colours an admin can give a member category (the frame and label of its
/// QR cards). A fixed, named set rather than a free picker: every entry is dark
/// enough to read as text on white paper (>= 4.5:1, CLAUDE.md §12.2) and the
/// hues stay distinguishable from each other on a cheap print. Because they can
/// still look alike to a colour-blind reader, the category *name* is always
/// printed on the card too.
///
/// Authored in OKLCH (§11.4); stored on the category as the ARGB int.
enum CategoryColor {
  red(Oklch(0.50, 0.19, 27)),
  orange(Oklch(0.55, 0.15, 55)),
  olive(Oklch(0.52, 0.12, 105)),
  green(Oklch(0.48, 0.14, 150)),
  teal(Oklch(0.48, 0.10, 195)),
  blue(Oklch(0.48, 0.18, 255)),
  indigo(Oklch(0.45, 0.18, 280)),
  purple(Oklch(0.48, 0.18, 315)),
  pink(Oklch(0.52, 0.18, 355)),
  slate(Oklch(0.40, 0.03, 255));

  const CategoryColor(this._oklch);

  final Oklch _oklch;

  Color get color => _oklch.toColor();

  int get argb => color.toARGB32();

  /// The palette entry stored as [argb], or null for no colour (or a value
  /// that isn't in the palette, e.g. written by a future version).
  static CategoryColor? fromArgb(int? argb) {
    if (argb == null) return null;
    for (final c in values) {
      if (c.argb == argb) return c;
    }
    return null;
  }
}

/// What a card uses when its category has no colour: dark neutral ink, so an
/// uncoloured card still prints sharply.
const Color kNeutralCardColor = Color(0xFF3A3A3A);

/// The colour to print for a stored category colour.
Color cardColorFor(int? argb) => argb == null ? kNeutralCardColor : Color(argb);
