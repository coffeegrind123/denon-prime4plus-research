# Denon Prime 4+ / Engine OS 4.3.4 — Security Research

Research notes and proof-of-concept code for a Denon DJ Prime 4+ (`JC11S`)
running Engine OS **4.3.4** (Buildroot 2023.02.11).
Current research release: **v0.2.3**.

The work covers four things:

1. a no-PC code-execution path through the factory **Production Test
   Application** launcher, reachable from a USB stick;
2. a persistent root shell built on the unverified `/data` partition;
3. a complete Docker-hosted QEMU lab used to reproduce and test every step
   against the real ARMv7 userland.
4. external EaaS source behavior and hardware UI capture/input research.

Everything below was reproduced on hardware and in emulation. No vendor
firmware, private keys, device serials, LAN addresses or personal data are
included.

---

## 1. Executive summary

| Finding | Result |
|---|---|
| AZ0x update container | RSA-2048 signed; cannot be repacked without the vendor key |
| Kernel FIT signature | hash nodes enforced, **config signature fail-open** (no `required`) |
| dm-verity | root hash bound only by the signed FIT cmdline |
| Production Test App V1 catalogue | documented layout is wrong; app and OS version directories are swapped |
| Launcher execution | auto-runs the catalogued `.taimg` path through `wordexp` without `WRDE_NOCMD` |
| Result | arbitrary command execution as **root** before any image/signature check |
| Persistence | `/etc` and `/var` are overlays with upper layers on the unverified `/data` partition |
| Boot trigger | `/etc/ld.so.preload` + a boot-id marker; survives reboots |
| Access | password SSH on port 22, verified after a cold reboot |
| QEMU lab | full Engine OS 4.3.4 userspace boot in a Docker container |
| Disclosure | `CAN-2026-2040266` submitted to MITRE; CVE ID pending; credit `coffeegrind123` |

The vendor’s own firmware update tooling and the community reverse-engineering
projects ([icedream/denon-prime4], [Peyton-C/QEngine], [DeathCamel58/denon-reverse-engineering])
were used as references. None of their code is vendored here.

---

## 2. The short version of the bug

Engine OS 4.3.4 ships a factory “Production Test Application” launcher. It
scans attached media for a **V1** catalogue:

```
<mount>/TestAppsCatalog/<PRODUCT>/<APP-VERSION>/<OS-VERSION>/<name>.taimg
```

The published documentation (and the first packages we built) used
`<PRODUCT>/<OS-VERSION>/<APP-VERSION>/`, which makes the launcher scan the
directory and then report `No matching test app found`.

With the correct order, the launcher:

1. matches `productCode=JC11S`, `osVersionID=2023.02.11`;
2. waits five seconds;
3. logs `Going to run test app from <path>`;
4. builds the string `az01-signed-fs "<path>"` and passes it to
   `wordexp(..., 0)`.

`wordexp` performs command substitution. A filename containing
`$(sh ... run.sh)` therefore executes **as root before the signature check**.
The `.taimg` itself can be an empty file; it never gets mounted successfully.

Proof from the QEMU lab:

```
Matching test app version: 1.0.0
Going to run test app from /media/P4PWN/TestAppsCatalog/.../$(sh${IFS}...run.sh).taimg
command starting: az01-signed-fs "/media/P4PWN/.../$(sh${IFS}...).taimg"
```

and from hardware:

```
=== Tue Oct 20 11:22:57 UTC 2026 prime4 usb payload ===
ssh-keygen: generating new host keys: RSA ECDSA ED25519
sshd rc=0
done
```

---

## 3. Persistence at a glance

`/etc` and `/var` are overlayfs mounts:

```
overlay on /etc  lowerdir=/etc  upperdir=/data/system/etc/overlay
overlay on /var  lowerdir=/var  upperdir=/data/system/var/overlay
```

`/data` is plain ext4 with no integrity check. The factory boot cleanup removes
only `ssh`, `passwd`, `shadow`, `group` and `gshadow` from the upper layer.
Everything else survives.

The persistence payload installs:

* `/data/payload/activate.sh` — sets the root password hash, generates host
  keys, starts sshd with a config on `/data`;
* `/data/payload/preload.so` — freestanding ARM32 shared object;
* `/etc/ld.so.preload` — loads `preload.so` into every dynamic process;
* a systemd unit, a `modprobe install` directive and a udev rule as persistent
  overlay files. New boot units require a later `daemon-reload`; the
  `/data/payload/activate.sh` path remains the deterministic trigger.

