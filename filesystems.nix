{ config, lib, pkgs, ... }:

let
  # Same paths used in format-disks.sh. bcachefs takes a colon-separated
  # device list; both members must be listed for the initrd to assemble it.
  fast = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_500GB_S4EVNZFN502006R-part2";
  slow = "/dev/disk/by-id/ata-CT500MX500SSD1_2028E2B63EE7-part2";
  members = "${fast}:${slow}";
in
{
  # Kernel comes from ./kernel.nix, shared with the rescue ISO. nixpkgs builds
  # bcachefs as an out-of-tree module and marks it broken on unsupported
  # kernels, so a bad choice fails the build rather than the boot.
  imports = [ ./kernel.nix ];

  boot.supportedFilesystems.bcachefs = true;
  boot.initrd.supportedFilesystems.bcachefs = true;

  fileSystems."/" = {
    device = members;
    fsType = "bcachefs";
    options = [ "degraded" ];   # still boot if one member is missing
  };

  fileSystems."/home" = {
    device = members;
    fsType = "bcachefs";
    options = [ "X-mount.subdir=home" "degraded" ];
  };

  fileSystems."/nix" = {
    device = members;
    fsType = "bcachefs";
    options = [ "X-mount.subdir=nix" "degraded" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # Spare ESP on the second disk. Not automatically kept in sync — see notes.
  fileSystems."/boot-fallback" = {
    device = "/dev/disk/by-label/BOOTALT";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" "nofail" "noauto" ];
  };

  # 2TB Seagate: files + this repo. Untouched by the install.
  fileSystems."/srv/archive" = {
    device = "/dev/disk/by-uuid/3f44dad1-f31b-4e49-be8b-c10736e0ba79";
    fsType = "btrfs";
    options = [ "compress=zstd:3" "noatime" "nofail" ];
  };

  # Windows (WD SN750). Read-only until `powercfg /h off` has been run there.
  # Get the UUID with: blkid on the 465.1G ntfs partition of
  # /dev/disk/by-id/nvme-WDS500G3X0C-00SJG0_210767805963
  fileSystems."/mnt/windows" = {
    device = "/dev/disk/by-uuid/REPLACE-ME";
    fsType = "ntfs3";
    options = [ "ro" "nofail" "uid=1000" "gid=100" "windows_names" ];
  };

  swapDevices = [ ];
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # Monthly integrity pass over both members.
  systemd.services.bcachefs-scrub = {
    description = "bcachefs scrub of /";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bcachefs-tools}/bin/bcachefs data scrub /";
      IOSchedulingClass = "idle";
      Nice = 19;
    };
  };
  systemd.timers.bcachefs-scrub = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "monthly";
      RandomizedDelaySec = "6h";
      Persistent = true;
    };
  };
}
