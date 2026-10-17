import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'nb_surface.dart';

/// The honest fine print for hosting on an iPhone. iOS gives an app no way to
/// keep a server alive in the background and no way to create its own network,
/// so the operator has to know this up front — shown on first host setup and in
/// Admin → Hosting, never buried in a doc.
class IosHostAdvisory extends StatelessWidget {
  const IosHostAdvisory({super.key});

  static List<String> _points(BuildContext context) => [
        AppText.of(context).iosHostAdvisoryPointForeground,
        AppText.of(context).iosHostAdvisoryPointWifi,
        AppText.of(context).iosHostAdvisoryPointAndroid,
      ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NbSurface(
      intensity: NbIntensity.full,
      background: t.color.warn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppText.of(context).iosHostAdvisoryTitle,
              style: t.text.label.copyWith(color: t.color.onWarn)),
          for (final p in _points(context))
            Padding(
              padding: const EdgeInsets.only(top: NbSpace.xs),
              child: Text('•  $p',
                  style: t.text.body.copyWith(color: t.color.onWarn)),
            ),
        ],
      ),
    );
  }
}
