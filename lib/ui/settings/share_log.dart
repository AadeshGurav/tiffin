import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/logging.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/messages.dart';
import '../shared_widgets/nb_feedback.dart';

/// Hands this phone's log file to the share sheet so the admin can send it to
/// IT, who finds the failure by the code the screen showed (docs/ERRORS.md).
/// Shows nothing on success: the share sheet is the confirmation.
Future<void> shareLogFile(BuildContext context) async {
  final text = AppText.of(context);
  final path = AppLogger.logFilePath;
  if (path == null || !File(path).existsSync()) {
    showNbSnack(context, text.shareLogEmpty, ok: false);
    return;
  }
  // iPad share sheets anchor to a rectangle; phones ignore it.
  final box = context.findRenderObject() as RenderBox?;
  try {
    await AppLogger.flush();
    await SharePlus.instance.share(ShareParams(
      files: [XFile(path, mimeType: 'text/plain')],
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  } catch (e, st) {
    if (!context.mounted) return;
    final notice = text.describeError(e, st);
    showNbSnack(context, notice.message, ok: false, ref: notice.ref);
  }
}
