{ config, lib, pkgs, inputs, hyprland, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Nix settings (улучшенные настройки)
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-users = [ "root" "@wheel" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
  
  nixpkgs.config.allowUnfree = true;

  # Boot loader (проверенные настройки UEFI)
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # Hibernation
    resumeDevice = "/dev/vg0/swap";
    kernelParams = [ 
      "resume=/dev/vg0/swap"
      "nvidia-drm.modeset=1"  # Для NVIDIA
    ];
    
    # Улучшенные настройки ядра для производительности
    kernel.sysctl = {
      "vm.swappiness" = 10;
      "fs.inotify.max_user_watches" = 524288;
    };
  };

  # Networking
  networking = {
    hostName = "PC-NixOS";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  # Localization (расширенные настройки)
  time.timeZone = "Europe/Moscow";
  i18n = {
    defaultLocale = "ru_RU.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "ru_RU.UTF-8";
      LC_IDENTIFICATION = "ru_RU.UTF-8";
      LC_MEASUREMENT = "ru_RU.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "ru_RU.UTF-8";
      LC_NUMERIC = "ru_RU.UTF-8";
      LC_PAPER = "ru_RU.UTF-8";
      LC_TELEPHONE = "ru_RU.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  # Console (улучшенные настройки для UWQHD)
  console = {
    keyMap = "us";
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    packages = with pkgs; [ terminus_font ];
  };

  # Users
  users = {
    users.artfil-nixos = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" ];
      shell = pkgs.zsh;
    };
    mutableUsers = true;
  };

  # Security
  security = {
    sudo.wheelNeedsPassword = false;
    rtkit.enable = true;
  };

  # Autologin
  services.getty.autologinUser = "artfil-nixos";

  # NVIDIA (оптимизированная конфигурация для RTX 4070)
  hardware = {
    nvidia = {
      modesetting.enable = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
      powerManagement = {
        enable = true;
        finegrained = false;
      };
      open = false;
      nvidiaSettings = true;
      # Улучшенная поддержка для современных карт
      forceFullCompositionPipeline = false;
    };
    
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
        vaapiVdpau
        libvdpau-va-gl
      ];
    };
  };

  services.xserver = {
    enable = false;
    videoDrivers = [ "nvidia" ];
    # Настройки для UWQHD мониторов
    dpi = 109; # Для 34" UWQHD
  };

  # Hyprland (оптимизированная конфигурация)
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

  # Environment variables (оптимизация для UWQHD и NVIDIA)
  environment = {
    variables = {
      EDITOR = "nvim";
      BROWSER = "firefox";
      TERMINAL = "kitty";
      WLR_DRM_DEVICES = "/dev/dri/card0";
      NIXOS_OZONE_WL = "1";
      # Оптимизация для высоких разрешений
      GDK_SCALE = "1.25";
      GDK_DPI_SCALE = "0.8";
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";
      # NVIDIA оптимизации
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      LIBVA_DRIVER_NAME = "nvidia";
    };
    
    # Расширенный набор системных пакетов
    systemPackages = with pkgs; [
      # Основные утилиты
      vim neovim git curl wget tree
      htop btop fastfetch
      unzip zip p7zip
      
      # Сеть
      networkmanager
      
      # Desktop
      kitty firefox
      waybar wofi grim slurp
      wl-clipboard
      
      # Файловые системы
      ntfs3g exfat
      
      # Hardware utilities
      lshw pciutils usbutils
      nvidia-system-monitor-qt
      
      # Development
      gcc gnumake cmake
      python3
    ];
  };

  # Fonts (расширенный набор для UWQHD)
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      dejavu_fonts
      liberation_ttf
      noto-fonts
      noto-fonts-emoji
      fira-code
      fira-code-symbols
      jetbrains-mono
      font-awesome
      (nerdfonts.override { 
        fonts = [ "FiraCode" "JetBrainsMono" "Inconsolata" ]; 
      })
    ];
    
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [ "Liberation Serif" ];
        sansSerif = [ "Liberation Sans" ];
        monospace = [ "JetBrainsMono Nerd Font" ];
        emoji = [ "Noto Color Emoji" ];
      };
      # Улучшенный рендеринг для высоких DPI
      hinting = {
        enable = true;
        style = "slight";
      };
      subpixel.rgba = "rgb";
    };
  };

  # Audio (PipeWire с улучшенными настройками)
  sound.enable = false;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    jack.enable = true;
    
    # Оптимизация для низкой задержки
    extraConfig.pipewire."92-low-latency" = {
      context.properties = {
        default.clock.rate = 48000;
        default.clock.quantum = 32;
        default.clock.min-quantum = 32;
        default.clock.max-quantum = 32;
      };
    };
  };

  # Bluetooth (улучшенная конфигурация)
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };
  };
  services.blueman.enable = true;

  # Дополнительные сервисы
  services = {
    # SSH для удаленного доступа
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    
    # Fstrim для SSD
    fstrim.enable = true;
    
    # Thermald для Intel CPU
    thermald.enable = true;
  };

  # Программы
  programs = {
    zsh.enable = true;
    steam.enable = true;  # Для gaming
    dconf.enable = true;  # Для GTK настроек
  };

  # System version
  system.stateVersion = "24.05";
}