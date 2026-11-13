#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Abhisht Kohli
#
# Builds/installs a driver for the HP LaserJet M1005 MFP on modern macOS.
# This repository ships no Apple/HP binaries: legacy-cups mode downloads
# Apple's HP 5.1.1 update from Apple's CDN at runtime. native-ipp mode builds
# upstream GPL-2.0-or-later components (foo2xqx); see README.md.
# ==============================================================================
# HP LaserJet M1005 MFP — macOS Driver Builder & Installer
# ==============================================================================
# Target Hardware:
#   Model:          HP LaserJet M1005 Multifunction Printer
#   USB Vendor ID:  0x03f0 (Hewlett-Packard)
#   USB Product ID: 0x3b17 (HP LaserJet M1005)
#   Protocol:       Host-based XQX / ZjStream raster over USB Printer Class
#                   (Interface 1, Bulk OUT endpoint 0x02, Bulk IN 0x82)
#
# Supported macOS Versions:
#   macOS 12 Monterey, 13 Ventura, 14 Sonoma, 15 Sequoia, and 26 Tahoe+
#   (Intel x86_64 and Apple Silicon M1/M2/M3/M4 arm64)
#
# Why a Custom Builder/Installer is Required:
#   The HP LaserJet M1005 MFP is a host-based printer that lacks native PCL,
#   PostScript, or AirPrint support. Apple's final official HP driver bundle
#   (HP 5.1.1 Printer Software Update: https://support.apple.com/en-us/106385)
#   contains working user-space CUPS filters (hplaserjetzjs.bundle) and the
#   HP LaserJet M1005 PPD (v1.6.1), but its installer Distribution XML blocks
#   Apple Silicon (hostArchitectures="x86_64") and any macOS version > 15.0.
#
# Two Driver Modes Provided by This Script:
#   1. --mode legacy-cups (Default, Fast Setup)
#      Downloads Apple's official HewlettPackardPrinterDrivers.dmg from Apple's
#      CDN, extracts the user-space HP ZJS/XQX CUPS filters and M1005 PPD
#      directly into /Library/Printers/ (or builds a patched .pkg with the
#      macOS 15.0 cap and x86_64 lock removed), ensures Rosetta 2 is present on
#      Apple Silicon, and registers the USB printer queue in CUPS.
#      References:
#        - https://support.apple.com/en-us/106385
#        - https://gist.github.com/szhu/afd806ec1eb874848e1b4f412be7aaaf
#        - https://github.com/faradayfury/hp-printer-drivers-apple-silicon-patch
#        - https://github.com/edla/hp-laserjet-zjs-macos
#
#   2. --mode native-ipp (Modern Native arm64 IPP Everywhere Printer App)
#      Builds the open-source native arm64 user-space Printer Application using
#      PAPPL v1.4.11, OpenPrinting's isolated foo2xqx/JBIG encoder (C11), and
#      libusb transport for 03f0:3b17. Exposes the M1005 to macOS as a modern
#      driverless IPP Everywhere printer (A4, 600x600 dpi, tonal monochrome)
#      without requiring Rosetta 2 or deprecated CUPS PPD filters.
#      References:
#        - https://github.com/SKD-Innovations/hp-m1005-mfp-driver-mac-os
#        - https://medium.com/@sarthakg043/keeping-good-hardware-alive-building-a-modern-macos-driver-for-the-hp-laserjet-m1005-mfp-418b00c6f556
#
# Note on Scanning:
#   Both modes enable printing over USB Interface 1. Scanning over USB
#   Interface 0 (vendor-specific) is not supported by Apple's legacy ZJS bundle
#   and requires SANE (sane-backends hpljm1005) or VueScan on modern macOS.
# ==============================================================================

set -euo pipefail

APPLE_HP_DMG_URL="https://updates.cdn-apple.com/2021/macos/071-46903-20211101-0BD2764A-901C-41BA-9573-C17B8FDC4D90/HewlettPackardPrinterDrivers.dmg"
NATIVE_DRIVER_REPO="https://github.com/SKD-Innovations/hp-m1005-mfp-driver-mac-os.git"
PAPPL_REPO="https://github.com/michaelrsweet/pappl.git"
PAPPL_TAG="v1.4.11"

