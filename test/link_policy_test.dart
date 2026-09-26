import 'package:flutter_test/flutter_test.dart';
import 'package:scan_and_open/core/link_policy.dart';

void main() {
  group('LinkPolicy', () {
    test('allows only explicit supported external actions', () {
      expect(LinkPolicy.inspect('https://example.com/a').action, QrAction.web);
      expect(LinkPolicy.inspect('http://example.com').hostname, 'example.com');
      expect(LinkPolicy.inspect('mailto:person@example.com').action, QrAction.email);
      expect(LinkPolicy.inspect('tel:+66 123 456').action, QrAction.telephone);
      expect(LinkPolicy.inspect('tel:+66 123 456').uri.toString(), 'tel:+66123456');
    });
    test('never opens executable or arbitrary schemes', () {
      for (final value in ['javascript:alert(1)', 'data:text/html,test', 'file:///secret', 'intent://x', 'myapp://x', 'plain text']) {
        expect(LinkPolicy.inspect(value).canOpen, isFalse, reason: value);
      }
    });
    test('rejects malformed email and phone payloads', () {
      for (final value in ['mailto:', 'mailto:not-an-address', 'tel:call-me', 'tel:12', 'https://', 'http:///path']) {
        expect(LinkPolicy.inspect(value).canOpen, isFalse, reason: value);
      }
      expect(LinkPolicy.inspect('mailto:a@example.com?subject=Hi').canOpen, isTrue);
    });
    test('scheme matching is case-insensitive but still allowlisted', () {
      expect(LinkPolicy.inspect('HTTPS://Example.com').action, QrAction.web);
      expect(LinkPolicy.inspect('JavaScript:alert(1)').canOpen, isFalse);
      expect(LinkPolicy.inspect('  https://example.com  ').hostname, 'example.com');
    });
    test('never invents app schemes from domains', () {
      expect(LinkPolicy.inspect('https://www.youtube.com/watch?v=x').uri!.scheme, 'https');
    });
    test('rejects misleading URL user information', () {
      expect(LinkPolicy.inspect('https://trusted.example@evil.example').canOpen, isFalse);
    });
  });
}
