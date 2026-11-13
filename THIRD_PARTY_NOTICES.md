# Third-Party Notices

This repository contains only original shell-script and documentation code,
licensed under the MIT License (see `LICENSE`). It does **not** contain or
redistribute any Apple Inc. or HP Inc. binaries.

## Downloaded at runtime (not redistributed)

| Component | Source | Terms |
| --- | --- | --- |
| HP 5.1.1 Printer Software Update (`HewlettPackardPrinterDrivers.dmg`) | <https://updates.cdn-apple.com/2021/macos/071-46903-20211101-0BD2764A-901C-41BA-9573-C17B8FDC4D90/HewlettPackardPrinterDrivers.dmg> via [Apple Support 106385](https://support.apple.com/en-us/106385) | Apple's own software license terms; obtained by the end user from Apple |

## Cloned/built from source in `--mode native-ipp`

| Component | Source | Terms |
| --- | --- | --- |
| hp-m1005-mfp-driver-mac-os | <https://github.com/SKD-Innovations/hp-m1005-mfp-driver-mac-os> | See upstream repository |
| PAPPL | <https://github.com/michaelrsweet/pappl> (pinned `v1.4.11`) | See upstream repository |
| foo2xqx (foo2zjs) | Built via the above project | **GPL-2.0-or-later** |

Binaries produced by `--mode native-ipp` include GPL-2.0-or-later code and are
governed by the GPL, not the MIT License. If you redistribute such a binary you
must meet the GPL's source-availability obligations.

## Community work this project builds on

- szhu, legacy HP installer gist —
  <https://gist.github.com/szhu/afd806ec1eb874848e1b4f412be7aaaf>
- edla, hp-laserjet-zjs-macos —
  <https://github.com/edla/hp-laserjet-zjs-macos>
- SKD-Innovations, hp-m1005-mfp-driver-mac-os —
  <https://github.com/SKD-Innovations/hp-m1005-mfp-driver-mac-os>
- faradayfury, hp-printer-drivers-apple-silicon-patch —
  <https://github.com/faradayfury/hp-printer-drivers-apple-silicon-patch>

All trademarks are the property of their respective owners. This project is
not affiliated with or endorsed by Apple Inc. or HP Inc.
