import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:tiffin/discovery/discovery.dart';

/// Discovery once handed the UI the mDNS hostname (`service.host`, e.g.
/// `iPhone.local`), which `dart:io` cannot resolve — so a discovered host
/// failed at login as "offline". These lock in that a real IP is chosen.
void main() {
  nsd.Service svc(List<InternetAddress>? addresses, {String? host}) =>
      nsd.Service(
        name: 'Canteen',
        type: '_tiffin._tcp',
        host: host,
        port: 8710,
        addresses: addresses,
      );

  test('prefers a routable IPv4 over the .local hostname', () {
    final s = svc([InternetAddress('192.168.1.42')], host: 'iPhone.local');
    expect(HostBrowser.dialableAddress(s), '192.168.1.42');
  });

  test('never returns a .local hostname, even with no addresses', () {
    expect(
        HostBrowser.dialableAddress(svc(null, host: 'iPhone.local')), isNull);
    expect(
        HostBrowser.dialableAddress(svc(const [], host: 'host.local')), isNull);
  });

  test('accepts a bare IP literal in host when there are no addresses', () {
    expect(
        HostBrowser.dialableAddress(svc(null, host: '10.0.0.5')), '10.0.0.5');
  });

  test('skips loopback and link-local, falls through to a real address', () {
    final s = svc([
      InternetAddress('127.0.0.1'),
      InternetAddress('169.254.10.20'),
      InternetAddress('192.168.0.7'),
    ]);
    expect(HostBrowser.dialableAddress(s), '192.168.0.7');
  });

  test('uses IPv6 only when no usable IPv4 is present', () {
    final s = svc([
      InternetAddress('127.0.0.1'),
      InternetAddress('fd00::1234', type: InternetAddressType.IPv6),
    ]);
    expect(HostBrowser.dialableAddress(s), 'fd00::1234');
  });

  test('baseUrl brackets an IPv6 literal', () {
    const h = DiscoveredHost(name: 'x', host: 'fd00::1', port: 8710);
    expect(h.baseUrl, 'http://[fd00::1]:8710');
    const v4 = DiscoveredHost(name: 'x', host: '192.168.1.1', port: 8710);
    expect(v4.baseUrl, 'http://192.168.1.1:8710');
  });
}
