import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../shared_widgets/app_logo.dart';
import '../theme/tokens.dart';

/// The one layout every setup and sign-in screen shares, so a person always
/// knows where they are: which canteen, what this step is for, what to do, and
/// how to back out (Nielsen #1, #3; Jakob's Law).
///
/// Top to bottom: wordmark, the canteen being set up (with a way to change it),
/// the step title and one line of purpose, the step's [children], any [error]
/// right above the [action], and a quiet [footer] for secondary links. The form
/// sits straight on the page — the fields already carry their own borders, so
/// a heavy card around them was a second frame for no gain.
class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.title,
    this.subtitle,
    this.canteenName,
    this.onChangeCanteen,
    this.body = const [],
    this.error,
    this.action,
    this.footer = const [],
  });

  final String title;
  final String? subtitle;

  /// Shown as context above the title. Null on screens that come before a
  /// canteen is chosen.
  final String? canteenName;
  final VoidCallback? onChangeCanteen;
  final List<Widget> body;
  final String? error;

  /// The single primary action of the step.
  final Widget? action;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
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
                  const Center(child: AppWordmark(logoSize: 36)),
                  const SizedBox(height: NbSpace.lg),
                  if (canteenName != null) ...[
                    _CanteenBar(name: canteenName!, onChange: onChangeCanteen),
                    const SizedBox(height: NbSpace.lg),
                  ],
                  Semantics(
                    header: true,
                    child: Text(title, style: t.text.heading),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: NbSpace.xs),
                    Text(subtitle!,
                        style: t.text.body.copyWith(color: t.color.inkMuted)),
                  ],
                  const SizedBox(height: NbSpace.lg),
                  ...body,
                  if (error != null) ...[
                    const SizedBox(height: NbSpace.md),
                    _ErrorLine(message: error!),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: NbSpace.lg),
                    action!,
                  ],
                  if (footer.isNotEmpty) ...[
                    const SizedBox(height: NbSpace.md),
                    ...footer,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Main Gate Canteen — Change". Context first, escape hatch beside it.
class _CanteenBar extends StatelessWidget {
  const _CanteenBar({required this.name, this.onChange});

  final String name;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.color.surfaceMuted,
        borderRadius: t.shape.radius,
        border: Border.all(color: t.color.border, width: t.shape.borderHair),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: NbSpace.md),
        child: Row(
          children: [
            Icon(Icons.storefront_outlined, color: t.color.ink),
            const SizedBox(width: NbSpace.sm),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.label),
            ),
            if (onChange != null)
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onChange,
                child: Text(AppText.of(context).canteenChange),
              ),
          ],
        ),
      ),
    );
  }
}

/// Icon plus words, so an error never relies on colour alone (§12.2).
class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: t.color.reject),
          const SizedBox(width: NbSpace.sm),
          Expanded(
            child: Text(message,
                style: t.text.body.copyWith(color: t.color.reject)),
          ),
        ],
      ),
    );
  }
}
