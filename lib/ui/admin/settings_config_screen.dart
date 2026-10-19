import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/backend.dart';
import '../../domain/settings.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/nb_picker.dart';
import '../theme/tokens.dart';
import '../shared_widgets/nb_text_field.dart';
import '../../l10n/app_localizations.dart';

final _settingsProvider = FutureProvider.autoDispose<SettingsSnapshot>(
    (ref) => ref.watch(backendProvider).getSettings());
final _timezonesProvider = FutureProvider.autoDispose<List<String>>(
    (ref) => ref.watch(backendProvider).timezones());

/// The runtime-config form (PRD §6.8) — branding, prices, meal windows,
/// timezone, grace, reminders, UPI. All DB-backed, no restart. Split off its
/// own screen so the Settings hub stays a short menu rather than one long
/// scroll.
class SettingsConfigScreen extends ConsumerWidget {
  const SettingsConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(_settingsProvider);
    return Scaffold(
      appBar:
          AppBar(title: Text(AppText.of(context).settingsConfigScreenTitle)),
      body: AsyncView<SettingsSnapshot>(
        value: settings,
        onRetry: () => ref.invalidate(_settingsProvider),
        builder: (s) => _ConfigForm(initial: s),
      ),
    );
  }
}

class _ConfigForm extends ConsumerStatefulWidget {
  const _ConfigForm({required this.initial});
  final SettingsSnapshot initial;

  @override
  ConsumerState<_ConfigForm> createState() => _ConfigFormState();
}

class _ConfigFormState extends ConsumerState<_ConfigForm> {
  late final _appName = TextEditingController(text: widget.initial.appName);
  late final _lunchPrice = _num(widget.initial.unitPrices.lunch);
  late final _breakfastPrice = _num(widget.initial.unitPrices.breakfast);
  late final _brunchPrice = _num(widget.initial.unitPrices.brunch);
  late final _upiId = TextEditingController(text: widget.initial.upiId);
  late final _upiPayee =
      TextEditingController(text: widget.initial.upiPayeeName);
  late final _graceUnits = _num(widget.initial.graceAllowanceUnits.toDouble());
  late bool _graceEnabled = widget.initial.graceAllowanceEnabled;
  late final _reversal = _num(widget.initial.reversalWindowMinutes.toDouble());
  late final _prepLead = _num(widget.initial.prepLeadMinutes.toDouble());
  late final _purchaseLead = _num(widget.initial.purchaseLeadDays.toDouble());
  late String _timezone = widget.initial.localTimezone;

  late final Map<String, (TextEditingController, TextEditingController)>
      _windows = {
    for (final m in const ['breakfast', 'lunch', 'brunch'])
      m: (
        TextEditingController(text: widget.initial.mealWindows[m]!.start),
        TextEditingController(text: widget.initial.mealWindows[m]!.end),
      ),
  };

  bool _busy = false;

