import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/appearance_providers.dart';
import '../../app/locale_providers.dart';
import '../../app/providers.dart';
import '../../app/session_memory.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/locale_store.dart';
import '../../services/settings_service.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/nb_surface.dart';
import '../theme/appearance.dart';
import '../theme/theme_catalog.dart';
import '../theme/tokens.dart';
import 'theme_preview.dart';

/// Settings ▸ Appearance. Available to every role on every device, because how
/// a screen looks is a property of the screen, not of who signed in.
///
/// When the host enforces an appearance the controls stay visible but go
/// read-only, with the reason stated — silently ignoring a tap is worse than
/// disabling it (CLAUDE.md §11.1 heuristic 1).
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppText.of(context);
    final device = ref.watch(deviceAppearanceProvider);
    final effective = ref.watch(effectiveAppearanceProvider);
    final enforced = ref.watch(appearanceIsEnforcedProvider);
    final isAdmin = ref.watch(sessionProvider)?.role.isAdmin ?? false;
    final controller = ref.read(deviceAppearanceProvider.notifier);
    final locale = ref.watch(deviceLocaleProvider);
    final localeController = ref.read(deviceLocaleProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l.apprScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(NbSpace.lg),
        children: [
          if (enforced) ...[
            NbSurface(
              background: t.color.warn,
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: t.color.onWarn),
                  const SizedBox(width: NbSpace.sm),
                  Expanded(
                    child: Text(
                      l.apprScreenEnforcedBanner,
                      style: t.text.body.copyWith(color: t.color.onWarn),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: NbSpace.lg),
          ],
          Text(l.apprScreenThemeLabel, style: t.text.label),
          const SizedBox(height: NbSpace.sm),
          for (final id in TiffinThemeId.values) ...[
            ThemePreviewCard(
              id: id,
              brightness: effective
                  .brightness(MediaQuery.platformBrightnessOf(context)),
              selected: effective.theme == id,
              enabled: !enforced,
              onTap: () => controller.setTheme(id),
            ),
            const SizedBox(height: NbSpace.sm),
          ],
          const SizedBox(height: NbSpace.md),
          Text(l.apprScreenModeLabel, style: t.text.label),
          const SizedBox(height: NbSpace.sm),
          _ModeSelector(
            value: effective.mode,
            enabled: !enforced,
            onChanged: controller.setMode,
          ),
          const SizedBox(height: NbSpace.lg),
          Text(l.apprScreenMotionLabel, style: t.text.label),
          const SizedBox(height: NbSpace.sm),
          NbSurface(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.apprScreenMotionTitle, style: t.text.body),
              subtitle: Text(
                effective.motion
                    ? l.apprScreenMotionOnSubtitle
                    : l.apprScreenMotionOffSubtitle,
                style: t.text.body.copyWith(color: t.color.inkMuted),
              ),
              value: effective.motion,
              onChanged:
                  enforced ? null : (v) => controller.setMotion(enabled: v),
            ),
          ),
          const SizedBox(height: NbSpace.xs),
          Text(
            l.apprScreenReduceMotionNote,
            style: t.text.body.copyWith(color: t.color.inkMuted),
          ),
          const SizedBox(height: NbSpace.xl),
          Text(l.apprScreenLanguageLabel, style: t.text.label),
          const SizedBox(height: NbSpace.sm),
          _LanguageSelector(value: locale, onChanged: localeController.set),
          const SizedBox(height: NbSpace.xl),
          const _SavedLoginsCard(),
          if (isAdmin) ...[
            const SizedBox(height: NbSpace.xl),
            _EnforceCard(enforced: enforced, appearance: device),
          ],
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final ThemeMode value;
  final bool enabled;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppText.of(context);
    return Row(
      children: [
        for (final (mode, label, icon) in [
          (ThemeMode.system, l.apprScreenModeSystem, Icons.brightness_auto),
          (ThemeMode.light, l.apprScreenModeLight, Icons.light_mode),
          (ThemeMode.dark, l.apprScreenModeDark, Icons.dark_mode),
        ]) ...[
          Expanded(
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: NbSurface(
                intensity:
                    value == mode ? NbIntensity.full : NbIntensity.restrained,
                background: value == mode ? t.color.accent : t.color.surface,
                padding: const EdgeInsets.symmetric(vertical: NbSpace.md),
                onTap: enabled ? () => onChanged(mode) : null,
                child: Column(
                  children: [
                    // Selection is carried by fill, border weight AND a check
                    // — never colour alone (§12.2).
                    Icon(icon,
                        color: value == mode
                            ? t.color.on(t.color.accent)
                            : t.color.ink),
                    const SizedBox(height: NbSpace.xs),
                    Text(label,
                        style: t.text.label.copyWith(
                            color: value == mode
                                ? t.color.on(t.color.accent)
                                : t.color.ink)),
                  ],
                ),
              ),
            ),
          ),
          if (mode != ThemeMode.dark) const SizedBox(width: NbSpace.sm),
        ],
      ],
    );
  }
}

