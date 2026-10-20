# Target: Prime 4+ / Engine OS 4.3.4

## Hardware and software

| Item | Value |
|---|---|
| Product | Denon DJ PRIME 4+ |
| Product code | `JC11S` |
| SoC | Rockchip RK3288-C, ARMv7 hard-float |
| Firmware | Engine OS 4.3.4, Buildroot 2023.02.11 |
| Kernel | `6.1.111-inmusic-2024-09-19-rt41`, PREEMPT_RT |
| Update file | `AZ0x` container, 172,048,912 bytes |

Device tree identities used by Engine:

```
compatible = "inmusic,jc11s", "inmusic,az01", "rockchip,rk3288-c", "rockchip,rk3288"
inmusic,product-code = "JC11S"
```

## Storage layout

```
p1 spl1 544K    p2 spl2        p3 info1 512K  p4 info2 512K
p5 uboot1 4M    p6 uboot2 4M   p7 splash 4M   p8 updatesplash 4M
p9 kernel 16M   p10 rootfs 1024M
p11 data (rest of eMMC, ext4, PARTUUID 931ad49d-ad59-0849-833a-9bf00af5b60e)
```

## Trust chain

```
BootROM -> idbloader/TPL+SPL -> U-Boot (signed FIT)
        -> kernel.fit (signed FIT, hash nodes enforced)
        -> dm-verity rootfs on p10 (ro)
        -> overlayfs upper layers for /etc and /var on p11 (/data)
```

The `AZ0x` update container is RSA-2048/SHA-256 signed with `denon-1`; the
signature covers the container header and every payload has a separate
SHA-256. Repacking the update file is not possible without the vendor key.

That is not the weak point. The weak points are:

* the kernel FIT’s **config signatures have no `required` property**, so
  U-Boot’s required-signature check fails open;
* the FIT hash nodes are unkeyed and can be recomputed;
* dm-verity’s root hash lives in the FIT cmdline, not in a signed metadata
  block;
* `/data` has no integrity check and is the writable upper for `/etc` and
  `/var`;
* the factory test-app launcher builds a shell command from a filename and
  runs it through `wordexp` without `WRDE_NOCMD`.

## What is not broken

The bootloader and SPL are signed and enforced. There is no usable vendor
private key on the device. Writing the AZ0x container and expecting the
normal updater to accept it does not work.

The route documented here never touches the signed rootfs or bootloader.
Everything lives in `/data` or executes from a USB stick.
