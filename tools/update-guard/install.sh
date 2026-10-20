#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
GUARD=/data/update-guard

mkdir -p "$GUARD"

is_mounted() {
    grep -q " $1 " /proc/mounts
}

if ! is_mounted /usr/sbin/az01-update; then
    cp /usr/sbin/az01-update "$GUARD/az01-update.orig"
fi
if ! is_mounted /usr/bin/planck-remote-screen; then
    cp /usr/bin/planck-remote-screen "$GUARD/planck-remote-screen.orig"
fi
if ! is_mounted /usr/bin/systemctl; then
    cp /usr/bin/systemctl "$GUARD/systemctl.orig"
fi
if ! is_mounted /usr/Engine/Scripts/engine; then
    cp /usr/Engine/Scripts/engine "$GUARD/engine.orig"
fi
if [ ! -s "$GUARD/az01-update.orig" ] ||
    [ ! -s "$GUARD/planck-remote-screen.orig" ] ||
    [ ! -s "$GUARD/systemctl.orig" ] ||
    [ ! -s "$GUARD/engine.orig" ]; then
    echo "original update binaries unavailable; reboot before reinstalling" >&2
    exit 1
fi

cp "$SCRIPT_DIR/az01-update.sh" "$GUARD/az01-update"
cp "$SCRIPT_DIR/planck-remote-screen.sh" "$GUARD/planck-remote-screen"
cp "$SCRIPT_DIR/systemctl.sh" "$GUARD/systemctl"
cp "$SCRIPT_DIR/uninstall.sh" "$GUARD/uninstall.sh"
chmod 755 "$GUARD/az01-update" "$GUARD/planck-remote-screen" \
    "$GUARD/systemctl" "$GUARD/uninstall.sh"
rm -f "$GUARD/reboot"
sed 's#/usr/Engine/Engine -d0#/usr/Engine/Engine -d0 -updateServerUrl http://127.0.0.1:9/PrimeUpdates.xml#' \
    "$GUARD/engine.orig" >"$GUARD/engine"
chmod 755 "$GUARD/engine"

mount_bind() {
    source=$1
    target=$2
    umount "$target" 2>/dev/null || true
    mount --bind "$source" "$target"
}

mount_bind "$GUARD/az01-update" /usr/sbin/az01-update
mount_bind "$GUARD/planck-remote-screen" /usr/bin/planck-remote-screen
mount_bind "$GUARD/systemctl" /usr/bin/systemctl
mount_bind "$GUARD/engine" /usr/Engine/Scripts/engine

echo "$(date -u +%FT%TZ) update guard installed" >>"$GUARD/guard.log"
