{ config, pkgs, inputs, hyprland, portal, ... }:

{
  imports = [
    # ./hardware-configuration.nix # Раскомментируйте когда сгенерируете
  ];
  nixpkgs.config.allowUnfree = true;

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Базовая конфигурация файловой системы (замените на свою)
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

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

  # User
  users.users.artfil-nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "bluetooth" ];
    # Установите пароль: passwd artfil-nixos после установки
  };
  
  # Разрешить sudo без пароля для группы wheel
  security.sudo.wheelNeedsPassword = false;
  
  users.mutableUsers = true; # Разрешить изменение паролей

  # Autologin on tty1
  services.getty.autologinUser = "artfil-nixos";

  # Nvidia
  hardware.nvidia = {
    modesetting.enable = true;
    package = pkgs.linuxPackages.nvidia_x11;
    powerManagement.enable = true;
  };
  services.xserver.enable = false;
  services.xserver.videoDrivers = [ "nvidia" ];

  # Hyprland + Wayland
  programs.hyprland = {
    enable = true;
    package = hyprland;
  };

  environment.systemPackages = with pkgs; [
    kitty neovim firefox waybar wofi kanshi
  ] ++ [ hyprland ];

  # Audio
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
  services.blueman.enable = true;

  # Swap file (10 GB)
  swapDevices = [{
    device = "/swapfile";
    size = 10 * 1024 * 1024 * 1024;
  }];

  # Timezone
  time.timeZone = "Europe/Moscow";

  # System version
  system.stateVersion = "24.05";
}
