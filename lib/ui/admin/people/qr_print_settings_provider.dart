import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../app/providers.dart';
import '../../../core/print_layout.dart';

final _log = Logger('QrPrintSettings');

/// The paper/card layout last used for printing QR cards, remembered on this
/// device so the admin sets up their printer once.
class QrPrintSettingsController extends Notifier<PrintSettings> {
  static const _key = 'qr_print_settings';

  @override
  PrintSettings build() {
    final stored = ref.read(sharedPreferencesProvider).getString(_key);
    if (stored == null) return const PrintSettings();
    try {
      return PrintSettings.fromJson(jsonDecode(stored) as Map<String, dynamic>);
    } on FormatException catch (e) {
      // A corrupt value must not lock the screen: start from the defaults.
      _log.warning('ignoring unreadable saved print layout', e);
      return const PrintSettings();
    }
  }

  Future<void> save(PrintSettings settings) async {
    state = settings;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(settings.toJson()));
  }
}

final qrPrintSettingsProvider =
    NotifierProvider<QrPrintSettingsController, PrintSettings>(
        QrPrintSettingsController.new);
