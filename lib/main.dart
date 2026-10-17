import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'app/app_gate.dart';
import 'app/appearance_providers.dart';
import 'app/bootstrap.dart';
import 'app/locale_providers.dart';
import 'core/logging.dart';
import 'l10n/app_localizations.dart';
import 'l10n/locale_store.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await bootstrap();

  // Nothing fails silently (PRD §7, CLAUDE.md §8): every uncaught framework or
  // async error is written to the log and shown as a readable panel instead of
  // the red screen of death.
  final crash = log('crash');
  final priorOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    crash.severe('flutter framework error', details.exception, details.stack);
    priorOnError?.call(details);
  };
  final crashText = lookupAppText(LocaleStore(prefs).read().locale);
  ErrorWidget.builder =
      (details) => _FriendlyErrorWidget(details: details, text: crashText);
  PlatformDispatcher.instance.onError = (error, stack) {
    crash.severe('uncaught async error', error, stack);
    return true;
  };

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const TiffinApp(),
    ),
  );
}

class TiffinApp extends ConsumerWidget {
  const TiffinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Light and dark are both built and handed to MaterialApp so "system"
    // follows the OS without us watching for brightness changes ourselves.
    final appearance = ref.watch(effectiveAppearanceProvider);
    final localeId = ref.watch(deviceLocaleProvider);
    final appName = ref.watch(hostGreetingProvider).asData?.value.appName;
    // Every DateFormat in the app follows the chosen language from here, so
    // no screen has to remember to pass a locale.
    Intl.defaultLocale = localeId.code;
    ThemeData themeFor(Brightness brightness) => buildTiffinTheme(
          appearance.theme,
          brightness,
          motion: appearance.motion,
        );

    return MaterialApp(
      onGenerateTitle: (context) => appName ?? AppText.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: themeFor(Brightness.light),
      darkTheme: themeFor(Brightness.dark),
      themeMode: appearance.mode,
      // English, Hindi, Marathi (CLAUDE.md §13). The device's own saved
      // choice drives this, never the OS locale — see LocaleStore.
      locale: localeId.locale,
      localizationsDelegates: const [
        AppText.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppText.supportedLocales,
      home: const AppGate(),
    );
  }
}

/// Replaces Flutter's grey/yellow error box with something an operator can read
/// and report — the message, and (debug only) where it came from.
class _FriendlyErrorWidget extends StatelessWidget {
  const _FriendlyErrorWidget({required this.details, required this.text});

  final FlutterErrorDetails details;

  /// Looked up once at startup: this can render above MaterialApp, where
  /// there are no localizations to ask.
  final AppText text;

  @override
  Widget build(BuildContext context) {
    // This can be asked to render above MaterialApp — i.e. with no theme at
    // all. A last-resort error screen that itself throws for want of a token
    // would replace a readable message with Flutter's red box, so it falls
    // back to fixed colours rather than asserting.
    final t = context.maybeTokens;
    final background = t?.color.warn ?? const Color(0xFFE8A317);
    final foreground = t?.color.onWarn ?? const Color(0xFF1A1A1A);
    final labelStyle = (t?.text.label ?? const TextStyle(fontSize: 13))
        .copyWith(color: foreground);
    final bodyStyle = (t?.text.body ?? const TextStyle(fontSize: 16))
        .copyWith(color: foreground);

    return Container(
      color: background,
      padding: const EdgeInsets.all(NbSpace.md),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bug_report, color: foreground, size: 40),
            const SizedBox(height: NbSpace.sm),
            Text(text.crashTitle,
                textAlign: TextAlign.center, style: labelStyle),
            const SizedBox(height: NbSpace.xs),
            Text(
              kReleaseMode ? text.crashBody : '${details.exception}',
              textAlign: TextAlign.center,
              style: bodyStyle,
            ),
          ],
        ),
      ),
    );
  }
}
