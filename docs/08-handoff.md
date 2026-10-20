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

1. **External-source clients** — the on-device EaaS layout is documented and
   locally verified; other Engine builds still need the same discovery, port,
   and listener checks.
2. **Boot transaction coverage** — `/data` hooks work, but newly written
   systemd wants/drop-ins require a later `daemon-reload` on this firmware.
3. **Cleanup** — see `docs/03-persistence.md` for the exact `/data` footprint
   and uninstall steps.

## Debug anchors

* launcher log: stdout/journal of `/usr/bin/test-app-launcher`
* persistence log: `/data/payload/activate.log`
* USB payload log: `/data/prime4usb.log`
* probe: `/data/probe.txt`
* application boot helper: `/data/prime4-app/boot-start.log`

The signed rootfs, kernel and bootloader are never modified.
