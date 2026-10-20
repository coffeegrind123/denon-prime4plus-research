#!/bin/sh

command_name=$(basename "$0")
if [ "$command_name" = "reboot" ] && [ "${1:-}" = "loader" ]; then
    echo "$(date -u +%FT%TZ) blocked loader reboot" \
        >>/data/update-guard/guard.log
    echo "Loader/update mode is blocked by update guard" >&2
    exit 1
fi

exec /data/update-guard/systemctl.orig "$@"
