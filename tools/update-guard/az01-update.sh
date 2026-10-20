#!/bin/sh

for argument in "$@"; do
    case "$argument" in
        -h|--help)
            exec /data/update-guard/az01-update.orig --help
            ;;
    esac
done

log=/data/update-guard/guard.log
mkdir -p /data/update-guard
echo "$(date -u +%FT%TZ) blocked az01-update $*" >>"$log"
echo "OS update and factory reset are blocked by update guard" >&2
exit 1
