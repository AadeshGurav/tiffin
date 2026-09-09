import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/inventory.dart';
import '../shared_widgets/ingredient_quick_add.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/nb_surface.dart';
import '../shared_widgets/nb_text_field.dart';
import '../theme/tokens.dart';
import 'ingredients_screen.dart';

final _recipesProvider = FutureProvider.autoDispose<List<Recipe>>(
    (ref) => ref.watch(backendProvider).listRecipes());

/// Recipes, shown as the second tab of Kitchen setup (PRD §6.5.1): a dish name
/// (matched case-insensitively against menu items) linked to the ingredients
/// it needs, each with a quantity in that ingredient's unit. Body only.
class RecipesTab extends ConsumerWidget {
  const RecipesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final recipes = ref.watch(_recipesProvider);
    return AsyncView<List<Recipe>>(
      value: recipes,
      onRetry: () => ref.invalidate(_recipesProvider),
      loadingLabel: 'Loading recipes…',
      empty: NbEmpty(
        icon: Icons.menu_book_outlined,
        title: 'No recipes yet',
        quips: EmptyQuips.recipes,
        actionLabel: 'Add a recipe',
        onAction: () => openRecipeForm(context, ref, null),
      ),
      builder: (list) => ListView.separated(
        padding: const EdgeInsets.all(NbSpace.md),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: NbSpace.sm),
        itemBuilder: (_, i) {
          final r = list[i];
          return NbSurface(
            onTap: () => openRecipeForm(context, ref, r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.dishName, style: t.text.body),
                Text('${r.ingredients.length} ingredient(s)',
                    style: t.text.label),
              ],
            ),
          );
        },
      ),
    );
  }
}

typedef _Line = ({int ingredientId, TextEditingController qty});

/// Add or edit a recipe. Top-level so the Kitchen setup FAB and the tab's rows
/// share it.
Future<void> openRecipeForm(
    BuildContext context, WidgetRef ref, Recipe? existing) async {
  final t = context.tokens;
  final allIngredients = [...await ref.read(ingredientsProvider.future)];
  if (!context.mounted) return;
  final dish = TextEditingController(text: existing?.dishName ?? '');
  final lines = <_Line>[
    for (final ri in existing?.ingredients ?? const <RecipeIngredient>[])
      (
        ingredientId: ri.ingredientId,
        qty: TextEditingController(text: formatQuantity(ri.quantity)),
      ),
  ];
  if (lines.isEmpty && allIngredients.isNotEmpty) {
    lines.add((
      ingredientId: allIngredients.first.id,
      qty: TextEditingController(),
    ));
  }

  String unitFor(int ingredientId) => allIngredients
      .firstWhere((x) => x.id == ingredientId,
          orElse: () => allIngredients.first)
      .unit;

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setLocal) {
        Future<void> addNewIngredient() async {
          final made = await showQuickAddIngredient(context, ref);
          if (made == null || !context.mounted) return;
          ref.invalidate(ingredientsProvider);
          setLocal(() {
            allIngredients.add(made);
            lines.add((
              ingredientId: made.id,
              qty: TextEditingController(),
            ));
          });
        }

        return AlertDialog(
          title: Text(existing == null ? 'New recipe' : existing.dishName,
              style: t.text.heading),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NbTextField(label: 'Dish name', controller: dish),
                const SizedBox(height: NbSpace.xs),
                Text('Quantities are for ONE plate / one serving.',
                    style: t.text.label),
                const SizedBox(height: NbSpace.md),
                for (var i = 0; i < lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: NbSpace.sm),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButton<int>(
                            value: lines[i].ingredientId,
                            isExpanded: true,
                            items: [
                              for (final ing in allIngredients)
                                DropdownMenuItem(
                                    value: ing.id, child: Text(ing.name)),
                            ],
                            onChanged: (v) => setLocal(() => lines[i] = (
                                  ingredientId: v ?? lines[i].ingredientId,
                                  qty: lines[i].qty
                                )),
                          ),
                        ),
                        const SizedBox(width: NbSpace.sm),
                        Expanded(
                          flex: 2,
                          child: NbTextField(
                            label: 'per plate',
                            controller: lines[i].qty,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            formatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]')),
                            ],
                          ),
                        ),
                        const SizedBox(width: NbSpace.xs),
                        Text(unitFor(lines[i].ingredientId),
                            style: t.text.label),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Remove',
                          onPressed: lines.length == 1
                              ? null
                              : () => setLocal(() => lines.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                Wrap(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add row'),
                      onPressed: allIngredients.isEmpty
                          ? addNewIngredient
                          : () => setLocal(() => lines.add((
                                ingredientId: allIngredients.first.id,
                                qty: TextEditingController()
                              ))),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('New ingredient'),
                      onPressed: addNewIngredient,
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            NbButton(
                label: 'Save', onPressed: () => Navigator.pop(context, true)),
          ],
        );
      },
    ),
  );
  if (ok != true || !context.mounted) return;
  final ingredients = [
    for (final l in lines)
      if ((double.tryParse(l.qty.text.trim()) ?? 0) > 0)
        RecipeIngredient(
          ingredientId: l.ingredientId,
          quantity: double.parse(l.qty.text.trim()),
        ),
  ];
  final saved = await runGuarded(context, () async {
    final backend = ref.read(backendProvider);
    if (existing == null) {
      await backend.createRecipe(
          RecipeDraft(dishName: dish.text.trim(), ingredients: ingredients));
    } else {
      await backend.updateRecipe(existing.id,
          dishName: dish.text.trim(), ingredients: ingredients);
    }
  }, successMessage: 'Saved.');
  if (saved) ref.invalidate(_recipesProvider);
}