MODE="legacy-cups"
CUSTOM_DMG_PATH=""
BUILD_DIR="${HOME}/hp-m1005-macos-driver-build"
QUEUE_NAME="HP_LaserJet_M1005_MFP"
PATCH_PKG_ONLY=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --mode <legacy-cups|native-ipp>
      legacy-cups : (Default) Extracts & installs Apple/HP user-space CUPS
                    filters and M1005 PPD from Apple's official HP 5.1.1 bundle
                    (requires Rosetta 2 on Apple Silicon).
      native-ipp  : Clones and compiles the native arm64 PAPPL + foo2xqx +
                    libusb IPP Everywhere Printer Application from source.

  --dmg <path>
      Use an existing local HewlettPackardPrinterDrivers.dmg instead of
      downloading the ~560 MB archive from Apple's CDN (legacy-cups mode).

  --patch-pkg-only
      In legacy-cups mode, generate HewlettPackardPrinterDrivers-patched.pkg
      in the current directory (with hostArchitectures="x86_64,arm64" and the
      macOS 15.0 InstallationCheck cap removed) without auto-installing.

  --build-dir <dir>
      Working directory for source builds (default: ~/hp-m1005-macos-driver-build).

  --queue-name <name>
      CUPS printer queue name to register (default: HP_LaserJet_M1005_MFP).

  -h, --help
      Show this help message and exit.
EOF
}

log_info()  { printf "\033[1;34m[INFO]\033[0m  %s\n" "$*"; }
log_ok()    { printf "\033[1;32m[OK]\033[0m    %s\n" "$*"; }
log_warn()  { printf "\033[1;33m[WARN]\033[0m  %s\n" "$*" >&2; }
log_error() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; }

# Parse CLI flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --dmg)
      CUSTOM_DMG_PATH="${2:-}"
      shift 2
      ;;
    --patch-pkg-only)
      PATCH_PKG_ONLY=1
      shift
      ;;
    --build-dir)
      BUILD_DIR="${2:-}"
      shift 2
      ;;
    --queue-name)
      QUEUE_NAME="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  log_error "This script must be run on macOS (Darwin)."
  exit 1
fi

ensure_rosetta() {
  if [[ "$(uname -m)" == "arm64" ]]; then
    log_info "Checking for Rosetta 2 on Apple Silicon..."
    if /usr/bin/pgrep -q oahd; then
      log_ok "Rosetta 2 is active."
    else
      log_warn "Rosetta 2 is required to run HP's x86_64 CUPS filters on Apple Silicon."
      log_info "Installing Rosetta 2 via softwareupdate..."
      sudo softwareupdate --install-rosetta --agree-to-license
      log_ok "Rosetta 2 installed."
    fi
  fi
}

find_m1005_ppd() {
  local ppd_dir="/Library/Printers/PPDs/Contents/Resources"
  local found=""
  if [[ -f "${ppd_dir}/HP LaserJet M1005.gz" ]]; then
    found="${ppd_dir}/HP LaserJet M1005.gz"
  elif [[ -f "${ppd_dir}/en.lproj/HP LaserJet M1005.gz" ]]; then
    found="${ppd_dir}/en.lproj/HP LaserJet M1005.gz"
  else
    found=$(find "${ppd_dir}" -iname "*M1005*.gz" -o -iname "*M1005*.ppd" 2>/dev/null | head -n 1 || true)
  fi
  printf "%s" "$found"
}

configure_cups_queue() {
  local ppd_path="$1"
  log_info "Searching for connected HP LaserJet M1005 MFP via CUPS (lpinfo -v)..."
  local usb_uri
  usb_uri=$(lpinfo -v 2>/dev/null | awk '/usb:\/\/.*(M1005|03f0)/ {print $2; exit}' || true)

  if [[ -z "$usb_uri" ]]; then
    log_warn "HP LaserJet M1005 MFP not currently detected on USB."
    log_info "Plug in the printer via USB and add it in System Settings -> Printers & Scanners,"
    log_info "or run manually once connected:"
    log_info "  lpadmin -p \"${QUEUE_NAME}\" -E -v \"\$(lpinfo -v | awk '/M1005/ {print \$2; exit}')\" -P \"${ppd_path}\""
    return 0
  fi

  log_info "Found printer URI: ${usb_uri}"
  log_info "Registering CUPS queue '${QUEUE_NAME}'..."
  sudo lpadmin -p "${QUEUE_NAME}" -E \
    -v "${usb_uri}" \
    -P "${ppd_path}" \
    -D "HP LaserJet M1005 MFP" \
    -L "Local USB" \
    -o printer-is-shared=false

  sudo cupsenable "${QUEUE_NAME}" || true
  sudo cupsaccept "${QUEUE_NAME}" || true
  log_ok "Printer queue '${QUEUE_NAME}' configured and ready."
}

