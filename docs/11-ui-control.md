# Hardware UI capture and control

## Capture

The RK3288 framebuffer is exposed as `/dev/fb0`:

```text
virtual_size  800,3840
mode          800x1280
stride        3200
bpp           32
pan           0,<active-page-offset>
```

The framebuffer is triple-buffered. The visible page starts at the Y offset in
`/sys/class/graphics/fb0/pan`, typically 0, 1280, or 2560.

Capture the active page:

```sh
pan=$(ssh root@<unit> cat /sys/class/graphics/fb0/pan)
y=${pan#*,}
ssh root@<unit> "dd if=/dev/fb0 bs=3200 skip=$y count=1280 status=none" \
  > screen.raw
```

Convert the 800x1280 BGRA buffer and rotate it to the logical 1280x800 UI:

```python
from PIL import Image

raw = open("screen.raw", "rb").read()
image = Image.frombytes("RGBA", (800, 1280), raw, "raw", "BGRA")
image.rotate(90, expand=True).save("screen.png")
```

No screenshot service or display server is required.

## Touch input

The stock panel is `ILI2117 Touchscreen` on `/dev/input/event0`. Commands can
be injected through a temporary `/dev/uinput` multitouch device.

The verified calibration is:

```text
raw_x = 799 - logical_y
raw_y = logical_x
```

The generated device advertises an 800x1280 absolute coordinate space and
sends `ABS_MT_SLOT`, `ABS_MT_TRACKING_ID`, `ABS_MT_POSITION_X/Y`, `ABS_X/Y`,
`BTN_TOUCH`, and `SYN_REPORT`.

## Helper

```sh
export UNIT_HOST=<unit>
export UNIT_PASS=<password>

tools/ui-control/unit-ui.sh capture /tmp/player.png
tools/ui-control/unit-ui.sh tap 975 70
tools/ui-control/unit-ui.sh drag 800 130 640 740 900 24
```

`tap` and `drag` take logical 1280x800 coordinates. `raw-tap` bypasses the
rotation transform if the device or screen configuration changes.

The helper builds the ARMv7 binary in the `shimbuild` Docker container and
copies it to `/tmp` for each interaction. The device is not modified
persistently.

## Operational notes

* Capture is read-only.
* Synthetic input creates and destroys a temporary virtual device per command.
* Do not publish screenshots that contain account names, listening history,
  media libraries, or personal data.
* The example coordinates in this repository are generic UI locations; they
  are not tied to a specific user's content.
