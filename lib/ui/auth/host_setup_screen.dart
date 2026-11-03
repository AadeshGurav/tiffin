import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/messages.dart';
import '../admin/backup_screen.dart' show showImportDialog;
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_text_field.dart';
import '../theme/tokens.dart';
import 'auth_frame.dart';
import '../../l10n/app_localizations.dart';

/// First run on a new canteen: the operator creates the admin account (or
/// brings over an earlier canteen's records, accounts included).
///
/// This replaced a scheme that generated a password and showed it once on the
/// login screen. The account existed, but the password was held only in
/// memory — miss the banner or restart the app and the host had an admin
/// nobody could sign in as, recoverable only by wiping the database. Choosing
/// your own credentials cannot be lost by looking away.
///
/// Shown whenever there are no accounts, so it also comes back correctly
/// after a data reset instead of being a one-shot.
class HostSetupScreen extends ConsumerStatefulWidget {
  const HostSetupScreen({super.key});

  @override
  ConsumerState<HostSetupScreen> createState() => _HostSetupScreenState();
}

class _HostSetupScreenState extends ConsumerState<HostSetupScreen> {
  final _username = TextEditingController(text: 'admin');
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _revealed = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _suggest() async {
    final suggestion = ref.read(backendProvider).auth.suggestPassword();
    setState(() {
      _password.text = suggestion;
      _confirm.text = suggestion;
      // Revealed on purpose: a generated password you cannot read is one you
      // cannot write down, which is how the previous scheme stranded hosts.
      _revealed = true;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_password.text != _confirm.text) {
      setState(() => _error = AppText.of(context).hostSetupPasswordMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(backendProvider).auth.createInitialAdmin(
            username: _username.text.trim(),
            password: _password.text,
          );
      ref.invalidate(setupRequiredProvider);
      // Straight in, rather than making someone retype what they just chose.
      await ref
          .read(sessionProvider.notifier)
          .login(_username.text.trim(), _password.text);
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
    return AuthFrame(
      title: text.hostSetupTitle,
      subtitle: text.hostSetupSubtitle,
      body: [
        NbTextField(
          label: text.hostSetupUsernameLabel,
          controller: _username,
          autofocus: true,
        ),
        const SizedBox(height: NbSpace.md),
        NbTextField(
          label: text.hostSetupPasswordLabel,
          controller: _password,
          obscure: !_revealed,
        ),
        const SizedBox(height: NbSpace.md),
        NbTextField(
          label: text.hostSetupConfirmPasswordLabel,
          controller: _confirm,
          obscure: !_revealed,
        ),
        const SizedBox(height: NbSpace.sm),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.casino_outlined, size: 18),
                label: Text(text.hostSetupSuggestButton),
                onPressed: _busy ? null : _suggest,
              ),
            ),
            IconButton(
              icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility),
              tooltip: _revealed
                  ? text.hostSetupHidePassword
                  : text.hostSetupShowPassword,
              onPressed: () => setState(() => _revealed = !_revealed),
            ),
          ],
        ),
        // A hint beside the fields, not a yellow card of its own: it is advice
        // about this password, not a second thing to act on.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.key_outlined, size: 20, color: t.color.inkMuted),
            const SizedBox(width: NbSpace.sm),
            Expanded(
              child: Text(text.hostSetupPasswordWarning,
                  style: t.text.body.copyWith(color: t.color.inkMuted)),
            ),
          ],
        ),
      ],
      error: _error,
      action: NbButton(
        label: text.hostSetupSubmitButton,
        icon: Icons.check,
        busy: _busy,
        onPressed: _busy ? null : _submit,
      ),
      // Offered before choosing credentials: an imported backup brings its own
      // accounts, and replaces anything made here.
      footer: [
        TextButton.icon(
          icon: const Icon(Icons.drive_file_move_outline, size: 18),
          label: Text(text.importTitle),
          onPressed: _busy
              ? null
              : () async {
                  final imported = await showImportDialog(context);
                  if (imported) ref.invalidate(setupRequiredProvider);
                },
        ),
      ],
    );
  }
}
