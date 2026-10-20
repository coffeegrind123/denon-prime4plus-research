#!/usr/bin/env bash
# Build the USB image and verify its contents with debugfs. No device needed.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

bash "$ROOT/exploit/make_usb_p4pwn.sh" "$TMP/usb.img" >/dev/null

fail=0
check() {
  local name=$1
  shift
  if "$@"; then echo "ok   $name"; else echo "FAIL $name"; fail=1; fi
}

check image sh -c "file '$TMP/usb.img' | grep -q ext4"
check label sh -c "dumpe2fs -h '$TMP/usb.img' 2>/dev/null | grep -q 'P4PWN'"
check run-sh sh -c "debugfs -R 'stat /run.sh' '$TMP/usb.img' 2>/dev/null | grep -q 'Type: regular'"
check password sh -c "debugfs -R 'cat /sshd_config' '$TMP/usb.img' 2>/dev/null | grep -qx 'PasswordAuthentication yes'"
check no-pubkey sh -c "debugfs -R 'cat /sshd_config' '$TMP/usb.img' 2>/dev/null | grep -qx 'PubkeyAuthentication no'"
check no-pam sh -c "! debugfs -R 'cat /sshd_config' '$TMP/usb.img' 2>/dev/null | grep -q '^UsePAM'"
check catalog sh -c "debugfs -R 'ls /TestAppsCatalog/JC11S/1.0.0/2023.02.11' '$TMP/usb.img' 2>/dev/null | grep -qF '\$(sh\${IFS}'"
check no-swapped sh -c "! debugfs -R 'ls /TestAppsCatalog/JC11S/2023.02.11/1.0.0' '$TMP/usb.img' 2>/dev/null | grep -q taimg"

exit "$fail"
