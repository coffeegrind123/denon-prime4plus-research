# Handoff and remaining work

## Working state

* Root shell via password SSH (payload default `root` / `denonprime4`).
* Persistence through `/etc/ld.so.preload` + `/data/payload/activate.sh`,
  re-armed every boot via a `boot_id` marker.
* external service public playback verified on hardware through external service's
  resolver + locally concatenated HLS + ALSA.

## Recovery

The USB `usb-p4pwn.img` path is independent of SSH and of the installed
payload. Rebuild it with `exploit/make_usb_p4pwn.sh`, write raw, start the
Production Test Application, wait for the auto-run.

## Remaining gaps

1. **Own feed (`--me`)** — needs the account's OAuth token. Store it on
   `/data`, iterate the feed, record per-track refusals.
2. **Go+ tracks** — server-gated by `content_high_tier` and Widevine. Not
   solvable without a licence; public/free tracks are the supported scope.
3. **Engine deck integration** — the real DJ goal. Reasonable routes:
   * local HTTPS proxy impersonating `api-v2.external service.com`, with a CA
     installed in the `/etc` overlay and a `/etc/hosts` redirect;
   * cache tracks into a local folder and import them into Engine's library;
   * LD_PRELOAD hooks that redirect Engine's external service client to the proxy.
   All need mapping of Engine's external service request/response schema and its
   tier checks.
4. **ffmpeg network crash** — the static 7.0.2 build SIGSEGVs on any
   http/https input on this device. Use the existing local-HLS path, or
   build/find an ARMv7 ffmpeg with a working network stack.
5. **Cleanup** — see `docs/03-persistence.md` for the exact `/data` footprint
   and uninstall steps.

## Debug anchors

* launcher log: stdout/journal of `/usr/bin/test-app-launcher`
* persistence log: `/data/payload/activate.log`
* USB payload log: `/data/prime4usb.log`
* playback log: `/data/external service-local-play.log`
* probe: `/data/probe.txt`

The signed rootfs, kernel and bootloader are never modified.
