#!/bin/sh
set -eu

for target in \
    /usr/sbin/az01-update \
    /usr/bin/planck-remote-screen \
    /usr/bin/systemctl; do
    umount "$target" 2>/dev/null || true
done

echo "update guard detached; rootfs files are visible again"