  TextEditingController _num(double v) => TextEditingController(
      text: v == v.roundToDouble() ? v.toInt().toString() : v.toString());

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await runGuarded(context, () async {
      await ref.read(backendProvider).updateSettings(SettingsPatch(
            appName: _appName.text.trim(),
            unitPrices: UnitPrices(
              lunch: double.tryParse(_lunchPrice.text) ?? 0,
              breakfast: double.tryParse(_breakfastPrice.text) ?? 0,
              brunch: double.tryParse(_brunchPrice.text) ?? 0,
            ),
            upiId: _upiId.text.trim(),
            upiPayeeName: _upiPayee.text.trim(),
            graceAllowanceEnabled: _graceEnabled,
            graceAllowanceUnits: int.tryParse(_graceUnits.text) ?? 0,
            reversalWindowMinutes: int.tryParse(_reversal.text) ?? 10,
            prepLeadMinutes: int.tryParse(_prepLead.text) ?? 60,
            purchaseLeadDays: int.tryParse(_purchaseLead.text) ?? 1,
            localTimezone: _timezone,
            mealWindows: {
              for (final e in _windows.entries)
                e.key: MealWindowConfig(
                    start: e.value.$1.text.trim(), end: e.value.$2.text.trim()),
            },
          ));
    }, successMessage: AppText.of(context).settingsConfigScreenSavedMessage);
    if (mounted) setState(() => _busy = false);
    if (ok) ref.invalidate(_settingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final zones = ref.watch(_timezonesProvider).asData?.value ?? [_timezone];
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(NbSpace.lg),
        children: [
          _section(t, AppText.of(context).settingsConfigScreenSectionBranding),
          NbTextField(
              label: AppText.of(context).settingsConfigScreenAppNameLabel,
              controller: _appName),
          _section(t, AppText.of(context).settingsConfigScreenSectionPrices),
          NbTextField(
              label: AppText.of(context).settingsConfigScreenLunchLabel,
              controller: _lunchPrice,
              keyboardType: TextInputType.number),
          const SizedBox(height: NbSpace.sm),
          NbTextField(
              label: AppText.of(context).settingsConfigScreenBreakfastLabel,
              controller: _breakfastPrice,
              keyboardType: TextInputType.number),
          const SizedBox(height: NbSpace.sm),
          NbTextField(
              label: AppText.of(context).settingsConfigScreenBrunchLabel,
              controller: _brunchPrice,
              keyboardType: TextInputType.number),
          _section(
              t, AppText.of(context).settingsConfigScreenSectionMealWindows),
          // Meal key `m` doubles as the map key into `_windows` — it can't be
          // localized without decoupling display text from data lookup, so
          // it's left as-is (skipped per the retrofit conventions).
          for (final m in const ['breakfast', 'lunch', 'brunch'])
            Padding(
              padding: const EdgeInsets.only(bottom: NbSpace.sm),
              child: Row(
                children: [
                  SizedBox(width: 90, child: Text(m, style: t.text.label)),
                  Expanded(
                      child: NbTextField(
                          label: AppText.of(context)
                              .settingsConfigScreenStartLabel,
                          controller: _windows[m]!.$1)),
                  const SizedBox(width: NbSpace.sm),
                  Expanded(
                      child: NbTextField(
                          label:
                              AppText.of(context).settingsConfigScreenEndLabel,
                          controller: _windows[m]!.$2)),
                ],
              ),
            ),
          _section(t, AppText.of(context).settingsConfigScreenSectionTimezone),
          NbPickerField(
            label: AppText.of(context).settingsConfigScreenTimezoneFieldLabel,
            value: zones.contains(_timezone) ? _timezone : zones.first,
            options: zones,
            onSelected: (z) => setState(() => _timezone = z),
          ),
          _section(t, AppText.of(context).settingsConfigScreenSectionGrace),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
                AppText.of(context).settingsConfigScreenGraceEnabledLabel,
                style: t.text.body),
            value: _graceEnabled,
            onChanged: (v) => setState(() => _graceEnabled = v),
          ),
          NbTextField(
              label: AppText.of(context).settingsConfigScreenGraceUnitsLabel,
              controller: _graceUnits,
              keyboardType: TextInputType.number),
          _section(t,
              AppText.of(context).settingsConfigScreenSectionWindowsReminders),
          NbTextField(
              label:
                  AppText.of(context).settingsConfigScreenReversalWindowLabel,
              controller: _reversal,
              keyboardType: TextInputType.number),
          const SizedBox(height: NbSpace.sm),
          NbTextField(
              label: AppText.of(context).settingsConfigScreenPrepLeadLabel,
              controller: _prepLead,
              keyboardType: TextInputType.number),
          const SizedBox(height: NbSpace.sm),
          NbTextField(
              label: AppText.of(context).settingsConfigScreenPurchaseLeadLabel,
              controller: _purchaseLead,
              keyboardType: TextInputType.number),
          _section(t, AppText.of(context).settingsConfigScreenSectionUpi),
          NbTextField(
              label: AppText.of(context).settingsConfigScreenUpiIdLabel,
              controller: _upiId),
          const SizedBox(height: NbSpace.sm),
          NbTextField(
              label: AppText.of(context).settingsConfigScreenPayeeNameLabel,
              controller: _upiPayee),
          const SizedBox(height: NbSpace.xl),
        ],
      ),
      // Save stays in reach instead of stranded at the bottom of a long form.
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
            NbSpace.lg, NbSpace.sm, NbSpace.lg, NbSpace.sm),
        child: NbButton(
          label: AppText.of(context).settingsConfigScreenSaveButton,
          busy: _busy,
          onPressed: _busy ? null : _save,
        ),
      ),
    );
  }

  Widget _section(TiffinTokens t, String label) => Padding(
        padding: const EdgeInsets.only(top: NbSpace.lg, bottom: NbSpace.sm),
        child: Text(label.toUpperCase(), style: t.text.heading),
      );
}
