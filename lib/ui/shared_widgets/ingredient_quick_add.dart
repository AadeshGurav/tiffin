import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/inventory.dart';
import '../theme/tokens.dart';
import 'nb_button.dart';
import 'nb_feedback.dart';
import 'nb_text_field.dart';

/// A slim name + unit form that creates an [Ingredient] and returns it, so a
/// screen that needs one (recipes, the purchase schedule) stays usable before
/// the Ingredients screen has ever been opened. Returns null if cancelled or
/// the create failed. The caller is responsible for refreshing its own
/// ingredient list.
Future<Ingredient?> showQuickAddIngredient(
    BuildContext context, WidgetRef ref) async {
  final t = context.tokens;
  final name = TextEditingController();
  final unit = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('New ingredient', style: t.text.heading),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NbTextField(label: 'Name', controller: name, autofocus: true),
          const SizedBox(height: NbSpace.sm),
          NbTextField(label: 'Unit (kg, litre, pcs…)', controller: unit),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        NbButton(
            label: 'Create', onPressed: () => Navigator.pop(context, true)),
      ],
    ),
  );
  if (ok != true || !context.mounted) return null;
  Ingredient? made;
  final done = await runGuarded(
    context,
    () async {
      made = await ref
          .read(backendProvider)
          .createIngredient(name.text.trim(), unit.text.trim());
    },
    successMessage: 'Ingredient added.',
  );
  return done ? made : null;
}
