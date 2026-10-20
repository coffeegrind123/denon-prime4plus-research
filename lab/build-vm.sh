#!/bin/bash
# Reference implementation of the QEMU lab setup. Run inside the lab container
# (or any Debian environment with qemu-system-arm and the listed tools).
#
#   ./build-vm.sh <engine-rootfs.img> <usb-p4pwn.img>
#
# Produces, in ./vm:
#   vmlinuz, initrd.img, virt-az01.dtb, rootfs-vm.img, data.img
set -euo pipefail

ROOTFS=${1:?usage: build-vm.sh <rootfs.img> <usb.img>}
USB=${2:?usage: build-vm.sh <rootfs.img> <usb.img>}
VM=$(cd "$(dirname "$0")" && pwd)/vm
KV=6.1.0-50-armmp
mkdir -p "$VM"
cd "$VM"

# 1. Debian armmp kernel and static busybox
[ -f linux-image.deb ] || curl -fsSL -o linux-image.deb \
  http://deb.debian.org/debian/pool/main/l/linux/linux-image-6.1.0-50-armmp_6.1.176-1_armhf.deb
[ -f busybox.deb ] || curl -fsSL -o busybox.deb \
  http://deb.debian.org/debian/pool/main/b/busybox/busybox-static_1.35.0-4+deb12u1+b1_armhf.deb
rm -rf kdeb bbdeb && mkdir kdeb bbdeb
dpkg-deb -x linux-image.deb kdeb
dpkg-deb -x busybox.deb bbdeb
depmod -b kdeb "$KV"
cp "kdeb/boot/vmlinuz-$KV" vmlinuz

# 2. initramfs with the virtio + storage modules
rm -rf initramfs && mkdir -p initramfs/{bin,dev,proc,sys,newroot,modules,run,tmp}
cp bbdeb/bin/busybox initramfs/bin/
for a in sh mount umount insmod switch_root mkdir sleep ls cat echo; do
    ln -sf busybox "initramfs/bin/$a"
done
: > modorder.txt
for M in ext4 overlay virtio_mmio virtio_blk virtio_net virtio_pci virtio_gpu \
         usb_storage uas sd_mod ehci_hcd ehci_pci vfat exfat \
         nls_cp437 nls_iso8859_1 nls_utf8 nls_ascii scsi_mod; do
    modprobe -d kdeb -S "$KV" --show-depends --ignore-install "$M" 2>/dev/null \
        | sed -n 's/^insmod \([^ ]*\).*/\1/p' >> modorder.txt || true
done
awk '!seen[$0]++' modorder.txt > m2 && mv m2 modorder.txt
i=0
while IFS= read -r m; do
    [ -n "$m" ] || continue
    cp "$m" "$(printf 'initramfs/modules/%03d_%s' "$i" "$(basename "$m")")"
    i=$((i+1))
done < modorder.txt
cat > initramfs/init <<'INIT'
#!/bin/sh
export PATH=/bin
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
mkdir -p /dev/pts /dev/shm
mount -t devpts none /dev/pts 2>/dev/null
mount -t tmpfs none /run
for m in /modules/*.ko*; do insmod "$m" 2>/dev/null; done
sleep 2
for dev in /dev/vda /dev/vdb /dev/vdc /dev/vdd; do
    [ -b "$dev" ] || continue
    if mount -t ext4 -o rw "$dev" /newroot 2>/dev/null; then
        if [ -e /newroot/sbin/init ]; then
            umount /proc /sys /dev/pts 2>/dev/null
            exec switch_root /newroot /sbin/init
        fi
        umount /newroot
    fi
done
exec sh
INIT
chmod +x initramfs/init
( cd initramfs && find . | cpio -o -H newc --quiet ) | gzip -9 > initrd.img

# 3. DTB carrying the JC11S identity
qemu-system-arm -machine virt,highmem=off,dumpdtb=virt.dtb \
    -cpu cortex-a15 -m 2048 -smp 2 -display none 2>/dev/null || true
dtc -I dtb -O dts virt.dtb -o virt.dts 2>/dev/null
python3 - <<'PY'
import re
p='virt.dts'; s=open(p).read()
s=re.sub(r'compatible = "linux,dummy-virt";',
         'compatible = "inmusic,az01", "linux,dummy-virt";', s, count=1)
if 'inmusic,product-code' not in s:
    s=s.replace('/ {\n', '/ {\n\tinmusic,product-code = "JC11S";\n\tinmusic,panel-rotation = <0x00>;\n',1)
open(p,'w').write(s)
PY
dtc -I dts -O dtb virt.dts -o virt-az01.dtb 2>/dev/null

# 4. rootfs and data disks
cp "$ROOTFS" rootfs-vm.img
truncate -s 3G rootfs-vm.img
e2fsck -fy rootfs-vm.img >/dev/null 2>&1 || true
resize2fs rootfs-vm.img >/dev/null 2>&1 || true

truncate -s 2G data.img
sgdisk -o data.img >/dev/null
sgdisk -n 1:1M:0 -t 1:8300 \
    -u 1:931ad49d-ad59-0849-833a-9bf00af5b60e -c 1:az01-internal data.img >/dev/null

cp "$USB" usb-p4pwn.img
echo "[+] lab ready in $VM"
