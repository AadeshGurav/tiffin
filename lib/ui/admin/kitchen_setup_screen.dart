import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/tokens.dart';
import 'ingredients_screen.dart';
import 'recipes_screen.dart';

/// Kitchen setup (PRD §6.5.1) — ingredients and recipes were two dashboard
/// tiles for what is really one setup job you do once. Folded into a single
/// screen with two tabs; the purchase schedule (a weekly task) stays its own
/// screen.
class KitchenSetupScreen extends ConsumerStatefulWidget {
  const KitchenSetupScreen({super.key});

  @override
  ConsumerState<KitchenSetupScreen> createState() => _KitchenSetupScreenState();
}

class _KitchenSetupScreenState extends ConsumerState<KitchenSetupScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(_onTab);

  void _onTab() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTab)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final onIngredients = _tabs.index == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen setup'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Ingredients'), Tab(text: 'Recipes')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: t.color.accent,
        foregroundColor: t.color.onAccent,
        icon: const Icon(Icons.add),
        label: Text(onIngredients ? 'New ingredient' : 'New recipe'),
        onPressed: () => onIngredients
            ? openIngredientForm(context, ref, null)
            : openRecipeForm(context, ref, null),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [IngredientsTab(), RecipesTab()],
      ),
    );
  }
}
