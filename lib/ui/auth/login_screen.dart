import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/appearance_providers.dart';
import '../../app/credential_store.dart';
import '../../app/providers.dart';
import '../../app/session_memory.dart';
import '../../core/role.dart';
import '../../l10n/messages.dart';
import '../shared_widgets/brand_splash.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/nb_surface.dart';
import '../shared_widgets/nb_text_field.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';

/// Sign-in for scanner / counter / admin roles (PRD §4, §6.4). The session is
/// remembered on this device until sign-out or expiry, so a shared kiosk logs
/// in once.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _rememberPassword = false;
  bool _resuming = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // A device coming back to a host it already knows shouldn't have to sign
    // in again. The saved token is offered to the host, which is free to
    // reject it — that's the fallback to this form.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final resumed = await ref.read(sessionMemoryProvider).tryResume();
      if (!mounted) return;
      setState(() => _resuming = false);
      if (resumed) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .login(_username.text.trim(), _password.text);
      await ref.read(sessionMemoryProvider).remember(
            username: _username.text.trim(),
            password: _password.text,
            rememberPassword: _rememberPassword,
          );
      // The gate swaps the root route's child; anything pushed above it (a
      // settings route left over from signing out) has to come off too.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) setState(() => _error = AppText.of(context).errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Sets a new password for an offline account, offered on admin phones only.
  Future<void> _recoverPassword() async {
    final auth = ref.read(backendProvider).auth;
    final username = _username.text.trim();
    final result = await showDialog<({String username, String password})>(
      context: context,
      builder: (_) => _RecoverPasswordDialog(
        initialUsername: username.isEmpty ? 'admin' : username,
        suggestion: auth.suggestPassword(),
      ),
    );
    if (result == null) return;

    setState(() => _busy = true);
    try {
      await auth.resetPasswordFor(result.username, result.password);
      _username.text = result.username;
      _password.text = result.password;
      setState(() => _error = null);
      if (mounted) {
        showNbSnack(context, AppText.of(context).loginPasswordResetSnack);
      }
    } catch (e) {
      if (mounted) setState(() => _error = AppText.of(context).errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = AppText.of(context);
    final greeting = ref.watch(hostGreetingProvider);
    // Recovery is offered on admin phones only: such a phone can already
    // manage every account from Settings, so it grants nothing new.
    final isAdminPhone = ref.watch(grantProvider)?.role == Role.admin;

    // While a saved token is being offered to the host, show the splash
    // rather than a login form that may be about to disappear.
    if (_resuming) return BrandSplash(message: text.loginResumingMessage);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(NbSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The sign-in card comes first — advisories are context, not
                  // the task, and pushing the fields down the screen buries the
                  // one thing the operator opened this screen to do.
                  NbSurface(
                    intensity: NbIntensity.full,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          greeting.asData?.value.appName ?? text.appTitle,
                          style: t.text.heading,
                        ),
                        const SizedBox(height: NbSpace.xs),
                        Text(text.loginSignInLabel, style: t.text.body),
                        const SizedBox(height: NbSpace.lg),
                        NbTextField(
                          label: text.loginUsernameLabel,
                          controller: _username,
                          autofocus: true,
                        ),
                        const SizedBox(height: NbSpace.md),
                        NbTextField(
                          label: text.loginPasswordLabel,
                          controller: _password,
                          obscure: true,
                        ),
                        // Opt-in, and per account: these are shared canteen
                        // phones, so saving a password is a decision someone
                        // makes rather than a side effect of signing in.
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _rememberPassword,
                          onChanged: (v) =>
                              setState(() => _rememberPassword = v ?? false),
                          title: Text(text.loginRememberPasswordLabel,
                              style: t.text.body),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: NbSpace.md),
                          Text(_error!,
                              style:
                                  t.text.body.copyWith(color: t.color.reject)),
                        ],
                        const SizedBox(height: NbSpace.lg),
                        NbButton(
                          label: text.loginSignInButton,
                          busy: _busy,
                          onPressed: _busy ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                  _SavedLogins(
                    onPick: (login) {
                      setState(() {
                        _username.text = login.username;
                        _password.text = login.password ?? '';
                        _rememberPassword = login.password != null;
                        _error = null;
                      });
                      if (login.password != null) _submit();
                    },
                  ),
                  if (isAdminPhone)
                    TextButton.icon(
                      icon: const Icon(Icons.lock_reset, size: 18),
                      label: Text(text.loginForgotPasswordButton),
                      onPressed: _busy ? null : _recoverPassword,
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

/// Accounts this device has signed in with on this host. Usernames only,
/// unless the operator asked for the password to be kept too.
class _SavedLogins extends ConsumerWidget {
  const _SavedLogins({required this.onPick});

  final void Function(SavedLogin) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = AppText.of(context);
    final saved = ref.watch(savedLoginsForHostProvider).asData?.value;
    if (saved == null || saved.logins.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: NbSpace.md),
      child: NbSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text.loginSavedLoginsHeader, style: t.text.label),
            const SizedBox(height: NbSpace.xs),
            for (final login in saved.logins)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    login.password != null ? Icons.key : Icons.person_outline,
                    color: t.color.ink),
                title: Text(login.username, style: t.text.body),
                subtitle: Text(
                  login.password != null
                      ? text.loginSavedLoginTapToSignIn
                      : text.loginSavedLoginTapToFillUsername,
                  style: t.text.body.copyWith(color: t.color.inkMuted),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: text.loginForgetAccountTooltip,
                  onPressed: () => ref
                      .read(sessionMemoryProvider)
                      .forgetLogin(saved.hostId, login.username),
                ),
                onTap: () => onPick(login),
              ),
          ],
        ),
      ),
    );
  }
}

/// Typed confirmation for the host-device password reset. Requires the word
/// RESET, matching the pattern the destructive data wipe already uses, so a
/// stray tap on a shared phone can't change a credential.
class _RecoverPasswordDialog extends StatefulWidget {
  const _RecoverPasswordDialog({
    required this.initialUsername,
    required this.suggestion,
  });

  final String initialUsername;
  final String suggestion;

  @override
  State<_RecoverPasswordDialog> createState() => _RecoverPasswordDialogState();
}

class _RecoverPasswordDialogState extends State<_RecoverPasswordDialog> {
  late final _username = TextEditingController(text: widget.initialUsername);
  late final _password = TextEditingController(text: widget.suggestion);
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = AppText.of(context);
    final armed =
        confirmWordMatches(_confirm.text, text.confirmWordReset, 'RESET');
    return AlertDialog(
      title: Text(text.loginRecoverDialogTitle, style: t.text.heading),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              text.loginRecoverDialogBody,
              style: t.text.body,
            ),
            const SizedBox(height: NbSpace.md),
            NbTextField(
                label: text.loginRecoverAccountLabel, controller: _username),
            const SizedBox(height: NbSpace.sm),
            NbTextField(
                label: text.loginRecoverNewPasswordLabel,
                controller: _password),
            const SizedBox(height: NbSpace.sm),
            NbTextField(
              label: text.loginRecoverConfirmLabel,
              controller: _confirm,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(text.loginRecoverCancelButton),
        ),
        NbButton(
          label: text.loginRecoverSubmitButton,
          background: t.color.reject,
          onPressed: armed
              ? () => Navigator.pop(
                    context,
                    (
                      username: _username.text.trim(),
                      password: _password.text,
                    ),
                  )
              : null,
        ),
      ],
    );
  }
}
