(function expose(root, factory) {
  const policy = factory();
  if (typeof module === 'object' && module.exports) module.exports = policy;
  else root.ScanOpenLinkPolicy = policy;
})(typeof globalThis === 'object' ? globalThis : this, function createPolicy() {
  function allowedAction(raw) {
    let decoded;
    try { decoded = decodeURIComponent(raw); } catch { return null; }
    if ([...raw, ...decoded].some(char => char.charCodeAt(0) < 32 || char.charCodeAt(0) === 127)) return null;
    let url;
    try { url = new URL(raw); } catch { return null; }
    const scheme = url.protocol.toLowerCase();
    if ((scheme === 'http:' || scheme === 'https:') && url.hostname && !url.username && !url.password) {
      return {url, host: url.hostname};
    }
    if (scheme === 'mailto:' && /^[^@\s,;]+@[^@\s,;]+$/.test(decodeURIComponent(url.pathname))) {
      return {url, host: 'Email'};
    }
    if (scheme === 'tel:' && /^\+?[0-9(). -]{3,30}$/.test(url.pathname)) {
      return {url, host: 'Telephone'};
    }
    return null;
  }
  return {allowedAction};
});
