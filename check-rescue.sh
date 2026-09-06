#!/usr/bin/env bash
# Is the rescue stick still current?
#
# The stick goes stale when flake.lock moves bcachefs forward. This compares
# what the flake would build now against what the running system has, and
# against a recorded fingerprint of the last ISO you actually wrote.
#
# Usage:
#   ./check-rescue.sh          # report
#   ./check-rescue.sh --record # after dd'ing a fresh stick

set -euo pipefail
cd "$(dirname "$0")"

STAMP=".rescue-stamp"

# Works whether or not flakes are enabled system-wide -- this script has to run
# from the rescue environment too, where nothing is configured yet.
nix_() { command nix --extra-experimental-features 'nix-command flakes' "$@"; }

tools_ver() {
  nix_ eval --raw .#nixosConfigurations.installer.pkgs.bcachefs-tools.version
}
kernel_ver() {
  nix_ eval --raw .#nixosConfigurations.installer.config.boot.kernelPackages.kernel.version
}

now_tools="$(tools_ver)"
now_kernel="$(kernel_ver)"
running_tools="$(bcachefs version 2>/dev/null || echo unknown)"

if [[ "${1:-}" == "--record" ]]; then
  printf '%s %s\n' "$now_tools" "$now_kernel" > "$STAMP"
  echo "Recorded: tools $now_tools, kernel $now_kernel"
  exit 0
fi

echo "flake would build : tools $now_tools, kernel $now_kernel"
echo "running system    : tools $running_tools"

if [[ -f "$STAMP" ]]; then
  read -r iso_tools iso_kernel < "$STAMP"
  echo "stick was written : tools $iso_tools, kernel $iso_kernel"
  if [[ "$iso_tools" != "$now_tools" ]]; then
    echo
    echo ">>> STALE. bcachefs-tools moved $iso_tools -> $now_tools."
    echo ">>> Rebuild before you rebuild the system:"
    echo ">>>   nix build .#installer"
    exit 1
  fi
  echo
  echo "Stick is current."
else
  echo
  echo "No stamp file. Write a stick, then run: $0 --record"
  exit 1
fi