run_legacy_cups_mode() {
  ensure_rosetta

  local work_dir
  work_dir=$(mktemp -d "${TMPDIR:-/tmp}/hp_m1005_driver.XXXXXX")
  local mount_point="${work_dir}/mount"
  local expanded_dir="${work_dir}/expanded"
  local dmg_file="${work_dir}/HewlettPackardPrinterDrivers.dmg"

  cleanup() {
    if [[ -d "${mount_point}" ]]; then
      hdiutil detach "${mount_point}" -quiet 2>/dev/null || true
    fi
    rm -rf "${work_dir}"
  }
  trap cleanup EXIT

  if [[ -n "${CUSTOM_DMG_PATH}" ]]; then
    if [[ ! -f "${CUSTOM_DMG_PATH}" ]]; then
      log_error "Specified DMG file not found: ${CUSTOM_DMG_PATH}"
      exit 1
    fi
    log_info "Using local DMG: ${CUSTOM_DMG_PATH}"
    dmg_file="${CUSTOM_DMG_PATH}"
  else
    log_info "Downloading official Apple HP 5.1.1 Printer Software Update (~560 MB)..."
    curl -fL --progress-bar -o "${dmg_file}" "${APPLE_HP_DMG_URL}"
    log_ok "Download complete."
  fi

  log_info "Mounting disk image..."
  mkdir -p "${mount_point}"
  hdiutil attach "${dmg_file}" -mountpoint "${mount_point}" -nobrowse -quiet

  local pkg_source="${mount_point}/HewlettPackardPrinterDrivers.pkg"
  if [[ ! -f "${pkg_source}" ]]; then
    log_error "HewlettPackardPrinterDrivers.pkg not found inside mounted DMG."
    exit 1
  fi

  if [[ "${PATCH_PKG_ONLY}" -eq 1 ]]; then
    log_info "Expanding package metadata to patch Distribution XML..."
    pkgutil --expand "${pkg_source}" "${expanded_dir}"

    local dist_file="${expanded_dir}/Distribution"
    log_info "Patching hostArchitectures to allow arm64 and removing macOS 15.0 cap..."
    # 1. Allow Apple Silicon (arm64) alongside Intel (x86_64)
    sed -i '' 's/hostArchitectures="x86_64"/hostArchitectures="x86_64,arm64"/g' "${dist_file}"
    # 2. Bypass InstallationCheck() version limit (> 15.0)
    /usr/bin/python3 - "${dist_file}" <<'PYEOF'
import re, sys
path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    content = f.read()
patched = re.sub(
    r"function\s+InstallationCheck\s*\([^)]*\)\s*\{.*?\n\}",
    "function InstallationCheck(prefix) {\n\treturn true;\n}",
    content,
    flags=re.DOTALL,
)
with open(path, "w", encoding="utf-8") as f:
    f.write(patched)
PYEOF

    local out_pkg="${PWD}/HewlettPackardPrinterDrivers-patched.pkg"
    log_info "Flattening patched package to ${out_pkg}..."
    pkgutil --flatten "${expanded_dir}" "${out_pkg}"
    log_ok "Created patched installer: ${out_pkg}"
    log_info "Install anytime with: sudo installer -pkg \"${out_pkg}\" -target /"
    return 0
  fi

  log_info "Expanding full package payload (this may take a minute)..."
  pkgutil --expand-full "${pkg_source}" "${expanded_dir}"

  local payload_root="${expanded_dir}/HewlettPackardPrinterDrivers.pkg/Payload"
  if [[ ! -d "${payload_root}/Library/Printers/hp" ]]; then
    log_error "Expected payload directory Library/Printers/hp not found."
    exit 1
  fi

  log_info "Installing user-space HP CUPS filters and PPDs into /Library/Printers..."
  if [[ -d "/Library/Printers/hp" ]]; then
    local backup_suffix
    backup_suffix="bak-$(date -u '+%Y%m%d%H%M%S')"
    log_info "Backing up existing /Library/Printers/hp to /Library/Printers/hp.${backup_suffix}..."
    sudo mv "/Library/Printers/hp" "/Library/Printers/hp.${backup_suffix}"
  fi

  sudo mkdir -p "/Library/Printers" "/Library/Printers/PPDs/Contents/Resources"
  sudo cp -R "${payload_root}/Library/Printers/hp" "/Library/Printers/"
  sudo cp -R "${payload_root}/Library/Printers/PPDs/Contents/Resources/"* "/Library/Printers/PPDs/Contents/Resources/"

  log_info "Setting root:wheel ownership and 755 permissions on /Library/Printers/hp..."
  sudo chown -R root:wheel "/Library/Printers/hp"
  sudo chmod -R 755 "/Library/Printers/hp"

  local m1005_ppd
  m1005_ppd=$(find_m1005_ppd)
  if [[ -n "${m1005_ppd}" ]]; then
    log_ok "Verified M1005 PPD at: ${m1005_ppd}"
    configure_cups_queue "${m1005_ppd}"
  else
    log_warn "Could not auto-locate HP LaserJet M1005.gz PPD in /Library/Printers/PPDs/Contents/Resources/."
    log_info "Open System Settings -> Printers & Scanners -> Add Printer -> Select Software -> HP LaserJet M1005."
  fi

  log_ok "HP LaserJet M1005 MFP user-space CUPS driver installation complete!"
}

