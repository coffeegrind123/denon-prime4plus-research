# Security policy

This repository is security research for hardware you own.

## Reporting

For issues in this repository, use GitHub private vulnerability reporting on
this repo.

For the underlying device issues (launcher `wordexp` injection, `/data`
overlay trust model), report them to Denon DJ / inMusic through their security
contact. A vendor reproduction does not require firmware or private keys: the
Docker/QEMU lab in `lab/` boots the vendor rootfs supplied by the researcher.

## Scope

In scope:

* Production Test Application catalogue handling;
* `wordexp` command construction;
* `/etc` / `/var` overlay trust boundaries;
* `/data` preload/systemd/modprobe/udev trust.

Out of scope:

* repacking signed AZ0x firmware;
* bypassing Widevine or Go+ licensing.
