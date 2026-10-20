#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SOURCE="$ROOT/tools/ui-control/ui_touch.c"
BUILD_DIR="$ROOT/build/ui-control"
BINARY="$BUILD_DIR/ui-touch-armhf"
REMOTE_BINARY=/tmp/prime4-ui-touch

: "${UNIT_HOST:?set UNIT_HOST to the player address}"
UNIT_USER=${UNIT_USER:-root}
: "${UNIT_PASS:?set UNIT_PASS in the environment}"
export SSHPASS="$UNIT_PASS"

SSH_OPTIONS=(
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o ConnectTimeout=8
)

ssh_run() {
    sshpass -e ssh "${SSH_OPTIONS[@]}" "$UNIT_USER@$UNIT_HOST" "$@"
}

build_touch() {
    local source_epoch=0
    local binary_epoch=0

    if [[ -f "$BINARY" ]]; then
        source_epoch=$(stat -c %Y "$SOURCE")
        binary_epoch=$(stat -c %Y "$BINARY")
    fi
    if [[ -x "$BINARY" && "$binary_epoch" -ge "$source_epoch" ]]; then
        return
    fi

    mkdir -p "$BUILD_DIR"
    if docker exec shimbuild true >/dev/null 2>&1; then
        docker cp "$SOURCE" shimbuild:/tmp/prime4-ui-touch.c
        docker exec shimbuild \
            arm-linux-gnueabihf-gcc -O2 -Wall -Wextra \
            -o /tmp/prime4-ui-touch /tmp/prime4-ui-touch.c
        docker cp shimbuild:/tmp/prime4-ui-touch "$BINARY"
    elif command -v arm-linux-gnueabihf-gcc >/dev/null; then
        arm-linux-gnueabihf-gcc -O2 -Wall -Wextra -o "$BINARY" "$SOURCE"
    else
        echo "need shimbuild Docker container or arm-linux-gnueabihf-gcc" >&2
        exit 1
    fi
}

install_touch() {
    build_touch
    sshpass -e scp "${SSH_OPTIONS[@]}" -O "$BINARY" \
        "$UNIT_USER@$UNIT_HOST:$REMOTE_BINARY" >/dev/null
    ssh_run "chmod 755 $REMOTE_BINARY"
}

capture() {
    local output=${1:-"screen-$(date +%Y%m%d-%H%M%S).png"}
    local pan
    local raw

    pan=$(ssh_run "cat /sys/class/graphics/fb0/pan")
    raw=${pan#*,}
    ssh_run "dd if=/dev/fb0 bs=3200 skip=$raw count=1280 status=none" \
        >"$output.raw"
    python3 - "$output.raw" "$output" <<'PY'
import sys
from PIL import Image

raw_path, output_path = sys.argv[1:]
image = Image.frombytes(
    "RGBA", (800, 1280), open(raw_path, "rb").read(), "raw", "BGRA"
)
image.rotate(90, expand=True).save(output_path)
PY
    rm "$output.raw"
    printf '%s\n' "$output"
}

logical_tap() {
    local x=$1
    local y=$2
    local hold=${3:-150}
    local raw_x=$((799 - y))

    install_touch
    ssh_run "$REMOTE_BINARY tap $raw_x $x $hold"
}

logical_doubletap() {
    local x=$1
    local y=$2
    local hold=${3:-60}
    local gap=${4:-120}
    local raw_x=$((799 - y))

    install_touch
    ssh_run "$REMOTE_BINARY doubletap $raw_x $x $hold $gap"
}

logical_drag() {
    local x1=$1
    local y1=$2
    local x2=$3
    local y2=$4
    local duration=${5:-900}
    local steps=${6:-24}
    local raw_x1=$((799 - y1))
    local raw_x2=$((799 - y2))

    install_touch
    ssh_run "$REMOTE_BINARY drag $raw_x1 $x1 $raw_x2 $x2 $duration $steps"
}

raw_tap() {
    install_touch
    ssh_run "$REMOTE_BINARY tap $1 $2 ${3:-150}"
}

case "${1:-}" in
    capture)
        shift
        capture "$@"
        ;;
    tap)
        shift
        logical_tap "$@"
        ;;
    doubletap)
        shift
        logical_doubletap "$@"
        ;;
    drag)
        shift
        logical_drag "$@"
        ;;
    raw-tap)
        shift
        raw_tap "$@"
        ;;
    *)
        cat >&2 <<EOF
usage: UNIT_HOST=... UNIT_PASS=... $0 capture [FILE.png]
       UNIT_HOST=... UNIT_PASS=... $0 tap X Y [HOLD_MS]
       UNIT_HOST=... UNIT_PASS=... $0 doubletap X Y [HOLD_MS] [GAP_MS]
       UNIT_HOST=... UNIT_PASS=... $0 drag X1 Y1 X2 Y2 [DURATION_MS] [STEPS]
       UNIT_HOST=... UNIT_PASS=... $0 raw-tap RAW_X RAW_Y [HOLD_MS]
EOF
        exit 2
        ;;
esac
