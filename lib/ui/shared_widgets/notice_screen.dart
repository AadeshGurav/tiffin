import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_logo.dart';
import 'nb_surface.dart';

/// A full screen that explains a state and, optionally, offers one way out.
/// For the moments where the honest answer is "nothing to do here yet".
class NoticeScreen extends StatelessWidget {
  const NoticeScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

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
                  const Center(child: AppWordmark()),
                  const SizedBox(height: NbSpace.lg),
                  NbSurface(
                    intensity: NbIntensity.full,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 40, color: t.color.ink),
                        const SizedBox(height: NbSpace.sm),
                        Text(title, style: t.text.heading),
                        const SizedBox(height: NbSpace.xs),
                        Text(body, style: t.text.body),
                        for (final a in actions) ...[
                          const SizedBox(height: NbSpace.md),
                          a,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