run_native_ipp_mode() {
  log_info "Preparing native Apple Silicon IPP Everywhere Printer Application build..."

  for cmd in git make clang pkg-config; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log_error "Required build tool '$cmd' not found. Install Xcode Command Line Tools (xcode-select --install) and Homebrew packages (brew install libusb pkg-config)."
      exit 1
    fi
  done

  if ! pkg-config --exists libusb-1.0 2>/dev/null; then
    log_warn "libusb-1.0 not detected via pkg-config."
    if command -v brew >/dev/null 2>&1; then
      log_info "Installing libusb via Homebrew..."
      brew install libusb pkg-config
    else
      log_error "Please install Homebrew and run: brew install libusb pkg-config"
      exit 1
    fi
  fi

  mkdir -p "${BUILD_DIR}"
  if [[ ! -d "${BUILD_DIR}/hp-m1005-mfp-driver-mac-os" ]]; then
    log_info "Cloning SKD-Innovations/hp-m1005-mfp-driver-mac-os into ${BUILD_DIR}..."
    git clone "${NATIVE_DRIVER_REPO}" "${BUILD_DIR}/hp-m1005-mfp-driver-mac-os"
  else
    log_info "Updating existing repository in ${BUILD_DIR}/hp-m1005-mfp-driver-mac-os..."
    git -C "${BUILD_DIR}/hp-m1005-mfp-driver-mac-os" pull --ff-only || true
  fi

  cd "${BUILD_DIR}/hp-m1005-mfp-driver-mac-os"

  if [[ ! -d "external/pappl" ]]; then
    log_info "Bootstrapping pinned PAPPL (${PAPPL_TAG}) into external/pappl..."
    mkdir -p external
    git clone --branch "${PAPPL_TAG}" --depth 1 "${PAPPL_REPO}" external/pappl
  fi

  log_info "Building Phase 1 & Phase 2 (isolated C11 foo2xqx/JBIG encoder & USB transport)..."
  make all
  make validate
  make phase2-test

  log_info "Building Phase 3 & Phase 4 (PAPPL IPP Everywhere service & reliable USB state machine)..."
  make phase3
  make phase4

  log_info "Building Phase 5 macOS application bundle and unsigned installer package..."
  make phase5-package

  log_ok "Native build complete in: ${BUILD_DIR}/hp-m1005-mfp-driver-mac-os/build"
  log_info "Built artifacts:"
  log_info "  - Standalone XQX encoder : build/m1005-xqx-encode"
  log_info "  - IPP Printer App server : build/m1005-printer-app"
  log_info "  - macOS Menu Bar App     : build/M1005Printer.app"
  log_info ""
  log_info "To start the local IPP Everywhere service manually on port 8000:"
  log_info "  ${BUILD_DIR}/hp-m1005-mfp-driver-mac-os/build/m1005-printer-app server -o server-port=8000 -o log-level=info"
  log_info "Then inspect http://localhost:8000/ or add the advertised Bonjour IPP printer in System Settings -> Printers & Scanners."
}

case "${MODE}" in
  legacy-cups)
    run_legacy_cups_mode
    ;;
  native-ipp)
    run_native_ipp_mode
    ;;
  *)
    log_error "Invalid --mode '${MODE}'. Must be 'legacy-cups' or 'native-ipp'."
    usage
    exit 1
    ;;
esac