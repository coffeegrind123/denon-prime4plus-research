# Handoff and remaining work

## Working state

* Root shell via password SSH (payload default `root` / `denonprime4`).
* Persistence through `/etc/ld.so.preload` + `/data/payload/activate.sh`,
  re-armed every boot via a `boot_id` marker.

## Recovery

The USB `usb-p4pwn.img` path is independent of SSH and of the installed
payload. Rebuild it with `exploit/make_usb_p4pwn.sh`, write raw, start the
Production Test Application, wait for the auto-run.

## Remaining gaps

1. **HTTPS fetcher** — the device's stock fetchers lack TLS. A static helper
   can provide HTTPS without replacing system libraries.
2. **Network-input decoder crash** — the static 7.0.2 build SIGSEGVs on
   http/https input on this device. Local files and ALSA output work.
3. **Cleanup** — see `docs/03-persistence.md` for the exact `/data` footprint
   and uninstall steps.

## Debug anchors

* launcher log: stdout/journal of `/usr/bin/test-app-launcher`
* persistence log: `/data/payload/activate.log`
* USB payload log: `/data/prime4usb.log`
* probe: `/data/probe.txt`

The signed rootfs, kernel and bootloader are never modified.
