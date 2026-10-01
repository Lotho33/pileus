import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/server_address.dart';

void main() {
  group('parseServerAddressInput — LAN', () {
    test('a private IPv4 (the discovery screens\' own hint text) is LAN', () {
      final p = parseServerAddressInput('192.168.1.10');
      expect(p.remote, isFalse);
      expect(p.host, '192.168.1.10');
      expect(p.port, isNull);
    });

    test('10.0.0.0/8 is LAN', () {
      expect(parseServerAddressInput('10.20.30.40').remote, isFalse);
    });

    test('172.16.0.0/12 is LAN', () {
      expect(parseServerAddressInput('172.16.0.1').remote, isFalse);
      expect(parseServerAddressInput('172.31.255.255').remote, isFalse);
    });

    test('172.32.x.x is just OUTSIDE 172.16/12 — not LAN', () {
      expect(parseServerAddressInput('172.32.0.1').remote, isTrue);
    });

    test('loopback (127.0.0.1) is LAN', () {
      expect(parseServerAddressInput('127.0.0.1').remote, isFalse);
    });

    test('a private IP with an explicit port ("host:porta") stays LAN, '
        'port parsed out but unused by LAN mode', () {
      final p = parseServerAddressInput('192.168.1.10:50051');
      expect(p.remote, isFalse);
      expect(p.host, '192.168.1.10');
      expect(p.port, 50051);
    });

    test('a bare private IP with a *scheme* is remote — an explicit '
        'http(s):// always wins over the private-range check', () {
      final p = parseServerAddressInput('https://192.168.1.10');
      expect(p.remote, isTrue);
      expect(p.scheme, 'https');
    });
  });

  group('parseServerAddressInput — remote', () {
    test('a public (non-private-range) bare IP is remote', () {
      final p = parseServerAddressInput('8.8.8.8');
      expect(p.remote, isTrue);
      expect(p.host, '8.8.8.8');
    });

    test('a bare domain name (no scheme) is remote, defaulting to https',
        () {
      final p = parseServerAddressInput('media.example.com');
      expect(p.remote, isTrue);
      expect(p.host, 'media.example.com');
      expect(p.scheme, 'https');
      expect(p.port, isNull);
      expect(p.remoteHttpPort, 443);
    });

    test('https://domain is remote on port 443', () {
      final p = parseServerAddressInput('https://media.example.com');
      expect(p.remote, isTrue);
      expect(p.host, 'media.example.com');
      expect(p.scheme, 'https');
      expect(p.port, isNull);
      expect(p.remoteHttpPort, 443);
      expect(p.remoteBaseUrl, 'https://media.example.com');
    });

    test('https://domain:8443 is remote on the explicit port', () {
      final p = parseServerAddressInput('https://media.example.com:8443');
      expect(p.remote, isTrue);
      expect(p.host, 'media.example.com');
      expect(p.port, 8443);
      expect(p.remoteHttpPort, 8443);
      expect(p.remoteBaseUrl, 'https://media.example.com:8443');
    });

    test('http://domain (explicit, non-default scheme) is remote and keeps '
        'http', () {
      final p = parseServerAddressInput('http://media.example.com');
      expect(p.remote, isTrue);
      expect(p.scheme, 'http');
      expect(p.remoteBaseUrl, 'http://media.example.com');
    });

    test('trailing path/query is stripped from the host', () {
      final p =
          parseServerAddressInput('https://media.example.com/pileus/info');
      expect(p.host, 'media.example.com');
    });

    test('surrounding whitespace is trimmed', () {
      final p = parseServerAddressInput('  media.example.com  ');
      expect(p.host, 'media.example.com');
      expect(p.remote, isTrue);
    });

    test('scheme is matched case-insensitively', () {
      final p = parseServerAddressInput('HTTPS://media.example.com');
      expect(p.remote, isTrue);
      expect(p.scheme, 'https');
    });
  });
}
