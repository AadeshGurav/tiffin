import 'package:flutter/widgets.dart';

import 'logging.dart';

/// Records when the app is backgrounded or brought back, so a gap or a
/// restart in the log can be told apart from a crash.
class LifecycleLogger with WidgetsBindingObserver {
  final _log = log('lifecycle');

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _log.info(state.name);
}
