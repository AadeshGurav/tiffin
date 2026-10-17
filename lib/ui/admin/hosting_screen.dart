import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/providers.dart';
import '../../discovery/hotspot.dart';
import '../shared_widgets/copyable_url.dart';
import '../shared_widgets/ios_host_advisory.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_surface.dart';
import '../shared_widgets/nb_feedback.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';

/// Admin ▸ Hosting — the LAN server controls that used to live on a pre-login
/// console. Start/stop serving, see the URLs other devices use, and generate
/// the optional desktop-browser TLS certificate. Host mode only.
class HostingScreen extends ConsumerWidget {
  const HostingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final serving = ref.watch(hostServingProvider);
    final ctrl = ref.read(hostServingProvider.notifier);
    final running = serving.running;
    final server = running ? ref.watch(hostServerProvider) : null;

    return Scaffold(
      appBar: AppBar(title: Text(AppText.of(context).hostingScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(NbSpace.lg),
        children: [
          if (Platform.isIOS) ...[
            const IosHostAdvisory(),
            const SizedBox(height: NbSpace.md),
          ],

          // Status + start/stop -------------------------------------------
          NbSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(running ? Icons.check_circle : Icons.circle_outlined,
                        color: running ? t.color.accept : t.color.ink),
                    const SizedBox(width: NbSpace.sm),
                    Text(
                        running
                            ? AppText.of(context).hostingScreenServingOn
                            : AppText.of(context).hostingScreenNotServing,
                        style: t.text.heading),
                  ],
                ),
                if (running && server != null) ...[
                  const SizedBox(height: NbSpace.sm),
                  Text(
                    server.httpsPort != null
                        ? AppText.of(context).hostingScreenPortWithHttps(
                            server.httpPort!, server.httpsPort!)
                        : AppText.of(context)
                            .hostingScreenPortHttpOnly(server.httpPort!),
                    style: t.text.body,
                  ),
                ],
                if (!serving.discoveryOk) ...[
                  const SizedBox(height: NbSpace.sm),
                  Text(
                    AppText.of(context).hostingScreenAutoDiscoveryOff,
                    style: t.text.body.copyWith(color: t.color.reject),
                  ),
                ],
                if (serving.lastError != null) ...[
                  const SizedBox(height: NbSpace.sm),
                  Text(serving.lastError!,
                      style: t.text.body.copyWith(color: t.color.reject)),
                ],
                const SizedBox(height: NbSpace.md),
                if (!running)
                  NbButton(
                    label: AppText.of(context).hostingScreenStartServing,
                    icon: Icons.play_arrow,
                    busy: serving.busy,
                    onPressed: serving.busy ? null : ctrl.start,
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: NbButton(
                          label: AppText.of(context).hostingScreenStop,
                          icon: Icons.stop,
                          background: t.color.reject,
                          foreground: t.color.onReject,
                          busy: serving.busy,
                          onPressed: serving.busy ? null : ctrl.stop,
                        ),
                      ),
                      const SizedBox(width: NbSpace.sm),
                      Expanded(
                        child: NbButton.secondary(
                          label: AppText.of(context).hostingScreenRestart,
                          icon: Icons.refresh,
                          busy: serving.busy,
                          onPressed: serving.busy ? null : ctrl.restart,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: NbSpace.md),

          // LAN URLs -----------------------------------------------------
          if (running)
            ref.watch(lanUrlsProvider).maybeWhen(
                  data: (urls) => NbSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppText.of(context).hostingScreenDesktopAdminLabel,
                            style: t.text.label),
                        const SizedBox(height: NbSpace.xs),
                        if (urls.http.isEmpty)
                          Text(AppText.of(context).hostingScreenNoLanAddress,
                              style: t.text.body)
                        else ...[
                          Text(
                              AppText.of(context).hostingScreenOpenInBrowser,
                              style: t.text.body),
                          for (final u in urls.http) CopyableUrl(url: u),
                          if (urls.https.isNotEmpty) ...[
                            const SizedBox(height: NbSpace.xs),
                            Text(
                                AppText.of(context)
                                    .hostingScreenEncryptedWarning,
                                style: t.text.label),
                            for (final u in urls.https) CopyableUrl(url: u),
                          ],
                        ],
                      ],
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
          if (running) const SizedBox(height: NbSpace.md),

          // Offline hotspot (Android) ----------------------------------
          if (ref.watch(hotspotProvider).supported) ...[
            const _HotspotCard(),
            const SizedBox(height: NbSpace.md),
          ],

          // Keep awake -------------------------------------------------
          NbSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppText.of(context).hostingScreenKeepAwakeLabel,
                    style: t.text.label),
                const SizedBox(height: NbSpace.xs),
                Text(
                  Platform.isIOS
                      ? AppText.of(context).hostingScreenKeepAwakeIos
                      : AppText.of(context).hostingScreenKeepAwakeAndroid,
                  style: t.text.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: NbSpace.md),

          // TLS cert -------------------------------------------------
          NbSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppText.of(context).hostingScreenTlsLabel,
                    style: t.text.label),
                const SizedBox(height: NbSpace.xs),
                Text(
                  AppText.of(context).hostingScreenTlsDescription,
                  style: t.text.body,
                ),
                if (serving.certExpiry != null) ...[
                  const SizedBox(height: NbSpace.xs),
                  Text(
                      AppText.of(context).hostingScreenCertExpiry(
                          serving.certExpiry.toString()),
                      style: t.text.body),
                ],
                const SizedBox(height: NbSpace.md),
                NbButton.secondary(
                  label: AppText.of(context).hostingScreenGenerateCertificate,
                  busy: serving.busy,
                  onPressed: serving.busy ? null : ctrl.generateCert,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Serve without Wi-Fi" — the host device broadcasts its own network via
/// Android's local-only hotspot. Other phones join it (SSID + passphrase, or
/// the QR) and reach the host at 192.168.49.1.
class _HotspotCard extends ConsumerWidget {
  const _HotspotCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final hs = ref.watch(hotspotProvider);
    final ctrl = ref.read(hotspotProvider.notifier);
    final info = hs.info;

    return NbSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppText.of(context).hostingScreenHotspotLabel,
              style: t.text.label),
          const SizedBox(height: NbSpace.xs),
          if (info == null) ...[
            Text(
              AppText.of(context).hostingScreenHotspotDescription,
              style: t.text.body,
            ),
            if (hs.error != null) ...[
              const SizedBox(height: NbSpace.xs),
              Text(hs.error!,
                  style: t.text.body.copyWith(color: t.color.reject)),
            ],
            const SizedBox(height: NbSpace.md),
            NbButton.secondary(
              label: AppText.of(context).hostingScreenStartHotspot,
              icon: Icons.wifi_tethering,
              busy: hs.busy,
              onPressed: hs.busy
                  ? null
                  : () async {
                      await ctrl.start();
                      ref.invalidate(lanUrlsProvider);
                    },
            ),
          ] else ...[
            _kv(context, AppText.of(context).hostingScreenNetworkLabel,
                info.ssid),
            _kv(context, AppText.of(context).hostingScreenPasswordLabel,
                info.passphrase),
            _kv(context, AppText.of(context).hostingScreenHostAddressLabel,
                '${info.host}:8710'),
            const SizedBox(height: NbSpace.sm),
            Text(
                AppText.of(context)
                    .hostingScreenOtherPhonesJoin('192.168.49.1'),
                style: t.text.body),
            const SizedBox(height: NbSpace.sm),
            Center(
              child: Container(
                padding: const EdgeInsets.all(NbSpace.sm),
                color: t.color.surface,
                child: QrImageView(
                  data: info.joinQr,
                  size: 180,
                  backgroundColor: t.color.surface,
                ),
              ),
            ),
            const SizedBox(height: NbSpace.md),
            NbButton(
              label: AppText.of(context).hostingScreenStopHotspot,
              icon: Icons.stop,
              background: t.color.reject,
              foreground: t.color.onReject,
              busy: hs.busy,
              onPressed: hs.busy ? null : ctrl.stop,
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final t = context.tokens;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: NbSpace.xs),
        child: Row(
          children: [
            SizedBox(width: 120, child: Text(k, style: t.text.label)),
            Expanded(
              child: InkWell(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: v));
                  if (context.mounted) {
                    showNbSnack(
                        context, AppText.of(context).hostingScreenCopiedSnack(v));
                  }
                },
                child: Text(v,
                    style: t.text.body.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ));
  }
}
