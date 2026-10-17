import 'package:flutter/material.dart';

import 'themes/clay.dart';
import 'themes/clean.dart';
import 'themes/frost.dart';
import 'themes/neobrutal.dart';
import 'tokens.dart';

/// The themes a device can be set to. Each ships a light and a dark variant —
/// dark is a mode, not a fifth theme (CLAUDE.md §11.5.10).
///
/// [wire] is the stored/transmitted name: it must stay stable, because it is
/// persisted per device and can also be set for the whole canteen.
enum TiffinThemeId {
  neobrutal(wire: 'neobrutal'),
  clean(wire: 'clean'),
  frost(wire: 'frost'),
  clay(wire: 'clay');

  const TiffinThemeId({required this.wire});

  /// Stored and synced name; its words live in the ARB files
  /// (`themeLabel` / `themeBlurb` in `l10n/labels.dart`).
  final String wire;

  /// Falls back to the default rather than throwing: a theme name can arrive
  /// from another device's settings, and an unknown one should degrade to a
  /// usable app rather than a crash on launch.
  static TiffinThemeId fromWire(String? wire) => values.firstWhere(
        (t) => t.wire == wire,
        orElse: () => defaultTheme,
      );

  /// A fresh install opens on the app's own identity.
  static const defaultTheme = TiffinThemeId.neobrutal;

  TiffinTokens tokens(Brightness brightness) => switch (this) {
        TiffinThemeId.neobrutal => buildNeobrutal(brightness),
        TiffinThemeId.clean => buildClean(brightness),
        TiffinThemeId.frost => buildFrost(brightness),
        TiffinThemeId.clay => buildClay(brightness),
      };
}
