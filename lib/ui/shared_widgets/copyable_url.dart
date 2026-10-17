import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'nb_feedback.dart';

/// A LAN URL that copies to the clipboard on tap, with a cheerful confirmation
/// (the operator does this a lot — reward the tap, Peak-End Rule, CLAUDE.md
/// §11.2).
class CopyableUrl extends StatelessWidget {
  const CopyableUrl({super.key, required this.url});

  final String url;

  static List<String> _quips(BuildContext context) => [
        AppText.of(context).copyableUrlQuip1,
        AppText.of(context).copyableUrlQuip2,
        AppText.of(context).copyableUrlQuip3,
        AppText.of(context).copyableUrlQuip4,
        AppText.of(context).copyableUrlQuip5,
        AppText.of(context).copyableUrlQuip6,
      ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: url));
        if (context.mounted) {
          final quips = _quips(context);
          showNbSnack(context, quips[Random().nextInt(quips.length)]);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: NbSpace.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                url,
                style: t.text.body.copyWith(
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(width: NbSpace.xs),
            Icon(Icons.copy, size: 16, color: t.color.ink),
          ],
        ),
      ),
    );
  }
}
