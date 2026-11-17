import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_report.dart';
import '../../app/providers.dart';
import '../../data/canteens.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/messages.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../theme/tokens.dart';

/// Sign in with Apple needs the iOS capability and a paid developer team, so
/// the button appears only in builds made with `--dart-define=APPLE_SIGN_IN=true`.
const _appleEnabled = bool.fromEnvironment('APPLE_SIGN_IN');

/// Microsoft sign-in needs an Azure app registration wired into Firebase Auth,
/// so it is opt-in too: `--dart-define=MICROSOFT_SIGN_IN=true`.
const _microsoftEnabled = bool.fromEnvironment('MICROSOFT_SIGN_IN');

/// "Continue with Google / Microsoft / Apple". [onSignedIn] runs once the
/// person is signed in, so each screen decides what happens next.
class ProviderButtons extends ConsumerStatefulWidget {
  const ProviderButtons({super.key, required this.onSignedIn});

  final Future<void> Function() onSignedIn;

  @override
  ConsumerState<ProviderButtons> createState() => _ProviderButtonsState();
}

class _ProviderButtonsState extends ConsumerState<ProviderButtons> {
  bool _busy = false;
  ErrorNotice? _error;

  Future<void> _go(SignInProvider which) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(canteenServiceProvider).signInWith(which);
      final user = ref.read(identityProvider).currentUser;
      if (user != null && !user.isAnonymous) await widget.onSignedIn();
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
    final text = AppText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NbButton.secondary(
          label: text.signInGoogle,
          icon: Icons.g_mobiledata,
          onPressed: _busy ? null : () => _go(SignInProvider.google),
        ),
        if (_microsoftEnabled) ...[
          const SizedBox(height: NbSpace.sm),
          NbButton.secondary(
            label: text.signInMicrosoft,
            icon: Icons.window,
            onPressed: _busy ? null : () => _go(SignInProvider.microsoft),
          ),
        ],
        if (_appleEnabled && Platform.isIOS) ...[
          const SizedBox(height: NbSpace.sm),
          NbButton.secondary(
            label: text.signInApple,
            icon: Icons.apple,
            onPressed: _busy ? null : () => _go(SignInProvider.apple),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: NbSpace.sm),
          ErrorNoticeView(_error!),
        ],
      ],
    );
  }
}
