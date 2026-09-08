import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/inventory.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/nb_surface.dart';
import '../shared_widgets/nb_text_field.dart';
import '../shared_widgets/unit_field.dart';
import '../theme/tokens.dart';

final ingredientsProvider = FutureProvider.autoDispose<List<Ingredient>>(
    (ref) => ref.watch(backendProvider).listIngredients());

/// The ingredients master list, shown as the first tab of Kitchen setup
/// (PRD §6.5.1). Body only — the hosting Scaffold owns the app bar and FAB.
class IngredientsTab extends ConsumerWidget {
  const IngredientsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final ingredients = ref.watch(ingredientsProvider);
    return AsyncView<List<Ingredient>>(
      value: ingredients,
      onRetry: () => ref.invalidate(ingredientsProvider),
      loadingLabel: 'Loading ingredients…',
      empty: NbEmpty(
        icon: Icons.egg_alt_outlined,
        title: 'No ingredients yet',
        quips: EmptyQuips.ingredients,
        actionLabel: 'Add an ingredient',
        onAction: () => openIngredientForm(context, ref, null),
      ),
      builder: (list) => ListView.separated(
        padding: const EdgeInsets.all(NbSpace.md),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: NbSpace.sm),
        itemBuilder: (_, i) {
          final ing = list[i];
          return NbSurface(
            onTap: () => openIngredientForm(context, ref, ing),
            child: Row(
              children: [
                Expanded(child: Text(ing.name, style: t.text.body)),
                Text(ing.unit, style: t.text.label),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await runGuarded(
                      context,
                      () => ref.read(backendProvider).deleteIngredient(ing.id),
                      successMessage: 'Deleted.',
                    );
                    if (ok) ref.invalidate(ingredientsProvider);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Add or edit an ingredient. Top-level so the Kitchen setup FAB, the tab's
/// rows, and the recipe/purchase quick-add all reach the same form.
Future<void> openIngredientForm(
    BuildContext context, WidgetRef ref, Ingredient? existing) async {
  final t = context.tokens;
  final name = TextEditingController(text: existing?.name ?? '');
  var unit = existing?.unit ?? kCommonUnits.first;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(existing == null ? 'New ingredient' : existing.name,
          style: t.text.heading),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NbTextField(label: 'Name', controller: name, autofocus: true),
          const SizedBox(height: NbSpace.md),
          NbUnitField(
              initial: existing?.unit ?? '', onChanged: (u) => unit = u),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        NbButton(label: 'Save', onPressed: () => Navigator.pop(context, true)),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final saved = await runGuarded(context, () async {
    final backend = ref.read(backendProvider);
    if (existing == null) {
      await backend.createIngredient(name.text.trim(), unit.trim());
    } else {
      await backend.updateIngredient(existing.id,
          name: name.text.trim(), unit: unit.trim());
    }
  }, successMessage: 'Saved.');
  if (saved) ref.invalidate(ingredientsProvider);
}
