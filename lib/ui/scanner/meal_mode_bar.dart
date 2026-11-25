import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/canteen_book.dart';
import '../../app/providers.dart';
import '../../domain/settings.dart';
import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// Which meal this phone serves: null = by the clock (the built-in meals),
/// else an anytime meal's id (ADR 0009 §5). Remembered per phone and per
/// canteen, so the tea-counter phone stays on Tea all afternoon.
class ScannerMode extends Notifier<String?> {
  String get _key => 'scanner_mode_${ref.watch(activeCanteenProvider)}';

  @override
  String? build() => ref.read(sharedPreferencesProvider).getString(_key);

  Future<void> set(String? mealId) async {
    state = mealId;
    final prefs = ref.read(sharedPreferencesProvider);
    mealId == null
        ? await prefs.remove(_key)
        : await prefs.setString(_key, mealId);
  }
}

final scannerModeProvider =
    NotifierProvider<ScannerMode, String?>(ScannerMode.new);

/// The saved [mode] if it is still an active meal, else null (by time): a
/// retired meal must never keep charging.
String? liveMode(String? mode, List<AnytimeMeal> catalogue) =>
    catalogue.any((m) => m.id == mode && m.active) ? mode : null;

/// The bottom bar (thumb zone, §11.6.5): "By time" then each active anytime
/// meal, grouped. Shown only when the canteen has an anytime meal, so
/// canteens that don't use them see no change.
class MealModeBar extends StatelessWidget {
  const MealModeBar({
    super.key,
    required this.catalogue,
    required this.selected,
    required this.onSelect,
  });

  final List<AnytimeMeal> catalogue;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final meals = groupMeals(catalogue.where((m) => m.active));
    if (meals.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    final text = AppText.of(context);

    Widget chip(String label, String? id) => Padding(
          padding: const EdgeInsets.only(right: NbSpace.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            // ChoiceChip carries "selected" to screen readers and shows a
            // check mark, so the choice is never colour alone.
            child: ChoiceChip(
              label: Text(label),
              selected: selected == id,
              onSelected: (_) => onSelect(id),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
        );

    final children = <Widget>[chip(text.scannerModeByTime, null)];
    String? group;
    for (final m in meals) {
      if (m.group != null && m.group!.toLowerCase() != group?.toLowerCase()) {
        group = m.group;
        children.add(Padding(
          padding: const EdgeInsets.only(right: NbSpace.xs),
          child: Text(group!, style: t.text.label.copyWith(color: t.color.ink)),
        ));
      }
      children.add(chip(m.name, m.id));
    }

    return Semantics(
      container: true,
      label: text.scannerModeBarLabel,
      child: Material(
        color: t.color.surface,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: NbSpace.md, vertical: NbSpace.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
