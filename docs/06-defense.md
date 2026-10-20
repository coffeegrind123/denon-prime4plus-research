# Defense notes

## Launcher

* Replace the `wordexp` call with an argv-based `execve`, or pass
  `WRDE_NOCMD`.
* Run the production test launcher in a sandbox without network or `/data`
  write access.
* Verify the signature of every test package **before** constructing any
  path or command.
* Validate that the product/OS directories are plain identifiers; reject
  metacharacters in filenames.
* Remove the factory launcher from production firmware, or gate it behind a
  signed unlock token.

## `/data` overlay

* Add dm-verity or a signed manifest for the upper layers, or encrypt them.
* Do not honour `/etc/ld.so.preload`, systemd units, udev rules or modprobe
  `install` directives that originate from `/data`.
* Restrict the overlay upper to data-only paths.

## Kernel FIT

* Set `required = "conf"` on the kernel FIT configurations so the RSA
  signature is enforced rather than fail-open.
* Keep the dm-verity root hash in a signed, separate metadata block.
* Do not rely on unkeyed hash nodes as an integrity boundary.

## Indicators

* `test-app-launcher` command lines containing `$(` or backticks.
* `az01-signed-fs` invocations against paths with shell metacharacters.
* `/data/system/etc/overlay/ld.so.preload`.
* `/data/payload/activate.log`, `/data/prime4usb.log`.
* `sshd` running with `-f /media/*/sshd_config` or
  `-f /data/payload/sshd_config`.

## Disclosure

Report the launcher `wordexp` issue and the `/data` trust model to the vendor
through their security contact. Give them the QEMU reproduction; no vendor
firmware or keys are required for it.
