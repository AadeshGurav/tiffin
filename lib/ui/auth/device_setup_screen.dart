import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/canteen_book.dart';
import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/messages.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_text_field.dart';
import 'provider_buttons.dart';
import '../theme/tokens.dart';
import 'auth_frame.dart';

/// This phone isn't part of the active canteen yet. Either it asks to join
/// (and the admin approves it), or someone signs in with an online account.
class DeviceSetupScreen extends ConsumerStatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  ConsumerState<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends ConsumerState<DeviceSetupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  // Online sign-in first: managers and admins come back this way, and a shared
  // phone is the rarer case (it is one tap away below).
  bool _online = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
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

  String get _phoneName {
    final typed = _name.text.trim();
    return typed.isEmpty ? AppText.of(context).deviceSetupNameHint : typed;
  }

  Future<void> _join() => _run(() async {
        final access = ref.read(accessServiceProvider);
        await access.ensureIdentity();
        await access.requestApproval(_phoneName);
      });

  Future<void> _signInOnline() => _run(() async {
        await ref
            .read(accessServiceProvider)
            .signInOnline(_email.text, _password.text);
      });

  Future<void> _sendReset() => _run(() async {
        await ref.read(accessServiceProvider).sendPasswordReset(_email.text);
        if (mounted) {
          setState(() =>
              _error = AppText.of(context).onlineResetSent(_email.text.trim()));
        }
      });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = AppText.of(context);
    final canteen = ref.watch(canteenBookProvider).active?.name ?? '';

    // Both ways in are always visible: "who are you signing in as" is the one
    // question on this screen, and hiding half the answer behind a text link
    // left people guessing which path they were on.
    final mode = SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: true, label: Text(text.setupModeOnline)),
        ButtonSegment(value: false, label: Text(text.setupModeSharedPhone)),
      ],
      selected: {_online},
      onSelectionChanged: _busy
          ? null
          : (v) => setState(() {
                _online = v.first;
                _error = null;
              }),
    );

    final fields = _online
        ? [
            Text(text.setupOnlineHint,
                style: t.text.body.copyWith(color: t.color.inkMuted)),
            const SizedBox(height: NbSpace.md),
            ProviderButtons(
              onSignedIn: () async {
                final user = ref.read(identityProvider).currentUser!;
                await ref.read(accessServiceProvider).requestOnlineAccess(user);
              },
            ),
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
                controller: _password,
                obscure: true),
          ]
        : [
            Text(text.deviceSetupBody,
                style: t.text.body.copyWith(color: t.color.inkMuted)),
            const SizedBox(height: NbSpace.md),
            NbTextField(
              label: text.deviceSetupNameLabel,
              hint: text.deviceSetupNameHint,
              controller: _name,
            ),
          ];

    return AuthFrame(
      title: text.deviceSetupTitle,
      canteenName: canteen,
      onChangeCanteen: _busy
          ? null
          : () => ref.read(canteenBookProvider.notifier).deactivate(),
      body: [mode, const SizedBox(height: NbSpace.lg), ...fields],
      error: _error,
      action: _online
          ? NbButton(
              label: text.onlineSignInButton,
              busy: _busy,
              onPressed: _busy ? null : _signInOnline,
            )
          : NbButton(
              label: text.deviceSetupJoinButton,
              icon: Icons.login,
              busy: _busy,
              onPressed: _busy ? null : _join,
            ),
      footer: [
        if (_online)
          TextButton(
            onPressed: _busy ? null : _sendReset,
            child: Text(text.onlineForgotButton),
          ),
      ],
    );
  }
}
