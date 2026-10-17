import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/config.dart';
import '../../discovery/discovery.dart';
import '../../l10n/app_localizations.dart';
import '../auth/login_screen.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/nb_surface.dart';
import '../theme/tokens.dart';
import '../shared_widgets/motion.dart';

/// Client mode: pick a host found on the LAN (PRD §13.5) — recognition over
/// recall (CLAUDE.md §11.1 #6). Auto-discovery is the happy path; a manual
/// "connect by IP" fallback covers routers that block mDNS between devices
/// (guest networks, AP isolation) and iOS hosts that never got Local Network
/// permission (CLAUDE.md §4.6 graceful degradation, §11.1 #3 user control).
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  void _connect(BuildContext context, WidgetRef ref, DiscoveredHost host) {
    ref.read(selectedHostProvider.notifier).state = host;
    Navigator.of(context)
        .push(tiffinRoute<void>(context, () => const LoginScreen()));
  }

  Future<void> _enterManually(BuildContext context, WidgetRef ref,
      {String? initialIp}) async {
    final host = await showDialog<DiscoveredHost>(
      context: context,
      builder: (_) => _ManualHostDialog(initialIp: initialIp),
    );
    if (host != null && context.mounted) _connect(context, ref, host);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final hosts = ref.watch(discoveredHostsProvider);
    final lastHost = ref.read(lastHostStoreProvider).read();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppText.of(context).discoverScreenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: AppText.of(context).discoverScreenChangeMode,
            onPressed: () async {
              await ref.read(currentModeProvider.notifier).clear();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(NbSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppText.of(context).discoverScreenSubtitle,
                style: t.text.heading),
            const SizedBox(height: NbSpace.md),
            if (lastHost != null) ...[
              NbButton(
                label:
                    AppText.of(context).discoverScreenReconnect(lastHost.name),
                icon: Icons.history,
                onPressed: () => _connect(context, ref, lastHost),
              ),
              const SizedBox(height: NbSpace.md),
            ],
            Expanded(
              child: AsyncView<List<DiscoveredHost>>(
                value: hosts,
                onRetry: () => ref.invalidate(discoveredHostsProvider),
                builder: (list) {
                  if (list.isEmpty) {
                    return const _Searching();
                  }
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: NbSpace.sm),
                    itemBuilder: (_, i) {
                      final host = list[i];
                      return NbSurface(
                        onTap: () => _connect(context, ref, host),
                        child: Row(
                          children: [
                            Icon(Icons.dns, color: t.color.ink),
                            const SizedBox(width: NbSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(host.name, style: t.text.body),
                                  Text('${host.host}:${host.port}',
                                      style: t.text.label),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: NbSpace.md),
            NbButton.secondary(
              label: AppText.of(context).discoverScreenSearchAgain,
              onPressed: () {
                ref.read(hostBrowserProvider).restart();
                ref.invalidate(discoveredHostsProvider);
              },
            ),
            const SizedBox(height: NbSpace.sm),
            NbButton.secondary(
              label: AppText.of(context).discoverScreenConnectByIp,
              icon: Icons.keyboard,
              onPressed: () => _enterManually(context, ref),
            ),
            const SizedBox(height: NbSpace.sm),
            NbButton.secondary(
              label: AppText.of(context).discoverScreenHostHotspot,
              icon: Icons.wifi_tethering,
              onPressed: () =>
                  _enterManually(context, ref, initialIp: '192.168.49.1'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback when mDNS can't cross the network: type the host's IP (shown on the
/// host device under Admin ▸ Hosting) and port.
class _ManualHostDialog extends StatefulWidget {
  const _ManualHostDialog({this.initialIp});

  final String? initialIp;

  @override
  State<_ManualHostDialog> createState() => _ManualHostDialogState();
}

class _ManualHostDialogState extends State<_ManualHostDialog> {
  late final _ip = TextEditingController(text: widget.initialIp ?? '');
  final _port = TextEditingController(text: '${AppConfig.defaultServerPort}');
  String? _error;

  @override
  void dispose() {
    _ip.dispose();
    _port.dispose();
    super.dispose();
  }

  void _submit() {
    final ip = _ip.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (ip.isEmpty || port == null || port < 1 || port > 65535) {
      setState(() => _error = AppText.of(context).discoverScreenInvalidIpPort);
      return;
    }
    Navigator.of(context).pop(
      DiscoveredHost(
        name: AppText.of(context).discoverScreenHostAtIp(ip),
        host: ip,
        port: port,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AlertDialog(
      title: Text(AppText.of(context).discoverScreenConnectByIpTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ip,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: AppText.of(context).discoverScreenHostIpLabel,
              hintText: AppText.of(context).discoverScreenHostIpHint,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: NbSpace.sm),
          TextField(
            controller: _port,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
                labelText: AppText.of(context).discoverScreenPortLabel),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: NbSpace.sm),
            Text(_error!, style: t.text.label.copyWith(color: t.color.reject)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppText.of(context).discoverScreenCancel),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(AppText.of(context).discoverScreenConnect),
        ),
      ],
    );
  }
}

class _Searching extends StatelessWidget {
  const _Searching();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: t.color.ink),
          const SizedBox(height: NbSpace.md),
          Text(AppText.of(context).discoverScreenSearching, style: t.text.body),
          const SizedBox(height: NbSpace.xs),
          Text(AppText.of(context).discoverScreenSearchingHint,
              textAlign: TextAlign.center, style: t.text.label),
        ],
      ),
    );
  }
}
