# Security Policy

## Supported versions

Only the latest commit on `main` is supported. This project is a shell script
and does not maintain release branches.

## Reporting a vulnerability

Please **do not open a public issue** for security problems.

Use GitHub's private vulnerability reporting:
<https://github.com/dumbL4d/hp-laserjet-m1005-macos-driver/security/advisories/new>

Include:

- Affected commit / version of the script
- macOS version and architecture
- Steps to reproduce
- Impact (e.g. command injection, unsafe `sudo` handling, path traversal in
  DMG payload extraction)

You can expect an initial response within 7 days. Please allow time for a fix
before public disclosure.

## Scope notes

- The script downloads a DMG from `updates.cdn-apple.com` and expands it with
  `pkgutil`. A compromised upstream file is an Apple supply-chain issue, but
  report it here if the script handles it unsafely.
- Reports about the proprietary Apple/HP binaries themselves should go to
  Apple or HP.
