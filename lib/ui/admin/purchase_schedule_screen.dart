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
import '../../l10n/app_localizations.dart';

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
        title: Text(AppText.of(context).purchaseScheduleScreenTitle),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip:
                  AppText.of(context).purchaseScheduleScreenGenerateFromMenu,
              onPressed: () => _generate(context, ref),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: t.color.accent,
        foregroundColor: t.color.onAccent,
        icon: const Icon(Icons.add),
        label: Text(AppText.of(context).purchaseScheduleScreenAddItem),
        onPressed: () => _addManual(context, ref),
      ),
      body: AsyncView<List<PurchaseScheduleItem>>(
        value: schedule,
        onRetry: () => ref.invalidate(_scheduleProvider),
        loadingLabel: AppText.of(context).purchaseScheduleScreenLoading,
        empty: NbEmpty(
          icon: Icons.shopping_cart_outlined,
          title: AppText.of(context).purchaseScheduleScreenEmptyTitle,
          quips: EmptyQuips.purchase(context),
          actionLabel:
              AppText.of(context).purchaseScheduleScreenGenerateFromMenu,
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
                                      ? AppText.of(context)
                                          .purchaseScheduleScreenSourceManual
                                      : (it.purchased
                                          ? AppText.of(context)
                                              .purchaseScheduleScreenSourceFromMenuBy(
                                                  it.purchasedBy ?? '')
                                          : AppText.of(context)
                                              .purchaseScheduleScreenSourceFromMenu),
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
                                successMessage: AppText.of(context)
                                    .purchaseScheduleScreenRemoved,
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
          title: Text(AppText.of(context).purchaseScheduleScreenGenerateTitle,
              style: t.text.heading),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppText.of(context).purchaseScheduleScreenGenerateDescription,
                style: t.text.label,
              ),
              const SizedBox(height: NbSpace.md),
              _dateRow(
                  context,
                  AppText.of(context).purchaseScheduleScreenFromLabel,
                  start,
                  (d) => setLocal(() => start = d)),
              _dateRow(
                  context,
                  AppText.of(context).purchaseScheduleScreenToLabel,
                  end,
                  (d) => setLocal(() => end = d)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppText.of(context).purchaseScheduleScreenCancel)),
            NbButton(
                label: AppText.of(context).purchaseScheduleScreenGenerateButton,
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
      showNbSnack(context,
          AppText.of(context).purchaseScheduleScreenAddedItems(created));
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
      reason = AppText.of(context).purchaseScheduleScreenReasonNoMenuEntries;
    } else if (recipes.isEmpty) {
      reason = AppText.of(context).purchaseScheduleScreenReasonNoRecipes;
    } else {
      reason = AppText.of(context).purchaseScheduleScreenReasonNoMatch;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppText.of(context).purchaseScheduleScreenNothingToAddTitle,
            style: t.text.heading),
        content: Text(reason, style: t.text.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppText.of(context).purchaseScheduleScreenOk)),
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
        title: Text(
            AppText.of(context)
                .purchaseScheduleScreenBoughtTitle(it.ingredientName),
            style: t.text.heading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                AppText.of(context)
                    .purchaseScheduleScreenPlannedLabel(it.quantityNote),
                style: t.text.label),
            const SizedBox(height: NbSpace.sm),
            NbTextField(
              label: AppText.of(context)
                  .purchaseScheduleScreenQuantityLabel(it.ingredientUnit),
              controller: qty,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: NbSpace.sm),
            NbTextField(
              label: AppText.of(context).purchaseScheduleScreenCostLabel,
              controller: cost,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppText.of(context).purchaseScheduleScreenCancel)),
          NbButton(
              label: AppText.of(context).purchaseScheduleScreenConfirm,
              onPressed: () => Navigator.pop(context, true)),
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
      successMessage: AppText.of(context).purchaseScheduleScreenMarkedPurchased,
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
          title: Text(AppText.of(context).purchaseScheduleScreenAddOneOffTitle,
              style: t.text.heading),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppText.of(context).purchaseScheduleScreenIngredientLabel,
                    style: t.text.label),
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
                      tooltip: AppText.of(context)
                          .purchaseScheduleScreenNewIngredientTooltip,
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
                    context,
                    AppText.of(context).purchaseScheduleScreenDateLabel,
                    date,
                    (d) => setLocal(() => date = d)),
                const SizedBox(height: NbSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: NbTextField(
                        label: AppText.of(context)
                            .purchaseScheduleScreenQuantityOnlyLabel,
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
                child: Text(AppText.of(context).purchaseScheduleScreenCancel)),
            NbButton(
                label: AppText.of(context).purchaseScheduleScreenAddButton,
                onPressed: () => Navigator.pop(context, true)),
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
      successMessage: AppText.of(context).purchaseScheduleScreenItemAdded,
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
          child: Text(AppText.of(context).purchaseScheduleScreenPickButton),
        ),
      ],
    );
  }
}
