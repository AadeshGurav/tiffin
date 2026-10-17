import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/messages.dart';
import '../shared_widgets/app_logo.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_surface.dart';
import '../shared_widgets/nb_text_field.dart';
import '../theme/tokens.dart';

/// This phone isn't part of the canteen yet. Either it asks to join (and the
/// admin approves it), it starts a brand-new canteen in an unclaimed project,
/// or someone signs in with an online account instead.
class DeviceSetupScreen extends ConsumerStatefulWidget {
  const DeviceSetupScreen(
      {super.key, required this.newCanteen, required this.signedIn});

  /// The project has no owner yet — offer to start the canteen here.
  final bool newCanteen;

  /// This phone already has a Firebase identity (it joined before and was
  /// reset, or is part-way through joining).
  final bool signedIn;

  @override
  ConsumerState<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends ConsumerState<DeviceSetupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _online = false;
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
        // A fresh project flips this screen to the "start a new canteen"
        // confirmation (the access stream reports NotJoined(newCanteen)).
        if (!await access.canteenExists()) return;
        await access.requestApproval(_phoneName);
      });

  Future<void> _claim() =>
      _run(() => ref.read(accessServiceProvider).claimNewCanteen(_phoneName));

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
    final project = ref.watch(firebaseConfigProvider)?.projectId ?? '';

    final card = _online
        ? [
            Text(text.onlineSignInTitle, style: t.text.heading),
            const SizedBox(height: NbSpace.lg),
            NbTextField(
              label: text.onlineEmailLabel,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
            const SizedBox(height: NbSpace.md),
            NbTextField(
                label: text.onlinePasswordLabel,
                controller: _password,
                obscure: true),
            const SizedBox(height: NbSpace.lg),
            NbButton(
              label: text.onlineSignInButton,
              busy: _busy,
              onPressed: _busy ? null : _signInOnline,
            ),
            TextButton(
              onPressed: _busy ? null : _sendReset,
              child: Text(text.onlineForgotButton),
            ),
          ]
        : widget.newCanteen
            ? [
                Text(text.newCanteenTitle, style: t.text.heading),
                const SizedBox(height: NbSpace.xs),
                Text(text.newCanteenBody, style: t.text.body),
                const SizedBox(height: NbSpace.lg),
                NbTextField(
                  label: text.deviceSetupNameLabel,
                  hint: text.deviceSetupNameHint,
                  controller: _name,
                ),
                const SizedBox(height: NbSpace.lg),
                NbButton(
                  label: text.newCanteenButton,
                  icon: Icons.storefront_outlined,
                  busy: _busy,
                  onPressed: _busy ? null : _claim,
                ),
              ]
            : [
                Text(text.deviceSetupTitle, style: t.text.heading),
                const SizedBox(height: NbSpace.xs),
                Text(text.deviceSetupBody, style: t.text.body),
                const SizedBox(height: NbSpace.lg),
                NbTextField(
                  label: text.deviceSetupNameLabel,
                  hint: text.deviceSetupNameHint,
                  controller: _name,
                  autofocus: true,
                ),
                const SizedBox(height: NbSpace.lg),
                NbButton(
                  label: text.deviceSetupJoinButton,
                  icon: Icons.login,
                  busy: _busy,
                  onPressed: _busy ? null : _join,
                ),
              ];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(NbSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppWordmark()),
                  const SizedBox(height: NbSpace.lg),
                  NbSurface(
                    intensity: NbIntensity.full,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...card,
                        if (_error != null) ...[
                          const SizedBox(height: NbSpace.md),
                          Text(_error!,
                              style:
                                  t.text.body.copyWith(color: t.color.reject)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: NbSpace.md),
                  TextButton.icon(
                    icon: Icon(
                        _online ? Icons.arrow_back : Icons.alternate_email,
                        size: 18),
                    label: Text(_online
                        ? text.onlineBack
                        : text.deviceSetupOnlineButton),
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _online = !_online;
                              _error = null;
                            }),
                  ),
                  Text(text.deviceSetupProject(project),
                      textAlign: TextAlign.center,
                      style: t.text.body.copyWith(color: t.color.inkMuted)),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () =>
                            ref.read(firebaseConfigProvider.notifier).forget(),
                    child: Text(text.deviceSetupChangeProject),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
