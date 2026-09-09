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

String _num(double x) =>
    x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toString();

/// The ingredients master list — also the inventory: each row shows on-hand
/// stock and flags LOW when it's at or below its alert threshold (PRD §6.5.1).
/// Body only — the hosting Scaffold owns the app bar and FAB.
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ing.name, style: t.text.body),
                      Text('${_num(ing.stockQty)} ${ing.unit} in stock',
                          style: t.text.label),
                    ],
                  ),
                ),
                if (ing.isLow)
                  Padding(
                    padding: const EdgeInsets.only(right: NbSpace.sm),
                    child: Text('LOW',
                        style: t.text.label.copyWith(color: t.color.reject)),
                  ),
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Adjust stock',
                  onPressed: () => _adjustStock(context, ref, ing),
                ),
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

  Future<void> _adjustStock(
      BuildContext context, WidgetRef ref, Ingredient ing) async {
    final t = context.tokens;
    final delta = TextEditingController();
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Adjust ${ing.name} stock', style: t.text.heading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Now: ${_num(ing.stockQty)} ${ing.unit}. Enter a change '
                '(e.g. 5 for a delivery, -2 for spoilage).',
                style: t.text.label),
            const SizedBox(height: NbSpace.sm),
            NbTextField(
              label: 'Change (${ing.unit})',
              controller: delta,
              keyboardType: const TextInputType.numberWithOptions(
                  signed: true, decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: NbSpace.sm),
            NbTextField(label: 'Reason', controller: reason),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          NbButton(
              label: 'Apply', onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final d = double.tryParse(delta.text.trim());
    if (d == null || d == 0) return;
    final done = await runGuarded(
      context,
      () => ref
          .read(backendProvider)
          .adjustIngredientStock(ing.id, d, reason.text.trim()),
      successMessage: 'Stock updated.',
    );
    if (done) ref.invalidate(ingredientsProvider);
  }
}

/// Add or edit an ingredient. Top-level so the Kitchen setup FAB, the tab's
/// rows, and the recipe/purchase quick-add all reach the same form.
Future<void> openIngredientForm(
    BuildContext context, WidgetRef ref, Ingredient? existing) async {
  final t = context.tokens;
  final name = TextEditingController(text: existing?.name ?? '');
  var unit = existing?.unit ?? kCommonUnits.first;
  final stock = TextEditingController(
      text: existing == null ? '' : _num(existing.stockQty));
  final threshold = TextEditingController(
      text: existing?.lowStockAt == null ? '' : _num(existing!.lowStockAt!));
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(existing == null ? 'New ingredient' : existing.name,
          style: t.text.heading),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NbTextField(label: 'Name', controller: name, autofocus: true),
            const SizedBox(height: NbSpace.md),
            NbUnitField(
                initial: existing?.unit ?? '', onChanged: (u) => unit = u),
            const SizedBox(height: NbSpace.md),
            NbTextField(
              label: 'Stock on hand',
              controller: stock,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: NbSpace.sm),
            NbTextField(
              label: 'Low-stock alert at (blank = no alert)',
              controller: threshold,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
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
  final stockQty = double.tryParse(stock.text.trim());
  final lowAt = double.tryParse(threshold.text.trim());
  final saved = await runGuarded(context, () async {
    final backend = ref.read(backendProvider);
    if (existing == null) {
      await backend.createIngredient(name.text.trim(), unit.trim(),
          stockQty: stockQty ?? 0, lowStockAt: lowAt);
    } else {
      await backend.updateIngredient(existing.id,
          name: name.text.trim(),
          unit: unit.trim(),
          stockQty: stockQty,
          lowStockAt: lowAt);
    }
  }, successMessage: 'Saved.');
  if (saved) ref.invalidate(ingredientsProvider);
}
