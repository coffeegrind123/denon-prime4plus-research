# Persistence on `/data`

## 1. Why `/data` survives

```
overlay on /etc type overlay lowerdir=/etc upperdir=/data/system/etc/overlay
overlay on /var type overlay lowerdir=/var upperdir=/data/system/var/overlay
```

The rootfs on p10 is dm-verity and read-only. `/data` is plain ext4 with no
integrity check. At boot, `overlayfs-setup.service` removes only `ssh`,
`passwd`, `shadow`, `group` and `gshadow` from the `/etc` upper layer.
Everything else in the upper survives reboots.

## 2. Files

| Path on `/data` | Runtime path |
|---|---|
| `/data/payload/activate.sh` | script |
| `/data/payload/sshd_config` | sshd config |
| `/data/payload/preload.so` | LD_PRELOAD object |
| `/data/system/etc/overlay/ld.so.preload` | `/etc/ld.so.preload` |
| `.../systemd/system/az0x-svc.service` | `/etc/systemd/system/...` |
| `.../modules-load.d/az0x-svc.conf` | `/etc/modules-load.d/...` |
| `.../modprobe.d/az0x-svc.conf` | `/etc/modprobe.d/...` |
| `.../udev/rules.d/99-az0x-svc.rules` | `/etc/udev/rules.d/...` |

`/etc/ld.so.preload` contains:

```
/data/payload/preload.so
```

## 3. Boot trigger

`preload.so` is freestanding ARM32 (raw EABI syscalls, no libc). On the first
dynamic exec after `/data` is mounted it:

1. reads `/proc/sys/kernel/random/boot_id`;
2. compares it with `/data/payload/.armed`;
3. if different, writes the new boot id and forks
   `/bin/sh /data/payload/activate.sh`;
4. if equal, returns immediately.

The boot-id marker is important: a plain `O_EXCL` marker only fires once in
the lifetime of the data partition, so the helper would never run again after
the first boot.

## 4. activate.sh

On every boot it:

* replaces `root:*` in `/etc/shadow` with the configured hash (the upper
  shadow is removed by the boot cleanup);
* generates an ed25519 host key on `/data`;
* starts `/usr/sbin/sshd -f /data/payload/sshd_config`;
* optionally attaches a root shell to the USB serial gadget.

The sshd config uses password authentication only:

```
Port 22
PasswordAuthentication yes
PubkeyAuthentication no
AuthenticationMethods password
PermitRootLogin yes
```

No `UsePAM` — the binary has no PAM support.

## 5. Secondary triggers

The systemd unit, `modprobe install` directive and udev rule are kept as
best-effort fallbacks. The `ld.so.preload` route is the deterministic one.

## 6. Install and verify

```sh
scp exploit/preload/{activate.sh,sshd_config,preload.so} root@<unit>:/data/payload/
ssh root@<unit> 'mkdir -p /data/system/etc/overlay/{systemd/system/multi-user.target.wants,modules-load.d,modprobe.d,udev/rules.d}'
# copy the overlay files, then:
ssh root@<unit> 'sync; reboot'
```

After the reboot:

```
$ ssh root@<unit>          # default PoC password: denonprime4
uid=0(root) ...
$ tail /data/payload/activate.log
... activate.sh start
... root password hash applied
... sshd started rc=0
... activate.sh done
```

The `boot_id` in `/data/payload/.armed` changes on every boot.

## 7. Recovery

Delete `/data/system/etc/overlay/ld.so.preload` from the data partition
(offline with `debugfs` or through a temporary root shell) to disable the
preload. Never install a `ld.so.preload` that points at a missing or corrupt
library.

## 8. Footprint on the unit

Nothing is written to the signed rootfs (p10), kernel (p9), bootloader or SPL.
The writable footprint is:

| Path | Size | Purpose |
|---|---:|---|
| `/data/payload/` | ~40 KiB | persistence scripts, preload, host key |
| `/data/system/etc/overlay/` | ~110 KiB | ld.so.preload, systemd/modprobe/udev entries, overlay metadata |
| `/data/probe.sh`, `/data/probe.txt` | ~20 KiB | diagnostics |
| `/data/prime4usb.log` | ~8 KiB | evidence |

`/tmp` is tmpfs and disappears on reboot.

Uninstall (keeps SSH until the reboot that removes the preload):

```sh
rm -f /data/system/etc/overlay/ld.so.preload
rm -rf /data/payload
rm -f /data/prime4usb.log
# optional: remove the systemd/modprobe/udev overlay files
```

The `ld.so.preload` file must be removed first; the overlay upper cannot be
safely edited while it is mounted, so remove the other files from a fresh
boot/USB shell.
