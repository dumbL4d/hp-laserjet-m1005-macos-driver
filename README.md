# HP LaserJet M1005 MFP — macOS Driver Builder & Installer

A single shell script that brings the **HP LaserJet M1005 MFP** (USB `03f0:3b17`)
back to life on modern macOS — Monterey 12 through Sequoia 15 and macOS 26
Tahoe — on both **Intel** and **Apple Silicon**.

HP never shipped a 64-bit-native, Apple Silicon-friendly driver for this
host-based (XQX / ZjStream) printer, and Apple's final official HP bundle is
hard-capped to macOS ≤ 15.0 and `x86_64`. This project provides two independent
ways to print again:

| Mode | What it does | Rosetta 2 | Status |
| --- | --- | --- | --- |
| `legacy-cups` *(default)* | Downloads Apple's official HP 5.1.1 Printer Software Update, extracts the user-space ZJS/XQX CUPS filter and the M1005 PPD, installs them into `/Library/Printers`, and registers the USB queue. | Required on Apple Silicon | Stable |
| `native-ipp` | Builds an open-source arm64 **PAPPL + foo2xqx + libusb** IPP Everywhere Printer Application from source. No Rosetta, no deprecated PPD filters. | Not required | Builds from source |

Scanning is **not** covered by either mode. USB scanning on this unit needs
SANE (`sane-backends`, `hpljm1005` backend) or a commercial option such as
VueScan.

> **This repository contains no binaries.** The script downloads Apple's
> installer directly from Apple's CDN on the machine that runs it. Nothing
> proprietary from HP or Apple is redistributed here.

---

## Requirements

- macOS 12 Monterey or newer (Intel `x86_64` or Apple Silicon `arm64`)
- An HP LaserJet M1005 / M1005 MFP connected over USB
- **`legacy-cups`**: ~1 GB free disk space, network access, and Rosetta 2 on
  Apple Silicon (the script offers to install it)
- **`native-ipp`**: Xcode Command Line Tools and Homebrew
  (`xcode-select --install`, then `brew install libusb pkg-config`)

---

## Usage

```bash
git clone https://github.com/dumbL4d/hp-laserjet-m1005-macos-driver.git
cd hp-laserjet-m1005-macos-driver
chmod +x build_hp_m1005_macos_driver.sh

# Default: extract Apple's official HP 5.1.1 filters + PPD and add the queue
./build_hp_m1005_macos_driver.sh

# Or: build the native arm64 IPP Everywhere Printer Application
./build_hp_m1005_macos_driver.sh --mode native-ipp
```

### Options

| Flag | Description |
| --- | --- |
| `--mode <legacy-cups\|native-ipp>` | Select the driver strategy. Default: `legacy-cups`. |
| `--dmg <path>` | Use an already-downloaded `HewlettPackardPrinterDrivers.dmg` instead of fetching the ~560 MB file from Apple. |
| `--patch-pkg-only` | Only produce `HewlettPackardPrinterDrivers-patched.pkg` (arm64 + macOS 15 cap removed) in the current directory; installs nothing. |
| `--build-dir <dir>` | Working directory for source builds. Default: `~/hp-m1005-macos-driver-build`. |
| `--queue-name <name>` | CUPS queue name. Default: `HP_LaserJet_M1005_MFP`. |
| `-h`, `--help` | Show help. |

### Examples

```bash
# Build a patched Apple installer to run manually later
./build_hp_m1005_macos_driver.sh --patch-pkg-only

# Install from a DMG you already have (offline / metered connection)
./build_hp_m1005_macos_driver.sh --dmg ~/Downloads/HewlettPackardPrinterDrivers.dmg

# Native build, custom queue name
./build_hp_m1005_macos_driver.sh --mode native-ipp --queue-name Office_M1005
```

After the native build, start the Printer Application manually:

```bash
~/hp-m1005-macos-driver-build/hp-m1005-mfp-driver-mac-os/build/m1005-printer-app \
  server -o server-port=8000 -o log-level=info
```

Then open <http://localhost:8000/> or add the advertised Bonjour IPP printer in
**System Settings → Printers & Scanners**.

---

## How it works

### `legacy-cups` (default)

1. Checks for Rosetta 2 on Apple Silicon and installs it if needed.
2. Downloads `HewlettPackardPrinterDrivers.dmg` (HP 5.1.1 Printer Software
   Update) from `updates.cdn-apple.com`.
3. Mounts the DMG and expands the `.pkg` payload.
4. Backs up any existing `/Library/Printers/hp` to
   `/Library/Printers/hp.bak-<timestamp>`.
