import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/canteen_book.dart';
import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../data/canteens.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/messages.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_group.dart';
import '../shared_widgets/nb_text_field.dart';
import 'provider_buttons.dart';
import '../theme/tokens.dart';
import 'auth_frame.dart';

enum _Step { home, join, create }

/// Shown whenever this phone has no active canteen: first launch, or after
/// choosing "switch canteen". It is also the switcher — every canteen this
/// phone knows is listed here, one tap from being active again (ADR 0006).
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _Step _step = _Step.home;
  bool _fromBackup = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = AppText.of(context).errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _go(_Step step) => setState(() {
        _step = step;
        _error = null;
      });

  Future<void> _join() => _run(() async {
        final service = ref.read(canteenServiceProvider);
        final name = await service.nameOf(_code.text);
        await ref
            .read(canteenBookProvider.notifier)
            .activate(CanteenService.normalise(_code.text), name);
        // A person already signed in with a real account asks to join as
        // themselves; an anonymous phone goes on to the phone-join screen.
        final user = ref.read(identityProvider).currentUser;
        if (user != null && !user.isAnonymous) {
          await ref.read(accessServiceProvider).requestOnlineAccess(user);
        }
      });

  Future<void> _create() => _run(() async {
        final service = ref.read(canteenServiceProvider);
        final user = ref.read(identityProvider).currentUser;
        if (user == null || user.isAnonymous) {
          if (_password.text.length < 6) {
            throw const ValidationException(
                ErrorCode.passwordTooShort, {'min': 6});
          }
          await service.signInWithEmail(_email.text, _password.text);
        }
        final made = await service.create(_name.text);
        ref.read(startFromBackupProvider.notifier).set(_fromBackup);
        await ref
            .read(canteenBookProvider.notifier)
            .activate(made.code, made.name);
      });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = AppText.of(context);
    final known = ref.watch(canteenBookProvider).canteens;
    final user = ref.watch(identityChangesProvider).asData?.value;
    final signedIn = user != null && !user.isAnonymous;

    final back = TextButton.icon(
      icon: const Icon(Icons.arrow_back, size: 18),
      label: Text(text.onlineBack),
      onPressed: _busy ? null : () => _go(_Step.home),
    );

    return switch (_step) {
      // With canteens already on this phone the first job is picking one, so
      // they lead and joining or creating is the quieter second choice.
      _Step.home => AuthFrame(
          title: known.isEmpty ? text.welcomeTitle : text.welcomeYourCanteens,
          subtitle: known.isEmpty ? text.welcomeBody : null,
          body: [
            if (known.isNotEmpty) ...[
              _KnownCanteens(canteens: known),
              const SizedBox(height: NbSpace.lg),
            ],
            if (known.isEmpty)
              NbButton(
                label: text.welcomeJoinButton,
                icon: Icons.login,
                onPressed: () => _go(_Step.join),
              )
            else
              NbButton.secondary(
                label: text.welcomeJoinButton,
                icon: Icons.login,
                onPressed: () => _go(_Step.join),
              ),
            const SizedBox(height: NbSpace.md),
            NbButton.secondary(
              label: text.welcomeCreateButton,
              icon: Icons.storefront_outlined,
              onPressed: () => _go(_Step.create),
            ),
          ],
        ),
      // Signing in is not asked here: the next screen opens on it, so a
      // returning admin is recognised without a second place to do it.
      _Step.join => AuthFrame(
          title: text.joinTitle,
          subtitle: text.joinBody,
          body: [
            NbTextField(
              label: text.joinCodeLabel,
              controller: _code,
              autofocus: true,
            ),
            if (signedIn) ...[
              const SizedBox(height: NbSpace.md),
              Text(text.createSignedInAs(user.email ?? ''),
                  style: t.text.body.copyWith(color: t.color.inkMuted)),
            ],
          ],
          error: _error,
          action: NbButton(
            label: text.joinContinueButton,
            icon: Icons.search,
            busy: _busy,
            onPressed: _busy ? null : _join,
          ),
          footer: [back],
        ),
      _Step.create => AuthFrame(
          title: text.createTitle,
          subtitle: text.createBody,
          body: [
            NbTextField(
              label: text.createNameLabel,
              hint: text.createNameHint,
              controller: _name,
              autofocus: true,
            ),
            const SizedBox(height: NbSpace.lg),
            if (signedIn)
              Text(text.createSignedInAs(user.email ?? ''),
                  style: t.text.body.copyWith(color: t.color.inkMuted))
            else ...[
              ProviderButtons(onSignedIn: () async {}),
              const SizedBox(height: NbSpace.md),
              Text(text.signInOr,
                  style: t.text.label.copyWith(color: t.color.inkMuted)),
              const SizedBox(height: NbSpace.sm),
              NbTextField(
                label: text.onlineEmailLabel,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: NbSpace.md),
              NbTextField(
                  label: text.onlinePasswordLabel,
                  hint: text.createPasswordHint,
                  controller: _password,
                  obscure: true),
            ],
            const SizedBox(height: NbSpace.sm),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _fromBackup,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _fromBackup = v ?? false),
              title: Text(text.createFromBackup, style: t.text.body),
            ),
          ],
          error: _error,
          action: NbButton(
            label: text.createButton,
            icon: Icons.storefront_outlined,
            busy: _busy,
            onPressed: _busy ? null : _create,
          ),
          footer: [back],
        ),
    };
  }
}

/// Canteens this phone already knows: one tap makes one active again.
class _KnownCanteens extends ConsumerWidget {
  const _KnownCanteens({required this.canteens});

  final List<JoinedCanteen> canteens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(context);
    final book = ref.read(canteenBookProvider.notifier);
    return NbGroup(children: [
      for (final c in canteens)
        NbListRow(
          icon: Icons.storefront_outlined,
          title: c.name,
          subtitle: c.code,
          onTap: () => book.activate(c.code, c.name),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: text.welcomeLeaveTooltip,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => book.leave(c.code),
          ),
        ),
    ]);
  }
}
