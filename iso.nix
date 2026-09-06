{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    # The -no-zfs variant matters: the plain installer profile pulls in ZFS,
    # which pins the kernel backwards and can make the bcachefs module
    # unavailable for that kernel.
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix")
    ./kernel.nix
  ];

  # Kernel comes from ./kernel.nix, shared with the system config, so the
  # ISO's bcachefs module can't drift from the one that mounts your root.
  boot.supportedFilesystems.bcachefs = true;

  isoImage.isoName = lib.mkForce "nixos-rescue-bcachefs.iso";
  isoImage.volumeID = lib.mkForce "NIXOS_RESCUE";

  networking.hostName = "rescue";
  networking.networkmanager.enable = true;

  # So you can reach the TrueNAS restic repo from the rescue environment.
  services.tailscale.enable = true;

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  # Drop your public key here so you can SSH in rather than typing on a
  # console at midnight.
  users.users.root.openssh.authorizedKeys.keys = [
    # "ssh-ed25519 AAAA... markov"
  ];

  environment.systemPackages = with pkgs; [
    bcachefs-tools
    keyutils          # needed for encrypted bcachefs unlock
    restic
    git
    neovim
    gptfdisk parted
    smartmontools nvme-cli
    efibootmgr
    ntfs3g
    tmux
    rsync
    pciutils usbutils
  ];

  # Print the versions on the console banner so you can eyeball a stale stick
  # without booting all the way in.
  environment.etc."issue".text = ''
    NixOS rescue — bcachefs
    tools: ${pkgs.bcachefs-tools.version}
    kernel: ${config.boot.kernelPackages.kernel.version}

  '';
}
