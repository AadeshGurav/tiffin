import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/menu.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/nb_surface.dart';
import '../shared_widgets/nb_text_field.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';

final _categoriesProvider = FutureProvider.autoDispose<List<MenuCategory>>(
    (ref) => ref.watch(backendProvider).listMenuCategories());

/// Editable menu category list (PRD §6.5) — not a fixed enum.
class MenuCategoriesScreen extends ConsumerWidget {
  const MenuCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final categories = ref.watch(_categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(AppText.of(context).menuCategoriesScreenTitle)),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: t.color.accent,
        foregroundColor: t.color.onAccent,
        icon: const Icon(Icons.add),
        label: Text(AppText.of(context).menuCategoriesScreenNew),
        onPressed: () => _form(context, ref, null),
      ),
      body: AsyncView<List<MenuCategory>>(
        value: categories,
        onRetry: () => ref.invalidate(_categoriesProvider),
        loadingLabel: AppText.of(context).menuCategoriesScreenLoading,
        empty: NbEmpty(
          icon: Icons.category_outlined,
          title: AppText.of(context).menuCategoriesScreenEmptyTitle,
          quips: EmptyQuips.categories(context),
          actionLabel: AppText.of(context).menuCategoriesScreenEmptyAction,
          onAction: () => _form(context, ref, null),
        ),
        builder: (list) => ListView.separated(
          padding: const EdgeInsets.all(NbSpace.md),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: NbSpace.sm),
          itemBuilder: (_, i) {
            final c = list[i];
            return NbSurface(
              onTap: () => _form(context, ref, c),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: t.text.body),
                        if (c.description != null)
                          Text(c.description!, style: t.text.label),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await runGuarded(
                        context,
                        () =>
                            ref.read(backendProvider).deleteMenuCategory(c.id),
                        successMessage:
                            AppText.of(context).menuCategoriesScreenDeleteSuccess,
                      );
                      if (ok) ref.invalidate(_categoriesProvider);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _form(
      BuildContext context, WidgetRef ref, MenuCategory? existing) async {
    final t = context.tokens;
    final name = TextEditingController(text: existing?.name ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            existing == null
                ? AppText.of(context).menuCategoriesScreenNewCategoryTitle
                : existing.name,
            style: t.text.heading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NbTextField(
                label: AppText.of(context).menuCategoriesScreenNameLabel,
                controller: name),
            const SizedBox(height: NbSpace.sm),
            NbTextField(
                label:
                    AppText.of(context).menuCategoriesScreenDescriptionLabel,
                controller: desc),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppText.of(context).menuCategoriesScreenCancel)),
          NbButton(
              label: AppText.of(context).menuCategoriesScreenSave,
              onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final saved = await runGuarded(context, () async {
      final backend = ref.read(backendProvider);
      final d = desc.text.trim().isEmpty ? null : desc.text.trim();
      if (existing == null) {
        await backend.createMenuCategory(name.text.trim(), d);
      } else {
        await backend.updateMenuCategory(existing.id,
            name: name.text.trim(), description: d);
      }
    }, successMessage: AppText.of(context).menuCategoriesScreenSaveSuccess);
    if (saved) ref.invalidate(_categoriesProvider);
  }
}
