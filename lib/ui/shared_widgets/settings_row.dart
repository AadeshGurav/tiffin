import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'nb_surface.dart';

/// One tappable row in a settings-style menu: an icon, a title, a one-line
/// description, and a chevron. Keeps the hub scannable instead of stacking a
/// dozen forms on one scroll.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Paints the row in the reject colour — for the one destructive entry.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = danger ? t.color.reject : t.color.ink;
    return NbSurface(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: NbSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(),
                    style: t.text.label.copyWith(color: fg)),
                const SizedBox(height: 2),
                Text(subtitle, style: t.text.body),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: fg),
        ],
      ),
    );
  }
}
