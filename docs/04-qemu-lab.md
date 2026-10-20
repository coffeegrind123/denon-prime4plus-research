# Docker-hosted QEMU lab

All emulation is done inside a Docker container. A fresh `debian:bookworm`
container is enough; the host only needs Docker.

## 1. Container

```sh
docker run -d --name eos-lab --platform linux/amd64 debian:bookworm sleep infinity
docker exec eos-lab bash -c '
  apt-get update -qq &&
  apt-get install -y qemu-system-arm cpio xz-utils device-tree-compiler \
      kmod curl e2fsprogs gdisk uuid-runtime openssh-client sshpass'
```

## 2. Kernel and initramfs

The Rockchip kernel has no virtio drivers. Use Debian’s armmp kernel for the
lab:

```
linux-image-6.1.0-50-armmp_6.1.176-1_armhf.deb
busybox-static_1.35.0-4+deb12u1+b1_armhf.deb
```

Extract with `dpkg-deb -x`, run `depmod -b kdeb 6.1.0-50-armmp`, and build a
small initramfs containing busybox plus these modules:

```
ext4 overlay virtio_mmio virtio_blk virtio_net virtio_pci virtio_gpu
usb_storage uas sd_mod ehci_hcd ehci_pci vfat exfat
nls_cp437 nls_iso8859_1 nls_utf8 nls_ascii scsi_mod
```

The init script loads every module, finds the ext4 disk that contains
`/sbin/init`, and `switch_root`s into it.

## 3. Device tree

Dump QEMU’s `virt` DTB and add the identity Engine reads:

```
compatible = "inmusic,az01", "linux,dummy-virt";
inmusic,product-code = "JC11S";
inmusic,panel-rotation = <0x00>;
```

Do **not** add `rockchip,rk3288` to the compatible list: the kernel then
selects the Rockchip machine descriptor and hangs before serial output.

## 4. Disks

* rootfs: a writable copy of the extracted 4.3.4 rootfs, grown to 3 GiB;
* data: a 2 GiB GPT disk with one partition whose PARTUUID is
  `931ad49d-ad59-0849-833a-9bf00af5b60e` (matches `data.mount`);
* USB: the exploit ext4 image, attached through `usb-storage`.

For faster boots, mask hardware-only units in the lab image
(`engine`, `xmos-update`, `touch-fw-update`, `soundswitch`). The launcher,
edisksd and D-Bus are untouched.

## 5. Boot

```sh
qemu-system-arm \
  -machine virt,highmem=off -cpu cortex-a15 -m 2048 -smp 2 \
  -dtb virt-az01.dtb -kernel vmlinuz -initrd initrd.img \
  -drive if=none,file=rootfs-vm.img,format=raw,id=hd \
  -device virtio-blk-device,drive=hd \
  -drive if=none,file=data.img,format=raw,id=data \
  -device virtio-blk-device,drive=data \
  -device usb-ehci,id=usb \
  -drive if=none,file=usb-p4pwn.img,format=raw,id=stick \
  -device usb-storage,drive=stick,bus=usb.0 \
  -netdev user,id=n0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=n0 \
  -device virtio-gpu-pci -display none \
  -serial file:/work/serial.log -monitor unix:/work/mon.sock,server,nowait \
  -append "root=/dev/vdb rw rootwait console=ttyAMA0" -no-reboot
```

Use `-smp 2`. With 4 vCPUs the Debian armmp kernel occasionally hangs in a
TCG ARM TLB-flush during systemd start.

## 6. Test sequence

1. wait for the serial getty/login;
2. confirm `compatible` contains `inmusic,az01` and product code `JC11S`;
3. run `/usr/bin/test-app-launcher`;
4. observe `Matching test app version`, the auto-run and the
   `az01-signed-fs` command line;
5. confirm `/data/prime4usb.log`;
6. confirm sshd listens on port 22;
7. log in with the configured password;
8. negative checks: wrong password and pubkey-only must both fail.

## 7. Expected evidence

```
Matching test app version: 1.0.0
Going to run test app from /media/P4PWN/TestAppsCatalog/.../$(...).taimg
command starting: az01-signed-fs "/media/P4PWN/.../$(...).taimg"
...
uid=0(root) gid=0(root) groups=0(root),10(wheel)
Permission denied, please try again.
Permission denied (password).
```

The `az01-signed-fs` mount failure after the command is expected: the injection
already executed.