/// Which language this device shows its own UI in. Purely device-local (see
/// [LocaleStore]) — no host-enforcement concept, unlike appearance: a
/// canteen's staff and members don't need to share a language the way they
/// share a visual brand.
class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.value, required this.onChanged});

  final AppLocaleId value;
  final ValueChanged<AppLocaleId> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        for (final id in AppLocaleId.values) ...[
          Expanded(
            child: NbSurface(
              intensity:
                  value == id ? NbIntensity.full : NbIntensity.restrained,
              background: value == id ? t.color.accent : t.color.surface,
              padding: const EdgeInsets.symmetric(vertical: NbSpace.md),
              onTap: () => onChanged(id),
              child: Text(
                id.nativeName,
                textAlign: TextAlign.center,
                style: t.text.label.copyWith(
                    color: value == id
                        ? t.color.on(t.color.accent)
                        : t.color.ink),
              ),
            ),
          ),
          if (id != AppLocaleId.values.last) const SizedBox(width: NbSpace.sm),
        ],
      ],
    );
  }
}

/// Host-admin control: push this device's appearance to every device.
class _EnforceCard extends ConsumerStatefulWidget {
  const _EnforceCard({required this.enforced, required this.appearance});

  final bool enforced;
  final Appearance appearance;

  @override
  ConsumerState<_EnforceCard> createState() => _EnforceCardState();
}

class _EnforceCardState extends ConsumerState<_EnforceCard> {
  bool _busy = false;

  Future<void> _apply({required bool enforce}) async {
    final l = AppText.of(context);
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => ref.read(backendProvider).updateSettings(SettingsPatch(
            enforceAppearance: enforce,
            appearanceTheme: widget.appearance.theme.wire,
            appearanceMode: widget.appearance.mode.name,
            appearanceMotion: widget.appearance.motion,
          )),
      successMessage: enforce
          ? l.apprScreenEnforceOnToast
          : l.apprScreenEnforceOffToast,
    );
    if (ok) ref.invalidate(appearancePolicyProvider);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppText.of(context);
    return NbSurface(
      tone: NbTone.system,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.apprScreenEnforceSectionLabel, style: t.text.label),
          const SizedBox(height: NbSpace.xs),
          Text(
            widget.enforced
                ? l.apprScreenEnforceEnabledBody
                : l.apprScreenEnforceDisabledBody,
            style: t.text.body,
          ),
          const SizedBox(height: NbSpace.md),
          if (widget.enforced)
            NbButton.secondary(
              label: l.apprScreenLetDevicesChoose,
              icon: Icons.lock_open,
              busy: _busy,
              onPressed: _busy ? null : () => _apply(enforce: false),
            )
          else
            NbButton(
              label: l.apprScreenUseEverywhere,
              icon: Icons.lock_outline,
              busy: _busy,
              onPressed: _busy ? null : () => _apply(enforce: true),
            ),
        ],
      ),
    );
  }
}

/// What this device has remembered, and the one control that clears it.
///
/// Lives here rather than in admin Settings because it is a property of the
/// phone, and because scanner and counter roles have no Settings screen — they
/// would otherwise have no way to clear a saved password.
class _SavedLoginsCard extends ConsumerWidget {
  const _SavedLoginsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppText.of(context);
    final hosts = ref.watch(savedHostsProvider).asData?.value ?? const [];

    return NbSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.apprScreenSavedLoginsLabel, style: t.text.label),
          const SizedBox(height: NbSpace.xs),
          if (hosts.isEmpty)
            Text(l.apprScreenSavedLoginsEmpty,
                style: t.text.body.copyWith(color: t.color.inkMuted))
          else ...[
            Text(l.apprScreenSavedLoginsBlurb, style: t.text.body),
            const SizedBox(height: NbSpace.sm),
            for (final host in hosts)
              Padding(
                padding: const EdgeInsets.only(bottom: NbSpace.xs),
                child: Row(
                  children: [
                    Icon(Icons.dns_outlined, size: 18, color: t.color.inkMuted),
                    const SizedBox(width: NbSpace.sm),
                    Expanded(
                      child: Text(
                        l.apprScreenSavedLoginsRow(host.name,
                            host.logins.map((login) => login.username).join(', ')),
                        style: t.text.body,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: NbSpace.sm),
            NbButton.secondary(
              label: l.apprScreenForgetAllLogins,
              icon: Icons.delete_outline,
              onPressed: () => runGuarded(
                context,
                ref.read(sessionMemoryProvider).forgetEverything,
                successMessage: l.apprScreenLoginsCleared,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
