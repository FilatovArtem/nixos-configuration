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
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      nixosConfigurations.PC-NixOS = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
        ];

        specialArgs = {
          inherit inputs;
          hyprland = hyprland.packages.${system}.hyprland;
          portal = hyprland.packages.${system}.xdg-desktop-portal-hyprland;
        };

        configuration = {
          nixpkgs.config.allowUnfree = true;

          # Bootloader
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;

          # Basic system settings
          networking.hostName = "PC-NixOS";
          networking.networkmanager.enable = true;

          i18n = {
            defaultLocale = "ru_RU.UTF-8";
            extraLocaleSettings = {
              LC_TIME = "en_US.UTF-8";
              LC_MONETARY = "en_US.UTF-8";
            };
          };
          console.keyMap = "us,ru";
          console.font = "Lat2-Terminus16";

          # User (edit artfil-nixos and password manually)
          users.users.artfil-nixos = {
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" "video" "audio" "bluetooth" ];
          };
          users.mutableUsers = false;

          # Autologin on tty1
          services.getty.autologin.enable = true;
          services.getty.autologin.user = "artfil-nixos";
          services.getty.autologin.tty = "tty1";

          # Nvidia setup
          hardware.nvidia = {
            modesetting.enable = true;
            package = pkgs.linuxPackages.nvidia_x11;
            powerManagement.enable = true;
          };
          services.xserver.enable = false; # disable X11 (we use Wayland)
          services.xserver.videoDrivers = [ "nvidia" ];

          # Wayland + Hyprland
          programs.hyprland = {
            enable = true;
            package = hyprland;
          };

          environment.systemPackages = with pkgs; [
            hyprland kitty neovim firefox waybar wofi kanshi
          ];

          # Audio via PipeWire
          sound.enable = true;
          services.pipewire = {
            enable = true;
            audio.enable = true;
            pulse.enable = true;
            alsa.enable = true;
          };
          security.rtkit.enable = true;

          # Bluetooth
          hardware.bluetooth.enable = true;
          services.bluetooth.enable = true;

          # Swap file 10G for hibernation support
          swapDevices = [
            {
              device = "/swapfile";
              size = 10 * 1024 * 1024 * 1024;
            }
          ];

          # Timezone
          time.timeZone = "Europe/Moscow";

          # System state version
          system.stateVersion = "24.05";

          # Home manager
          home-manager = {
            useUserPackages = true;
            users.artfil-nixos = { };
          };
        };
      };
    };
}
