{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./filesystems.nix
    ./backup.nix
  ];

  #############################################################################
  # Boot / dual boot
  #############################################################################

  boot.loader = {
    efi.canTouchEfiVariables = true;
    timeout = 5;

    systemd-boot = {
      enable = true;
      configurationLimit = 10;
      editor = false;
      consoleMode = "max";

      # Windows lives on nvme1n1p3 (its own 100M ESP), so systemd-boot cannot
      # autodetect it. Enable the shell, reboot into it, run `map -c`, then
      # `ls HDxx:\EFI` until you find Microsoft. Put that handle below.
      edk2-uefi-shell.enable = true;
      edk2-uefi-shell.sortKey = "z_edk2";

      windows."11" = {
        title = "Windows 11";
        efiDeviceHandle = "HD2b";   # <-- REPLACE with your handle
        sortKey = "y_windows";
      };
    };
  };

  #############################################################################
  # Windows interop
  #############################################################################

  boot.supportedFilesystems.ntfs = true;
  time.hardwareClockInLocalTime = false;
  # On the Windows side, once:
  #   reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" \
  #     /v RealTimeIsUniversal /t REG_QWORD /d 1 /f
  #   powercfg /h off

  #############################################################################
  # Nix
  #############################################################################

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "markov" ];
    warn-dirty = false;
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;

  #############################################################################
  # Networking / locale
  #############################################################################

  networking.hostName = "markov-desktop";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  #############################################################################
  # Desktop — Hyprland primary, Plasma kept as a fallback session
  #############################################################################

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  programs.uwsm.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Keep Plasma installed. When Hyprland is mid-breakage you'll want it.
  services.desktopManager.plasma6.enable = true;
  services.xserver.enable = false;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  console.useXkbConfig = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  security.pam.services.hyprlock = { };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
      inter
      noto-fonts
      noto-fonts-emoji
      noto-fonts-cjk-sans
    ];
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      sansSerif = [ "Inter" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  #############################################################################
  # Hardware / fans
  #############################################################################

  hardware.enableRedistributableFirmware = true;
  services.fwupd.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # If Radeon:  hardware.amdgpu.initrd.enable = true;
  # If NVIDIA:  services.xserver.videoDrivers = [ "nvidia" ];
  #             hardware.nvidia.modesetting.enable = true;
  #             programs.coolercontrol.nvidiaSupport = true;

  programs.coolercontrol.enable = true;

  # Declarative alternative to CoolerControl's GUI curves. Generate once with
  # `pwmconfig`, then paste the result here so fan curves live in git too.
  # hardware.fancontrol = {
  #   enable = true;
  #   config = ''
  #     INTERVAL=10
  #     DEVPATH=hwmon0=devices/platform/nct6775.656
  #     ...
  #   '';
  # };

  #############################################################################
  # Gaming
  #############################################################################

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
  programs.gamemode.enable = true;

  #############################################################################
  # Users
  #############################################################################

  users.users."markov" = {
    isNormalUser = true;
    description = "markov";
    extraGroups = [ "networkmanager" "wheel" "video" "audio" "input" ];
    shell = pkgs.nushell;
  };
  environment.shells = [ pkgs.nushell ];

  programs.firefox.enable = true;
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    # core
    neovim git wget curl ripgrep fd jq eza bat fzf zoxide starship
    nushell ghostty yazi

    # storage
    bcachefs-tools smartmontools nvme-cli ntfs3g efibootmgr restic

    # hardware
    lm_sensors liquidctl pciutils usbutils btop nvtopPackages.full

    # wayland / rice
    waybar hyprpaper hyprlock hypridle hyprpicker hyprshot
    fuzzel swaynotificationcenter wl-clipboard cliphist
    pavucontrol brightnessctl playerctl
    matugen wallust
    cava fastfetch
  ];

  environment.variables.EDITOR = "nvim";
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  #############################################################################
  # Services
  #############################################################################

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  services.tailscale.enable = true;

  system.stateVersion = "26.05";
}
