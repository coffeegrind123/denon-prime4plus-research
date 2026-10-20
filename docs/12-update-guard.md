# Engine OS update paths and soft guard

All tests here ran in the disposable `eosvm2` QEMU container. No hardware
image or bootloader was modified.

## Online update check

Engine OS 4.3.4 contains:

```text
https://autoupdate.airmusictech.com/PrimeUpdates.xml
```

The feed currently advertises `PRIME4PLUS` 5.0.4 and an update-image URL below
`public.inmusiccdn.com`.

Engine exposes update UI actions including `checkForUpdates`, `updateOnline`,
`updateOnlineForUrl`, and `updateFromComputer`. The Engine binary also accepts
an `updateServerUrl` command-line override. A local invalid URL can suppress the
online check, but the update chain still needs a runtime guard because manual
local and loader paths remain.

`skipFirmwareUpdate` exists in Engine, but its surrounding strings describe
connected-device/MCU firmware checks. It should not be treated as an Engine OS
update lock.

## OS update handoff

`/usr/Engine/Scripts/engine` handles Engine quit reasons:

| Reason | Action |
|---|---|
| `UpdateFromLoader` | `cleanup`, then `reboot loader` |
| `UpdateFromFile` | `/usr/sbin/az01-update "$UPDATE_FILE"` |
| `UpdateFromUrl` | `/usr/bin/planck-remote-screen --update "$UPDATE_FILE"` |
| `FactoryReset` | `az01-update --erase-data` |

Direct updater usage:

```text
az01-update [--file|--net] <file|url>
az01-update --erase-data
```

`planck-remote-screen` also links `libaz01-prog.so` directly and exposes:

```text
--update <URL>
```

Therefore blocking only the online XML request is insufficient.

## Image verification

`/opt/ramfs-update.squashfs` contains the updater ramfs and the
`denon-1.pub` key. Its init:

* opens AZ0x and AZ01 containers;
* verifies the RSA signature with `/usr/lib/az01/pubkeys/<key>.pub`;
* verifies each partition hash;
* refuses unsigned images;
* writes boot, kernel, rootfs, or data partitions only after validation.

This means a soft guard is not required to prevent arbitrary unsigned images
from being installed. It is required to prevent an accidental *valid* vendor
update from replacing the current vulnerable OS and removing the existing root
path.

## Reversible guard

The prototype under `tools/update-guard/` bind-mounts wrappers over:

```text
/usr/sbin/az01-update
/usr/bin/planck-remote-screen
/usr/bin/systemctl
/usr/Engine/Scripts/engine
```

The originals are first copied under `/data/update-guard/`.

The wrappers:

* reject every `az01-update` operation except `--help`;
* allow normal `planck-remote-screen` operation but reject `--update` and `-u`;
* allow normal systemctl and reboot behavior but reject `reboot loader`;
* replace Engine's online update URL with `http://127.0.0.1:9/PrimeUpdates.xml`
  in the guarded shell script.

QEMU results:

```text
az01-update --file ...  -> blocked
az01-update --net ...   -> blocked
az01-update --erase-data -> blocked
planck-remote-screen --update ... -> blocked
reboot loader -> blocked
systemctl is-active ... -> normal result
```

The QEMU guest stayed running after the blocked loader request.

## Acceptance matrix

The guard was tested against a fresh disposable rootfs/data pair:

| Test | Result |
|---|---|
| Install from unmounted originals | passed |
| Run installer a second time | passed; `*.orig` hashes unchanged |
| `az01-update --help` | allowed |
| `az01-update --file` | blocked |
| `az01-update --net` | blocked |
| `az01-update --erase-data` | blocked |
| `planck-remote-screen --update=X` | blocked |
| `planck-remote-screen --update X` | blocked |
| `planck-remote-screen -u X` | blocked |
| `reboot loader` | blocked; guest uptime unchanged |
| Normal `systemctl is-active` | passed |
| Normal hardware-info utility | passed |
| Engine `UpdateFromFile` branch | blocked at updater wrapper |
| Engine `UpdateFromUrl` branch | blocked at remote-screen wrapper |
| Engine `UpdateFromLoader` branch | blocked at reboot wrapper |
| Engine `FactoryReset` branch | blocked at updater wrapper |
| Uninstall | all bind mounts removed |
| Original hashes after uninstall | match saved `*.orig` hashes |
| Reinstall after uninstall | passed |
| Reapply before Engine at boot | passed |

The Engine branch tests used a disposable fake Engine process that emitted each
quit reason, allowing the real guarded `engine` shell script to execute its
normal update cases without starting the QEMU graphics stack.

The boot-reapply test used a one-shot systemd test unit calling the same
installer. On the device, the equivalent call belongs in
`/data/payload/activate.sh` because newly added late-overlay units are not
reliably loaded during the boot transaction.

## Scope and bypasses

This is a soft lock for the normal OS and Engine UI. It is not a security
boundary:

* root can execute the saved `*.orig` binaries;
* removing `/data` removes the guard;
* booting the signed recovery/update image bypasses the rootfs completely;
* USB update mode and physical recovery remain available;
* controller, display, touch, and XMOS firmware services are not covered.

The guard fails closed at install time if it cannot preserve the original
binaries. Reboot or `uninstall.sh` detaches all bind mounts without rewriting
the signed rootfs.
