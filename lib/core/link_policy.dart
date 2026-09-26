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
        return uri.path.isEmpty ? const LinkDecision(QrAction.none, null) : LinkDecision(QrAction.email, uri);
      case 'tel':
        return RegExp(r'^\+?[0-9(). -]{3,30}$').hasMatch(uri.path)
          ? LinkDecision(QrAction.telephone, uri) : const LinkDecision(QrAction.none, null);
      default:
        return const LinkDecision(QrAction.none, null);
    }
  }
}
