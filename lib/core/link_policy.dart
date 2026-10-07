enum QrAction { web, email, telephone, none }

class LinkDecision {
  const LinkDecision(this.action, this.uri);
  final QrAction action;
  final Uri? uri;
  bool get canOpen => action != QrAction.none && uri != null;
  String? get hostname => action == QrAction.web ? uri?.host : null;
  /// True for localhost, IP addresses and `.local` names: these reach devices on the
  /// user's own network (routers, printers) rather than a public website.
  bool get targetsLocalNetwork => LinkPolicy.isLocalHost(hostname);
}

class LinkPolicy {
  /// Hosts must be plain ASCII hostnames. Percent-escapes, non-ASCII look-alike letters,
  /// whitespace and invisible direction controls can disguise the real destination.
  static final _plainHost = RegExp(r'^[A-Za-z0-9._-]+$|^[0-9A-Fa-f:.]*:[0-9A-Fa-f:.]*$');

  static bool isLocalHost(String? host) {
    if (host == null) return false;
    final h = host.toLowerCase().replaceAll(RegExp(r'\.$'), '');
    return h == 'localhost' || h.endsWith('.localhost') || h.endsWith('.local') || h.endsWith('.internal') || !h.contains('.') && !h.contains(':') ||
      RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(h) || h.contains(':');
  }

  static LinkDecision inspect(String payload) {
    final value = payload.trim();
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return const LinkDecision(QrAction.none, null);
    switch (uri.scheme.toLowerCase()) {
      case 'http':
      case 'https':
        if (uri.host.isEmpty || uri.userInfo.isNotEmpty || !_plainHost.hasMatch(uri.host)) return const LinkDecision(QrAction.none, null);
        return LinkDecision(QrAction.web, uri);
      case 'mailto':
        // One or more plain addresses; anything else is shown as text.
        final addresses = Uri.decodeComponent(uri.path).split(',');
        final valid = addresses.every((a) => RegExp(r'^[^@\s<>]+@[^@\s<>]+\.[^@\s<>]+$').hasMatch(a.trim()));
        return valid ? LinkDecision(QrAction.email, uri) : const LinkDecision(QrAction.none, null);
      case 'tel':
        // Uri percent-encodes spaces, so validate the decoded number and dial it without separators.
        final number = Uri.decodeComponent(uri.path);
        return RegExp(r'^\+?[0-9(). -]{3,30}$').hasMatch(number)
          ? LinkDecision(QrAction.telephone, Uri(scheme: 'tel', path: number.replaceAll(RegExp(r'[(). -]'), ''))) : const LinkDecision(QrAction.none, null);
      default:
        return const LinkDecision(QrAction.none, null);
    }
  }
}
