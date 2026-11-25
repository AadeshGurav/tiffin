import 'package:flutter/material.dart';

import '../../../core/error_report.dart';
import '../../../core/number_input.dart';
import '../../../domain/settings.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/labels.dart';
import '../../../l10n/messages.dart';
import '../../../services/system/settings_service.dart';
import '../../shared_widgets/nb_button.dart';
import '../../shared_widgets/nb_feedback.dart';
import '../../shared_widgets/nb_group.dart';
import '../../shared_widgets/nb_text_field.dart';
import '../../theme/tokens.dart';

/// Settings ▸ anytime meals (ADR 0009 §2): Tea, Juice — no window, no daily
/// limit. Each edit saves the whole catalogue through [onSave] at once, so a
/// mistake shows inside the dialog with the typing kept. There is no delete:
/// members may hold paid units, so a meal is retired instead.
class AnytimeMealsSection extends StatelessWidget {
  const AnytimeMealsSection(
      {super.key, required this.meals, required this.onSave});

  final List<AnytimeMeal> meals;
  final Future<void> Function(List<AnytimeMeal> next) onSave;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = AppText.of(context);
    final rows = <Widget>[];
    String? group;
    for (final m in groupMeals(meals)) {
      if (m.group != null && m.group!.toLowerCase() != group?.toLowerCase()) {
        group = m.group;
        rows.add(Padding(
          padding: const EdgeInsets.only(top: NbSpace.sm, bottom: NbSpace.xs),
          child: Text(group!, style: t.text.label),
        ));
      }
      rows.add(NbListRow(
        icon: m.active ? Icons.local_cafe : Icons.archive_outlined,
        title: m.name,
        // Retired is said in words, not only by the greyed icon.
        subtitle: m.active
            ? text.money(m.price)
            : text.anytimeMealsRetiredSubtitle(text.money(m.price)),
        onTap: () => _edit(context, m),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text.anytimeMealsIntro,
            style: t.text.body.copyWith(color: t.color.inkMuted)),
        const SizedBox(height: NbSpace.sm),
        ...rows,
        const SizedBox(height: NbSpace.sm),
        NbButton.secondary(
          label: text.anytimeMealsAddButton,
          icon: Icons.add,
          onPressed: () => _edit(context, null),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, AnytimeMeal? meal) =>
      showDialog<void>(
        context: context,
        builder: (_) => _MealDialog(
          meal: meal,
          groups: {
            for (final m in meals)
              if (m.group != null) m.group!.toLowerCase(): m.group!,
          }.values.toList(),
          onSave: (edited) => onSave([
            for (final m in meals) m.id == edited.id ? edited : m,
            if (meal == null) edited,
          ]),
        ),
      );
}

class _MealDialog extends StatefulWidget {
  const _MealDialog(
      {required this.meal, required this.groups, required this.onSave});

  final AnytimeMeal? meal;
  final List<String> groups;
  final Future<void> Function(AnytimeMeal) onSave;

  @override
  State<_MealDialog> createState() => _MealDialogState();
}

class _MealDialogState extends State<_MealDialog> {
  late final _name = TextEditingController(text: widget.meal?.name);
  late final _price = TextEditingController(
      text: widget.meal == null ? '' : _plain(widget.meal!.price));
  late final _group = TextEditingController(text: widget.meal?.group);
  late bool _active = widget.meal?.active ?? true;
  ErrorNotice? _error;
  bool _busy = false;

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(AnytimeMeal(
        id: widget.meal?.id ?? SettingsService.newAnytimeMealId(),
        name: _name.text,
        price: parseAmount(_price.text),
        active: _active,
        group: _group.text,
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      if (mounted) {
        setState(() => _error = AppText.of(context).describeError(e, st));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = AppText.of(context);
    final suggestions = widget.groups;
    return AlertDialog(
      title: Text(
          widget.meal == null
              ? text.anytimeMealsAddButton
              : text.anytimeMealsEditTitle(widget.meal!.name),
          style: t.text.heading),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NbTextField(
                label: text.anytimeMealsNameLabel,
                controller: _name,
                autofocus: widget.meal == null),
            const SizedBox(height: NbSpace.sm),
            NbTextField(
                label: text.anytimeMealsPriceLabel,
                controller: _price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: NbSpace.sm),
            NbTextField(
                label: text.anytimeMealsGroupLabel,
                hint: text.anytimeMealsGroupHint,
                controller: _group),
            // The groups already in use, one tap away, so "Drink" and
            // "Drinks" don't both end up in the catalogue.
            if (suggestions.isNotEmpty)
              Wrap(
                spacing: NbSpace.sm,
                children: [
                  for (final g in suggestions)
                    ActionChip(
                      label: Text(g),
                      onPressed: () => setState(() => _group.text = g),
                    ),
                ],
              ),
            if (widget.meal != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(text.anytimeMealsActiveLabel, style: t.text.body),
                subtitle: Text(text.anytimeMealsRetireHelp,
                    style: t.text.body
                        .copyWith(color: t.color.inkMuted, fontSize: 14)),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: NbSpace.sm),
                child: ErrorNoticeView(_error!, color: t.color.reject),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(text.anytimeMealsCancelButton),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(text.anytimeMealsSaveButton),
        ),
      ],
    );
  }
}
