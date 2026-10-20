#!/bin/bash
# Boot the lab built by build-vm.sh.
# Use -smp 2: 4 vCPUs intermittently hang in a TCG ARM TLB flush.
set -euo pipefail
VM=$(cd "$(dirname "$0")" && pwd)/vm
cd "$VM"
exec qemu-system-arm \
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
  -serial file:serial.log -monitor unix:mon.sock,server,nowait \
  -append "root=/dev/vdb rw rootwait console=ttyAMA0" -no-reboot
