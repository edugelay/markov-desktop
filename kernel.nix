{ lib, pkgs, ... }:

# Single source of truth for the kernel, imported by BOTH the system and the
# rescue ISO. The out-of-tree bcachefs module is built against whatever this
# resolves to, so if these two ever diverged the rescue stick would be useless.
#
# mkForce because the installer-cd profiles also set boot.kernelPackages, and
# neither definition is a mkDefault.
#
# bcachefs does not backport fixes to LTS — track a recent kernel here.

{
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
}
