{
  description = "markov-desktop — tiered bcachefs root, Hyprland, Catppuccin Mocha";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative Catppuccin for NixOS + home-manager. Matches your Mocha
    # setup on the Mac, so both hosts can share one theme module.
    catppuccin.url = "github:catppuccin/nix";

    # Optional: wallpaper-driven base16 theming across GTK/Qt/terminals.
    # Pick catppuccin OR stylix, not both, or they'll fight over Qt.
    # stylix.url = "github:danth/stylix";

    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = { self, nixpkgs, home-manager, catppuccin, ... }@inputs: {

    # Rescue ISO. Built from this same flake.lock, so its bcachefs-tools and
    # kernel module are exactly the versions markov-desktop runs.
    #   nix build .#installer
    #   sudo dd if=result/iso/nixos-rescue-bcachefs.iso of=/dev/sdX bs=4M \
    #     conv=fsync status=progress
    nixosConfigurations."installer" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./iso.nix ];
    };

    packages.x86_64-linux.installer =
      self.nixosConfigurations.installer.config.system.build.isoImage;

    nixosConfigurations."markov-desktop" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        catppuccin.nixosModules.catppuccin

        ./configuration.nix

        {
          catppuccin = {
            enable = true;
            flavor = "mocha";
            accent = "mauve";
          };
        }

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-bak";
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.sharedModules = [ catppuccin.homeModules.catppuccin ];
          home-manager.users.markov = import ./home/markov.nix;
        }
      ];
    };
  };
}
