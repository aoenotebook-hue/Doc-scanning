# Security policy

## Reporting a vulnerability

Do not open a public issue containing document images, QR payloads, exported files,
credentials, or exploit details. Use the repository's private vulnerability-reporting
feature (**Security → Advisories → Report a vulnerability**). Include the affected commit,
platform and OS version, reproduction steps using non-sensitive sample data, and impact.

No production backend receives app content, so there is no support reason to attach a real
document or QR destination. Maintainers should acknowledge a report within seven days,
triage supported releases, and coordinate disclosure after a fix is available.

## Security boundaries

* Documents and drafts are private local files; generated exports leave that boundary only
  after an explicit Save As or Share action.
* External QR actions are limited to HTTP(S), `mailto`, and `tel`, are displayed before use,
  and reject control characters, URL user-info, and arbitrary schemes.
* Incoming share providers are untrusted. Android and iOS cap a share at 50 images and each
  copied image at 100 MiB. Native code claims each inbox item once.
* Android disables cleartext networking and OS backup for private app data. iOS backup
  behavior remains governed by the OS/user configuration and is documented in the app.
* CI has read-only repository permissions, does not persist checkout credentials, receives
  no deployment secrets, and publishes an unsigned artifact only. Store signing belongs in
  separately protected environments with required reviewers.

## Release checklist

1. Review Dependabot updates, upstream changelogs, platform support, and package licenses.
2. Run `./tool/verify_release.sh` from a clean checkout.
3. Test the native acceptance checklist on current physical iOS and Android devices.
4. Generate signed artifacts only in protected environments; never commit keys or profiles.
5. Confirm branch protection requires the mobile release check and at least one review.
