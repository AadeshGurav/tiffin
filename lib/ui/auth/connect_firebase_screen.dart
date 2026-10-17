import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/firebase_config.dart';
import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/messages.dart';
import '../shared_widgets/app_logo.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_surface.dart';
import '../theme/tokens.dart';

/// First launch: import the Firebase console's config file for this app.
/// That file is the only configuration this build takes.
class ConnectFirebaseScreen extends ConsumerStatefulWidget {
  const ConnectFirebaseScreen({super.key});

  @override
  ConsumerState<ConnectFirebaseScreen> createState() =>
      _ConnectFirebaseScreenState();
}

class _ConnectFirebaseScreenState extends ConsumerState<ConnectFirebaseScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Any file type: some OEM file managers grey out .plist and .json under
      // a strict filter. The content is what gets checked.
      final picked = await FilePicker.pickFile();
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await ref
          .read(firebaseConfigProvider.notifier)
          .import(utf8.decode(bytes, allowMalformed: true));
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
                        Text(text.connectTitle, style: t.text.heading),
                        const SizedBox(height: NbSpace.xs),
                        Text(text.connectBody, style: t.text.body),
                        if (_error != null) ...[
                          const SizedBox(height: NbSpace.md),
                          Text(_error!,
                              style:
                                  t.text.body.copyWith(color: t.color.reject)),
                        ],
                        const SizedBox(height: NbSpace.lg),
                        NbButton(
                          label: _busy
                              ? text.connectConnecting
                              : text.connectPickButton,
                          icon: Icons.file_open_outlined,
                          busy: _busy,
                          onPressed: _busy ? null : _pick,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: NbSpace.md),
                  Text(text.connectHelp(FirebaseConfig.thisAppId),
                      style: t.text.body.copyWith(color: t.color.inkMuted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
