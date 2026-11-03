import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One bordered container holding a run of related rows, split by hairlines.
///
/// A dozen separately boxed rows read as a dozen objects; one box with
/// dividers reads as one list (Gestalt common region, CLAUDE.md §11.3), and
/// leaves the heavy border for the things that are actually buttons.
class NbGroup extends StatelessWidget {
  const NbGroup({super.key, this.title, required this.children});

  /// Plain sentence-case heading above the box. Null for an untitled list.
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rows = <Widget>[
      for (final (i, row) in children.indexed) ...[
        if (i > 0) Divider(height: t.shape.borderHair, color: t.color.border),
        row,
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(
                top: NbSpace.lg, bottom: NbSpace.sm, left: NbSpace.xs),
            child: Semantics(
              header: true,
              child: Text(title!,
                  style: t.text.label.copyWith(color: t.color.inkMuted)),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: t.color.surface,
            borderRadius: t.shape.radius,
            border:
                Border.all(color: t.color.border, width: t.shape.borderBase),
          ),
          child: ClipRRect(
            borderRadius: t.shape.radius,
            child: Column(children: rows),
          ),
        ),
      ],
    );
  }
}

/// A tappable row inside an [NbGroup]: a toned icon, a title, an optional
/// one-line description, and a chevron. At least 56px tall, the full width is
/// the tap target (CLAUDE.md §11.6.5).
class NbListRow extends StatelessWidget {
  const NbListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tone = NbTone.neutral,
    this.trailing,
    this.danger = false,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final NbTone tone;

  /// Replaces the chevron, e.g. with a "Change" label or a close button.
  final Widget? trailing;

  /// Paints the row in the reject colour — for the one destructive entry.
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = danger ? t.color.reject : t.color.ink;
    final chip = t.color.tone(tone);
    return InkWell(
      onTap: onTap,
      highlightColor: t.color.surfaceMuted,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: NbSpace.md, vertical: NbSpace.sm),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: chip,
                  borderRadius: t.shape.radius,
                ),
                child: Icon(icon, size: 20, color: t.color.on(chip)),
              ),
              const SizedBox(width: NbSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.text.label.copyWith(color: fg)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: t.text.body
                              .copyWith(color: t.color.inkMuted, fontSize: 14)),
                    ],
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_right, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
