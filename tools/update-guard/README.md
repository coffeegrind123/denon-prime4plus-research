# Update guard prototype

This is a reversible, soft update lock for Engine OS 4.3.4. It was developed
and tested only against disposable QEMU images.

## What it blocks

* `/usr/sbin/az01-update` — local USB/file updates, network updates, factory
  reset, and data erase;
* `/usr/bin/planck-remote-screen --update` — the online update handoff;
* `/sbin/reboot loader` — Engine's transition into bootloader update mode;

The original executables are copied into `/data/update-guard/*.orig`. Bind
mounts place small wrappers over the read-only rootfs paths. Reboot, or running
`uninstall.sh`, removes the bind mounts without changing the signed rootfs.

The online checker may still report that an update exists. Every apply path
rejects the operation before an update image is used.

## Install

Copy this directory to the player as `/data/update-guard-src`, then run:

```sh
/data/update-guard-src/install.sh
```

For automatic reapplication after boot, invoke that command from the existing
`/data/payload/activate.sh` before Engine starts:

```sh
if [ -x /data/update-guard-src/install.sh ]; then
    /data/update-guard-src/install.sh \
        >>/data/update-guard/install.log 2>&1
fi
```

Installation is idempotent while mounted. If `*.orig` files are missing and a
wrapper is already mounted, the installer fails closed and asks for a reboot
rather than copying the wrapper as the original.

## Remove

```sh
/data/update-guard/uninstall.sh
```

or reboot. The wrappers remain in `/data`, but update functionality is restored
as soon as the bind mounts disappear.

## Verified in QEMU

```text
az01-update --file ...  -> blocked
planck-remote-screen --update ... -> blocked
reboot loader -> blocked
systemctl is-active ... -> normal result
```

The guard is deliberately not a hard security boundary. A local root user can
invoke `*.orig` directly, remove `/data`, or boot the signed recovery/update
image. Physical update mode bypasses the normal rootfs and therefore bypasses
this guard entirely.

## QEMU acceptance coverage

Tested successfully:

* clean install and idempotent reinstall;
* unchanged original hashes after repeated install;
* all local/network/erase update invocations blocked;
* every `planck-remote-screen` update spelling blocked;
* normal systemctl and hardware-info use;
* Engine `UpdateFromFile`, `UpdateFromUrl`, `UpdateFromLoader`, and
  `FactoryReset` quit-reason branches blocked;
* `reboot loader` rejected without changing guest uptime;
* uninstall restoring all original hashes;
* reinstalling after uninstall;
* automatic reapplication before Engine during boot.
