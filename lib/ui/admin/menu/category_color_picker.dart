import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/labels.dart';
import '../../theme/category_palette.dart';
import '../../theme/tokens.dart';

/// Swatches for [CategoryColor], plus "no colour". Each swatch is a 48px
/// target (§11.6.5) with a spoken name, and the chosen colour's name is
/// written underneath so the choice never rests on colour alone (§12.2).
class CategoryColorPicker extends StatelessWidget {
  const CategoryColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final CategoryColor? selected;
  final ValueChanged<CategoryColor?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = AppText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text.categoryColorLabel, style: t.text.label),
        const SizedBox(height: NbSpace.xs),
        Wrap(
          spacing: NbSpace.sm,
          runSpacing: NbSpace.sm,
          children: [
            _Swatch(
              name: text.categoryColorNone,
              fill: null,
              chosen: selected == null,
              onTap: () => onChanged(null),
            ),
            for (final c in CategoryColor.values)
              _Swatch(
                name: text.categoryColorName(c),
                fill: c.color,
                chosen: selected == c,
                onTap: () => onChanged(c),
              ),
          ],
        ),
        const SizedBox(height: NbSpace.xs),
        Text(
          selected == null
              ? text.categoryColorNone
              : text.categoryColorSelected(text.categoryColorName(selected!)),
          style: t.text.label,
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.name,
    required this.fill,
    required this.chosen,
    required this.onTap,
  });

  final String name;
  final Color? fill;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: chosen,
      label: name,
      child: Tooltip(
        message: name,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              // A thick ring marks the chosen swatch: shape, not just colour.
              border: Border.all(
                color: t.color.ink,
                width: chosen ? t.shape.borderBold : t.shape.borderHair,
              ),
            ),
            child: Icon(
              chosen ? Icons.check : (fill == null ? Icons.block : null),
              size: 22,
              color: fill == null ? t.color.ink : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
