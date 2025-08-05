{
  description = "My NixOS config with Hyprland and Flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, hyprland, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations.PC-NixOS = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          ./configuration.nix
          ./home-manager.nix
          home-manager.nixosModules.default
        ];

        specialArgs = {
          inherit inputs;
          hyprland = hyprland.packages.${system}.hyprland;
          portal = hyprland.packages.${system}.xdg-desktop-portal-hyprland;
          home-manager = home-manager;
        };
      };
    };
}
