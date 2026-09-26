enum QrAction { web, email, telephone, none }

class LinkDecision {
  const LinkDecision(this.action, this.uri);
  final QrAction action;
  final Uri? uri;
  bool get canOpen => action != QrAction.none && uri != null;
  String? get hostname => action == QrAction.web ? uri?.host : null;
}

class LinkPolicy {
  static LinkDecision inspect(String payload) {
    final value = payload.trim();
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return const LinkDecision(QrAction.none, null);
    switch (uri.scheme.toLowerCase()) {
      case 'http':
      case 'https':
        if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return const LinkDecision(QrAction.none, null);
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
