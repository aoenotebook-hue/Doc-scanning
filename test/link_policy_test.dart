import 'package:flutter_test/flutter_test.dart';
import 'package:scan_and_open/core/link_policy.dart';

void main() {
  group('LinkPolicy', () {
    test('allows only explicit supported external actions', () {
      expect(LinkPolicy.inspect('https://example.com/a').action, QrAction.web);
      expect(LinkPolicy.inspect('http://example.com').hostname, 'example.com');
      expect(LinkPolicy.inspect('mailto:person@example.com').action, QrAction.email);
      expect(LinkPolicy.inspect('tel:+66 123 456').action, QrAction.telephone);
    });
    test('never opens executable or arbitrary schemes', () {
      for (final value in ['javascript:alert(1)', 'data:text/html,test', 'file:///secret', 'intent://x', 'myapp://x', 'plain text']) {
        expect(LinkPolicy.inspect(value).canOpen, isFalse, reason: value);
      }
    });
    test('rejects misleading URL user information', () {
      expect(LinkPolicy.inspect('https://trusted.example@evil.example').canOpen, isFalse);
    });
  });
}
