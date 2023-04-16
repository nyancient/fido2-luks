fido2-luks
==========

This package is forked from [yubikey-luks](https://github.com/cornelinux/yubikey-luks).
It provides the following benefits over the original yubikey-luks:
- Device support: any FIDO2 token with the hmac-secret extension is supported.
- Brute force protection: since the FIDO2 hmac-secret extension is used,
  the security token handles PIN verification, and can enforce brute force protection
  policies. Yubikeys, for example, lock up after five incorrect PIN guesses by default.
- `systemd-cryptsetup` compatibility: this package uses the same on-disk format as
  `systemd-cryptsetup`, making migration trivial if Debian gets around to replacing
  `cryptsetup` in its initramfs.
- Zero configuration: no external configuration file is required to unlock an
  encrypted device, just the device, your FIDO2 token, and your PIN.

Description
-----------

This package lets you use a FIDO2 token with the hmac-secret extension
as a strong single factor for LUKS (Linux full disk encryption).

Well-known examples of such tokens include all FIDO2 models of Yubikey,
the Google Titan key, the Nitrokey FIDO2, any SoloKey,
and any other [Microsoft-compatible FIDO2 key](https://learn.microsoft.com/en-us/azure/active-directory/authentication/concept-fido2-hardware-vendor#current-partners).

The keyscript lets you boot the machine with either the FIDO2 token and its PIN,
or with a normal password from any key slot.
For security and to avoid having to support multiple separate use cases,
PIN entry is mandatory for decryption.


Installation
------------

1. Add the nyancient repository:
   ```bash
   curl https://nyancient.github.io/deb/setup.sh | sh
   ```
   Or, if you want to inspect the (very short) setup script before running it:
   ```bash
   curl https://nyancient.github.io/deb/setup.sh -o setup.sh
   cat setup.sh # Convince yourself that the script is safe to run
   sh ./setup.sh # Then run it
   ```
2. Install `fido2-luks`:
   ```bash
   sudo apt install fido2-luks
   ```


Enroll a FIDO2 token
--------------------

You can now assign the Yubikey to a slot using the tool

    fido2-luks-enroll

This will cause a few things to happen:
0. (If `-c` was specified) any existing FIDO2 LUKS keyslots are wiped.
1. A FIDO2 credential and salt is created and stored as a LUKS token in
   the header of the encrypted device.
2. The FIDO2 token computes a HMAC over the salt and credential created in step 1.
   You will be prompted for your FIDO2 token's PIN and asked to verify your presence.
3. The resulting HMAC is enrolled as a LUKS passphrase on the encrypted device.

This has a few implications:
1. To decrypt a device using your FIDO2 token, you only need the device itself (obviously),
   the token, and the token's PIN.
2. If an attacker is able to intercept the HMAC secret (e.g. using an evil maid attack),
   the secret can be used as a normal passphrase to unlock the disk.

It is therefore recommended that you keep a separate recovery key, if you should lose
your token, and to use secure boot with a
[signed initramfs](https://askubuntu.com/questions/1247826/secure-boot-verification-of-initramfs)
to prevent the HMAC secret from being intercepted.


Configuring encrypted root
--------------------------

In order to use your FIDO2 token to decrypt your root disk at boot time, there are still
a few hoops to jump through:

1. Add `keyscript=/usr/share/fido2-luks/fido2-luks-keyscript` to the options section of
   the entry in `/etc/crypttab` that corresponds to your encrypted root device.
2. Run `update-initramfs -u`, to make the above changes take effect during boot.


Non-root decryption
-------------------

Any partitions except the root partition can be unlocked at any time using
the `fido2-luks-open` command. This also applies to image files, USB memory sticks, or
anything else that uses LUKS for encryption.


Building
--------

Build the package (without signing it):

    make builddeb NO_SIGN=1

Install the package:

    dpkg -i DEBUILD/fido2-luks_0.*-1_all.deb
