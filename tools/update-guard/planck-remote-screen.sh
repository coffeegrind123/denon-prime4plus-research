#!/bin/sh

for argument in "$@"; do
    case "$argument" in
        -u|--update|--update=*)
            echo "$(date -u +%FT%TZ) blocked remote update $*" \
                >>/data/update-guard/guard.log
            echo "OS update is blocked by update guard" >&2
            exit 1
            ;;
    esac
done

exec /data/update-guard/planck-remote-screen.orig "$@"
