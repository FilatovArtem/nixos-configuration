{ config, lib, pkgs, inputs, hyprland, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # LUKS encryption
  boot.initrd.luks.devices."nixos-root" = {
    device = "/dev/nvme0n1p2";
    preLVM = true;
    allowDiscards = true;
  };

  # Hibernation
  boot.resumeDevice = "/dev/vg0/swap";
  boot.kernelParams = [ "resume=/dev/vg0/swap" ];

  # Networking
  networking.hostName = "PC-NixOS";
  networking.networkmanager.enable = true;

  # Localization
  time.timeZone = "Europe/Moscow";
  i18n.defaultLocale = "ru_RU.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
  };

  # Console
  console = {
    keyMap = "us";
    font = "Lat2-Terminus16";
  };

  # Users
  users.users.artfil-nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
  };

  # Security
  security.sudo.wheelNeedsPassword = false;
  users.mutableUsers = true;

  # Autologin
  services.getty.autologinUser = "artfil-nixos";

  # NVIDIA
  hardware.nvidia = {
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
    powerManagement.enable = true;
    open = false;
  };

  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  services.xserver.enable = false;
  services.xserver.videoDrivers = [ "nvidia" ];

  # Hyprland
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    xwayland.enable = true;
  };

  # XDG Portal
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vim neovim git curl wget
    kitty firefox
    waybar wofi
    networkmanager
  ];

  # Audio
  sound.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa.enable = true;
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Fonts
  fonts.packages = with pkgs; [
    dejavu_fonts
    liberation_ttf
  ];

  # SSH
  services.openssh.enable = true;

  # System version
  system.stateVersion = "24.05";
}