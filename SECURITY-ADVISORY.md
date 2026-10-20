# Engine OS test-app launcher: OS command injection (CWE-78)

Status: **CVE requested / pending**  
Reported by: **coffeegrind123** (confirmed credit)  
Product: Denon DJ PRIME 4+ (`JC11S`), inMusic Engine OS  
Affected: 4.3.4 verified; builds with `test-app-launcher` 2.1.4 presumed
affected (public analysis places the same launcher on 5.0.4 RK3288 builds)  
CWE: CWE-78 (Improper Neutralization of Special Elements used in an OS Command)  
CVSS 3.1: `AV:P/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H` = **6.8**

## Summary

The factory Production Test Application launcher builds a shell command from
an attacker-controlled `.taimg` path and passes it to `wordexp(..., 0)`
without `WRDE_NOCMD`. Command substitution in the filename executes as root
before any image or signature check.

## Impact

Arbitrary command execution as `root`. The payload can install persistence in
the unverified `/data` partition (`/etc` overlay), enable password SSH, or
modify user data. The signed rootfs and bootloader are not modified.

## Attack scenario

Physical access to the unit:

1. write an ext4 USB stick with the catalogue
   `TestAppsCatalog/JC11S/1.0.0/2023.02.11/<payload>.taimg`;
2. open Settings → About/Update → five taps → Advanced → Start Production
   Test Application;
3. the launcher matches the app, waits five seconds, and executes the path.

The `.taimg` file can be empty; the command substitution fires before the
mount/signature check.

## Reproduction

The launcher log shows:

```
Matching test app version: 1.0.0
Going to run test app from /media/P4PWN/TestAppsCatalog/JC11S/1.0.0/2023.02.11/$(...).taimg
command starting: az01-signed-fs "/media/P4PWN/.../$(...).taimg"
```

A filename such as

```
$(sh${IFS}${PATH%%usr*}media${PATH%%usr*}P4PWN${PATH%%usr*}run.sh).taimg
```

runs `/media/P4PWN/run.sh` as root. QEMU reproduction and hardware evidence
are in the repository (`docs/`, `exports/` not published).

Note: the V1 catalogue order is `<product>/<app-version>/<os-version>/`; the
currently published documentation has the last two reversed and therefore
produces `No matching test app found`.

## Root cause

The launcher interpolates a filesystem path into

```
az01-signed-fs "<path>"
```

and calls `wordexp` without disabling command substitution. Correctness of
the path is checked only after the command has been expanded and executed.

## Suggested fix

* Replace the shell string with an argv-based `execve`, or pass
  `WRDE_NOCMD`.
* Reject shell metacharacters in catalogue filenames.
* Verify the package signature before constructing or executing anything.
* Run the test launcher without network or `/data` write access.

## Disclosure

* Vendor: inMusic / Denon DJ technical support (no security.txt or CNA found).
* CNA: MITRE (inMusic is not a CNA; the related CVE-2025-66723 was assigned
  by MITRE).
* Public references:
  * https://github.com/coffeegrind123/denon-prime4plus-research
  * https://randomcpu.com/denon-engine-os-test-app-launcher/
  * https://github.com/DeathCamel58/denon-reverse-engineering
* Timeline:
  * 2026-10-20 — discovered and reproduced in QEMU.
  * 2026-10-20 — reproduced on hardware.
  * vendor notification / CVE request pending.
