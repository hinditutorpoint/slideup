# Security Policy

## Supported Versions

Only the latest release on the `main` branch is supported with security
updates. Older tags and branches are not patched retroactively.

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in this
project, please do NOT open a public GitHub issue.

Instead, report it privately to the maintainers so it can be fixed before
public disclosure.

### How to report

Email the maintainers at: (add your security contact email here)

Include in your report:

- A clear description of the vulnerability and its impact.
- Steps to reproduce (PoC, sample URL, or screenshots).
- Affected versions/platforms (Android/iOS, app version).
- Any suggested fix, if you have one.

You will receive a response within 7 days. We will work with you to
coordinate a fix and disclosure timeline.

### What to include in a good report

- Where the vulnerability is (screen, module, API, WebView content, etc.).
- Whether it affects the private browser, downloads, storage/vault,
  authentication, or network handling.
- The data or component at risk.

## Security Notes for This Project

- The app contains an incognito browser, file downloads, and an encrypted
  Vault (`.slock`) feature. Treat anything involving these as security
  sensitive.
- Do not commit secrets, API keys, or signing credentials to the repository.
- Report any issue that could lead to data exposure, code execution via
  WebView content, or bypass of the app lock/Vault encryption.

## Responsible Disclosure

We kindly ask that you allow us a reasonable period to fix and release a
patch before publicly disclosing the vulnerability.