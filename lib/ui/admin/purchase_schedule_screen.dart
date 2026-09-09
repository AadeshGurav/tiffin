import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/role.dart';
import '../../domain/inventory.dart';
import '../shared_widgets/ingredient_quick_add.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/nb_surface.dart';
import '../shared_widgets/nb_text_field.dart';
import '../theme/tokens.dart';
import 'ingredients_screen.dart';

final _scheduleProvider =
    FutureProvider.autoDispose<List<PurchaseScheduleItem>>(
        (ref) => ref.watch(backendProvider).listPurchaseSchedule());

/// Purchase schedule (PRD §6.5.1). Admin generates from the menu calendar and
/// deletes; admin + counter check items off and add ad-hoc items.
class PurchaseScheduleScreen extends ConsumerWidget {
  const PurchaseScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final schedule = ref.watch(_scheduleProvider);
    final isAdmin = ref.watch(sessionProvider)?.role == Role.admin;
    final fmt = DateFormat('EEE, MMM d');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase schedule'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Generate from menu',
              onPressed: () => _generate(context, ref),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: t.color.accent,
        foregroundColor: t.color.onAccent,
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
        onPressed: () => _addManual(context, ref),
      ),
      body: AsyncView<List<PurchaseScheduleItem>>(
        value: schedule,
        onRetry: () => ref.invalidate(_scheduleProvider),
        loadingLabel: 'Loading the shopping list…',
        empty: NbEmpty(
          icon: Icons.shopping_cart_outlined,
          title: 'Nothing to buy',
          quips: EmptyQuips.purchase,
          actionLabel: 'Generate from menu',
          onAction: () => _generate(context, ref),
        ),
        builder: (list) {
          final byDay = <String, List<PurchaseScheduleItem>>{};
          for (final it in list) {
            byDay.putIfAbsent(fmt.format(it.date), () => []).add(it);
          }
          return ListView(
            padding: const EdgeInsets.all(NbSpace.md),
            children: [
              for (final day in byDay.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(
                      top: NbSpace.md, bottom: NbSpace.xs),
                  child: Text(day.key.toUpperCase(), style: t.text.label),
                ),
                for (final it in day.value)
                  NbSurface(
                    child: Row(
                      children: [
                        Checkbox(
                          value: it.purchased,
                          onChanged: (v) =>
                              _togglePurchased(context, ref, it, v ?? false),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${it.ingredientName} — ${it.quantityNote} '
                                  '(${it.ingredientUnit})',
                                  style: t.text.body),
                              Text(
                                  it.source == 'manual'
                                      ? 'manual'
                                      : 'from menu'
                                          '${it.purchased ? ' · by ${it.purchasedBy}' : ''}',
                                  style: t.text.label),
                            ],
                          ),
                        ),
                        if (isAdmin)
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final ok = await runGuarded(
                                context,
                                () => ref
                                    .read(backendProvider)
                                    .deletePurchaseItem(it.id),
                                successMessage: 'Removed.',
                              );
                              if (ok) ref.invalidate(_scheduleProvider);
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final t = context.tokens;
    var start = DateTime.now();
    var end = DateTime.now().add(const Duration(days: 7));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Generate schedule', style: t.text.heading),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Builds the shopping list from menu entries in this date '
                'range. One-off items go in with the + button on the list.',
                style: t.text.label,
              ),
              const SizedBox(height: NbSpace.md),
              _dateRow(
                  context, 'From', start, (d) => setLocal(() => start = d)),
              _dateRow(context, 'To', end, (d) => setLocal(() => end = d)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            NbButton(
                label: 'Generate',
                onPressed: () => Navigator.pop(context, true)),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    var created = 0;
    final done = await runGuarded(
      context,
      () async {
        created = await ref
            .read(backendProvider)
            .generatePurchaseSchedule(start, end);
      },
    );
    if (!done || !context.mounted) return;
    ref.invalidate(_scheduleProvider);

    if (created > 0) {
      showNbSnack(context, 'Added $created item(s) to the list.');
      return;
    }
    // A zero result is the confusing case — say *why* nothing was added and
    // what to do about it, rather than a dead "Added 0 items" (CLAUDE.md §8).
    await _explainEmptyGenerate(context, ref, start, end);
  }

  /// Generation walks menu entries in the range, matches each item name to a
  /// recipe by dish name, and lists that recipe's ingredients. A zero result
  /// means one of those links is missing — work out which and say so.
  Future<void> _explainEmptyGenerate(
      BuildContext context, WidgetRef ref, DateTime start, DateTime end) async {
    final t = context.tokens;
    final backend = ref.read(backendProvider);
    final menu = await backend.listMenu(start: start, end: end);
    final recipes = await backend.listRecipes();
    if (!context.mounted) return;

    final String reason;
    if (menu.isEmpty) {
      reason = 'There are no menu entries between those dates. Add meals on '
          'the Menu calendar first, then generate.';
    } else if (recipes.isEmpty) {
      reason = 'The menu has entries, but there are no recipes yet. A recipe '
          'links a dish name to its ingredients — add recipes on the Recipes '
          'screen, matching the item names you typed on the menu.';
    } else {
      reason = 'The menu entries in that range don\'t match any recipe by '
          'dish name, or those recipes have no ingredients. Check that a '
          'recipe\'s dish name matches the menu item text, then try again. '
          'You can also add items directly with the + button.';
    }

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Nothing to add', style: t.text.heading),
        content: Text(reason, style: t.text.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  /// Ticking "purchased" opens a small form for the actual quantity received
  /// (→ stock) and, optionally, what it cost (→ Expenses). Un-ticking just
  /// reverses it.
  Future<void> _togglePurchased(BuildContext context, WidgetRef ref,
      PurchaseScheduleItem it, bool purchased) async {
    if (!purchased) {
      final ok = await runGuarded(
        context,
        () => ref
            .read(backendProvider)
            .updatePurchaseItem(it.id, purchased: false),
      );
      if (ok) ref.invalidate(_scheduleProvider);
      return;
    }

    final t = context.tokens;
    final planned = RegExp(r'[\d.]+').firstMatch(it.quantityNote)?.group(0);
    final qty = TextEditingController(text: planned ?? '');
    final cost = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Bought ${it.ingredientName}', style: t.text.heading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Planned: ${it.quantityNote}. Enter what you actually got.',
                style: t.text.label),
            const SizedBox(height: NbSpace.sm),
            NbTextField(
              label: 'Quantity (${it.ingredientUnit})',
              controller: qty,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: NbSpace.sm),
            NbTextField(
              label: 'Cost (Rs., optional)',
              controller: cost,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          NbButton(
              label: 'Confirm', onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    final ok = await runGuarded(
      context,
      () => ref.read(backendProvider).updatePurchaseItem(
            it.id,
            purchased: true,
            purchasedQty: double.tryParse(qty.text.trim()),
            purchasedCost: double.tryParse(cost.text.trim()),
          ),
      successMessage: 'Marked purchased.',
    );
    if (ok) ref.invalidate(_scheduleProvider);
  }

  Future<void> _addManual(BuildContext context, WidgetRef ref) async {
    final t = context.tokens;
    final ingredients = [...await ref.read(ingredientsProvider.future)];
    if (!context.mounted) return;

    // No ingredients yet used to make this button do nothing at all. Offer to
    // create the first one right here instead of a dead tap.
    if (ingredients.isEmpty) {
      final created = await showQuickAddIngredient(context, ref);
      if (created == null || !context.mounted) return;
      ref.invalidate(ingredientsProvider);
      ingredients.add(created);
    }

    Ingredient selected = ingredients.first;
    var date = DateTime.now();
    final qty = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Add one-off item', style: t.text.heading),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ingredient', style: t.text.label),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<Ingredient>(
                        value: selected,
                        isExpanded: true,
                        items: [
                          for (final ing in ingredients)
                            DropdownMenuItem(value: ing, child: Text(ing.name)),
                        ],
                        onChanged: (v) =>
                            setLocal(() => selected = v ?? selected),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'New ingredient',
                      onPressed: () async {
                        final made =
                            await showQuickAddIngredient(dialogContext, ref);
                        if (made == null) return;
                        ref.invalidate(ingredientsProvider);
                        setLocal(() {
                          ingredients.add(made);
                          selected = made;
                        });
                      },
                    ),
                  ],
                ),
                _dateRow(
                    context, 'Date', date, (d) => setLocal(() => date = d)),
                const SizedBox(height: NbSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: NbTextField(
                        label: 'Quantity',
                        controller: qty,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: NbSpace.sm),
                    Padding(
                      padding: const EdgeInsets.only(top: NbSpace.md),
                      child: Text(selected.unit, style: t.text.label),
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
                label: 'Add', onPressed: () => Navigator.pop(context, true)),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final n = double.tryParse(qty.text.trim());
    final label = n == null || n <= 0
        ? qty.text.trim()
        : '${formatQuantity(n)} ${selected.unit}';
    final saved = await runGuarded(
      context,
      () => ref
          .read(backendProvider)
          .addManualPurchaseItem(date, selected.id, label),
      successMessage: 'Item added.',
    );
    if (saved) ref.invalidate(_scheduleProvider);
  }

  Widget _dateRow(BuildContext context, String label, DateTime value,
      ValueChanged<DateTime> onChanged) {
    final t = context.tokens;
    return Row(
      children: [
        SizedBox(width: 56, child: Text(label, style: t.text.label)),
        Expanded(
            child:
                Text(DateFormat('MMM d, y').format(value), style: t.text.body)),
        TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) onChanged(picked);
          },
          child: const Text('Pick'),
        ),
      ],
    );
  }
}