5. Copies the user-space HP filter bundle and PPDs into `/Library/Printers`,
   fixing ownership to `root:wheel` and permissions to `755`.
6. Finds `HP LaserJet M1005.gz`, discovers the USB URI via `lpinfo -v`, and
   registers the queue with `lpadmin`.

With `--patch-pkg-only` the script instead rewrites the installer's
`Distribution` XML (`hostArchitectures="x86_64,arm64"` and
`InstallationCheck()` forced to `true`) and flattens a patched `.pkg` — useful
if you prefer Apple's installer flow.

### `native-ipp`

Clones [`SKD-Innovations/hp-m1005-mfp-driver-mac-os`][skd], bootstraps a pinned
**PAPPL v1.4.11**, builds the C11 XQX/JBIG encoder and libusb transport, then
produces the PAPPL Printer Application and an unsigned macOS menu-bar app.
Printing is exposed as a driverless IPP Everywhere queue (A4, 600×600 dpi,
monochrome), with no Rosetta dependency and no deprecated CUPS PPD filters.

---

## Legal, licensing, and attribution

### License

This project's shell script, documentation, and other original files are
released under the [MIT License](LICENSE).

### No bundled proprietary software

This repository intentionally ships **no** Apple or HP binaries. `*.dmg`,
`*.pkg`, `*.mpkg`, extracted `/Library/Printers/hp` payloads, and build output
are ignored via [`.gitignore`](.gitignore). The legacy mode always downloads
the HP 5.1.1 Printer Software Update directly from Apple's CDN at runtime, so
each user obtains Apple/HP software from Apple under Apple's own terms. If you
use `--dmg`, you are responsible for having obtained that file lawfully.

### Upstream and community attribution

This work stands on the shoulders of earlier community efforts:

- [szhu's legacy HP installer gist](https://gist.github.com/szhu/afd806ec1eb874848e1b4f412be7aaaf)
  — original approach for installing Apple's legacy HP drivers on modern macOS.
- [edla/hp-laserjet-zjs-macos](https://github.com/edla/hp-laserjet-zjs-macos) —
  ZJS/XQX driver packaging and legal structure (download, never redistribute).
- [SKD-Innovations/hp-m1005-mfp-driver-mac-os][skd] — native PAPPL/foo2xqx
  Printer Application for the M1005 (the `native-ipp` build target).
- [faradayfury/hp-printer-drivers-apple-silicon-patch](https://github.com/faradayfury/hp-printer-drivers-apple-silicon-patch)
  — patching of the `Distribution` XML for arm64 and newer macOS releases.
- [michaelrsweet/pappl](https://github.com/michaelrsweet/pappl) — PAPPL,
  pinned to `v1.4.11`.
- Apple's [HP 5.1.1 Printer Software Update](https://support.apple.com/en-us/106385)
  — the upstream legacy filters and PPDs, downloaded at runtime.

### GPL notice for `--mode native-ipp`

The `native-ipp` mode builds a Printer Application that includes **foo2xqx**
(from the foo2zjs project), which is licensed under **GPL-2.0-or-later**. Any
binaries produced by that build are therefore subject to the GPL, not the MIT
license that covers this repository's original code. Source for the GPL
components is fetched from their upstream repositories at build time; if you
distribute a compiled artifact, you must comply with the GPL (including
offering the corresponding source).

---

## Disclaimer

This project is **unofficial** and is provided **"as-is"**, without warranty of
any kind, express or implied, including but not limited to the warranties of
merchantability, fitness for a particular purpose, and non-infringement.

It is **not affiliated with, authorized, sponsored, or endorsed by Apple Inc.
or HP Inc.** "Apple", "macOS", "HP", "LaserJet", and related marks are the
property of their respective owners and are used here only for descriptive,
interoperability purposes.

You run this software at your own risk. It writes to `/Library/Printers` and
uses `sudo`, and it may modify printer queues. Back up your system and review
the script before running it.

---

## Uninstall

```bash
# Remove the CUPS queue
sudo lpadmin -x HP_LaserJet_M1005_MFP

# Remove the legacy filters/PPDs (and any timestamped backup)
sudo rm -rf /Library/Printers/hp /Library/Printers/hp.bak-*

# Remove build artifacts
rm -rf ~/hp-m1005-macos-driver-build
```

## Contributing

Issues and pull requests are welcome. Please do not attach `.dmg`, `.pkg`, or
extracted vendor binaries to issues or PRs — link to the vendor source instead.

[skd]: https://github.com/SKD-Innovations/hp-m1005-mfp-driver-mac-os