The preload arms once per boot, keyed on
`/proc/sys/kernel/random/boot_id` (the original `O_EXCL` marker only ever ran
once in the lifetime of the data partition). It forks
`/bin/sh /data/payload/activate.sh` as root.

After a cold reboot (default PoC credentials — user `root`, password
`denonprime4`):

```
$ ssh root@<unit-ip>
password: denonprime4
uid=0(root) gid=0(root) groups=0(root),10(wheel)
```

`/data/payload/activate.log` shows a fresh activation each boot.

---

## 4. Repository layout

```
docs/        full write-ups
exploit/     USB launcher payload and /data persistence payload
lab/         Docker/QEMU lab
tests/       offline checks
tools/       host-side research helpers
```

---

## 5. Quick start (USB route)

Build the ext4 image (default password `denonprime4`):

```sh
./exploit/make_usb_p4pwn.sh
```

To use a different password, run `exploit/hash-password.sh` and replace the
`ROOT_HASH` line in `exploit/usb-p4pwn/run.sh` and
`exploit/preload/activate.sh`, then rebuild.

The image is written **raw** to a USB stick. On Windows use **balenaEtcher**:

1. *Flash from file* → select `build/usb-p4pwn.img`;
2. select the USB stick;
3. *Flash*;
4. cancel any “You need to format this disk” prompt — the stick is ext4 on
   purpose and Windows cannot read it.

On Linux/macOS use `dd` (or balenaEtcher as well). The image is not bootable;
that is expected.

On the unit:

1. insert the stick;
2. Settings → About/Update → tap the version/product name five times;
3. Advanced → **Start Production Test Application**;
4. wait ~10 seconds;
5. `ssh root@<unit-ip>` — user `root`, password `denonprime4` by default.

The launcher may display an “unexpected error” dialog after the auto-run; that
is the dummy `.taimg` failing to mount. The injected command has already run.

Install persistence:

```sh
scp -r exploit/preload/* root@<unit-ip>:/data/payload/
# then follow docs/03-persistence.md to install the /etc overlay files
```

---

## 6. QEMU lab

The lab runs a fresh `debian:bookworm` container with:

* `qemu-system-arm` 7.2;
* a Debian armmp kernel (`6.1.0-50-armmp`) and a custom initramfs;
* a QEMU `virt` DTB patched with `inmusic,az01` and `inmusic,product-code = "JC11S"`;
* the extracted Engine OS rootfs as a virtio disk;
* a GPT data disk with the `931ad49d-…` PARTUUID;
* the USB image attached as `usb-storage`;
* `-smp 2` to avoid a TCG ARM TLB-flush hang seen with 4 vCPUs.

See `docs/04-qemu-lab.md` and `lab/` for the exact scripts.

---

## 7. External-source and UI research

Engine OS 4.3.4 can discover external EaaS libraries over UDP 11224 and consume
them through gRPC on TCP 50010 and HTTP on TCP 50020. On-player sources bind
both standard ports to a secondary LAN alias and send discovery replies from
that same address. The protocol, source-tree mapping, and stream contract are documented in
[`docs/10-eaas-source-protocol.md`](docs/10-eaas-source-protocol.md).
That document also records the standard-port layout for a source hosted on the
same player and the boot-safe activation route through the `/data` overlay.

The hardware UI can be captured through `/dev/fb0` and driven through
`/dev/uinput`. The calibrated capture/tap/doubletap/drag workflow is documented in
[`docs/11-ui-control.md`](docs/11-ui-control.md) and implemented under
`tools/ui-control/`.

---

## 8. Disclosure and safety

The launcher command injection is documented in
[`SECURITY-ADVISORY.md`](SECURITY-ADVISORY.md). The CVE request draft and
vendor notification text are in [`docs/09-cve-request.md`](docs/09-cve-request.md).
Credit: **coffeegrind123**. Handoff/remaining work:
[`docs/08-handoff.md`](docs/08-handoff.md).

This repository is research material for hardware you own. The exploit gives
root and disables signature enforcement paths at runtime; do not run it on
equipment you do not control.

The launcher bug and the `/data` trust model are worth reporting to the vendor.
See `docs/06-defense.md` for mitigation ideas and `SECURITY.md` for contact.

[icedream/denon-prime4]: https://github.com/icedream/denon-prime4
[Peyton-C/QEngine]: https://github.com/Peyton-C/QEngine
[DeathCamel58/denon-reverse-engineering]: https://github.com/DeathCamel58/denon-reverse-engineering
