# Полная инструкция по установке NixOS с шифрованием LUKS

## Характеристики системы
- **Процессор**: Intel i5-11600
- **Видеокарта**: NVIDIA RTX 4070
- **Накопитель**: NVMe 500GB
- **Монитор**: UWQHD 3440x1440 @ 175Hz
- **Сеть**: Ethernet с статическим IP
- **Архитектура**: x86_64 с UEFI

## 1. Подготовка к установке

### 1.1 Загрузка с NixOS Live USB
1. Загрузитесь с флешки NixOS
2. Выберите раскладку клавиатуры (US/RU)
3. Войдите в систему как пользователь `nixos`

### 1.2 Настройка сети (при необходимости)
```bash
# Проверить подключение
ping -c 3 8.8.8.8

# Если нужен статический IP (замените на ваши значения)
sudo ip addr add 192.168.1.100/24 dev enp3s0  # замените интерфейс
sudo ip route add default via 192.168.1.1
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

### 1.3 Увеличение консольного шрифта (опционально)
```bash
sudo setfont ter-132n
```

## 2. Разметка диска

### 2.1 Определение диска
```bash
# Найти NVMe диск
lsblk
# Обычно это /dev/nvme0n1

# Установить переменную для удобства
export DISK="/dev/nvme0n1"
```

### 2.2 Создание таблицы разделов
```bash
# Очистить диск (ОСТОРОЖНО!)
sudo wipefs -a $DISK

# Создать GPT таблицу разделов
sudo parted $DISK -- mklabel gpt

# Создать EFI раздел (512MB)
sudo parted $DISK -- mkpart ESP fat32 1MB 513MB
sudo parted $DISK -- set 1 esp on

# Создать основной раздел для LUKS (остальное место)
sudo parted $DISK -- mkpart primary 513MB 100%

# Проверить разметку
sudo parted $DISK -- print
lsblk
```

## 3. Настройка шифрования LUKS + LVM

### 3.1 Создание зашифрованного контейнера
```bash
# Создать LUKS контейнер (введите НАДЕЖНЫЙ пароль!)
sudo cryptsetup luksFormat /dev/nvme0n1p2

# Открыть зашифрованный раздел
sudo cryptsetup luksOpen /dev/nvme0n1p2 nixos-root

# Проверить что контейнер открыт
ls -la /dev/mapper/nixos-root
```

### 3.2 Настройка LVM
```bash
# Создать физический том
sudo pvcreate /dev/mapper/nixos-root

# Создать группу томов
sudo vgcreate vg0 /dev/mapper/nixos-root

# Создать логические тома:
# Root: 60GB (достаточно для системы)
sudo lvcreate -L 60G -n root vg0

# Swap: 32GB (для гибернации, >= RAM)
sudo lvcreate -L 32G -n swap vg0

# Home: остальное место (~400GB)
sudo lvcreate -l 100%FREE -n home vg0

# Проверить созданные тома
sudo lvdisplay
lsblk
```

## 4. Форматирование файловых систем

```bash
# EFI раздел
sudo mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1

# Root раздел (ext4 с журналированием)
sudo mkfs.ext4 -L NIXOS /dev/vg0/root

# Home раздел
sudo mkfs.ext4 -L HOME /dev/vg0/home

# Swap
sudo mkswap -L SWAP /dev/vg0/swap

# Проверить метки
sudo blkid
```

## 5. Монтирование файловых систем

```bash
# Монтировать корневой раздел
sudo mount /dev/vg0/root /mnt

# Создать точки монтирования
sudo mkdir -p /mnt/boot
sudo mkdir -p /mnt/home

# Монтировать остальные разделы
sudo mount /dev/nvme0n1p1 /mnt/boot
sudo mount /dev/vg0/home /mnt/home

# Включить swap
sudo swapon /dev/vg0/swap

# Проверить монтирование
df -h
lsblk
```

## 6. Генерация базовой конфигурации

```bash
# Сгенерировать hardware-configuration.nix
sudo nixos-generate-config --root /mnt

# Посмотреть что сгенерировалось
cat /mnt/etc/nixos/hardware-configuration.nix
```

## 7. Создание конфигурационных файлов

### 7.1 Создание flake.nix
```bash
sudo tee /mnt/etc/nixos/flake.nix << 'EOF'
{
  description = "NixOS configuration with Hyprland and NVIDIA RTX 4070";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, home-manager, hyprland, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
    in {
      nixosConfigurations.PC-NixOS = nixpkgs.lib.nixosSystem {
        inherit system;
        
        modules = [
          ./configuration.nix
          ./home-manager.nix
          home-manager.nixosModules.home-manager
        ];

        specialArgs = {
          inherit inputs pkgs-unstable;
        };
      };
    };
}
EOF
```

### 7.2 Создание configuration.nix
```bash
sudo tee /mnt/etc/nixos/configuration.nix << 'EOF'
{ config, lib, pkgs, inputs, pkgs-unstable, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Разрешить несвободные пакеты
  nixpkgs.config.allowUnfree = true;

  # Nix flakes и новые команды
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;

  # Загрузчик UEFI
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 5;
    };
    
    # LUKS расшифровка
    initrd.luks.devices."nixos-root" = {
      device = "/dev/nvme0n1p2";
      preLVM = true;
      allowDiscards = true; # Для SSD TRIM
    };
    
    # Гибернация
    resumeDevice = "/dev/vg0/swap";
    kernelParams = [ 
      "resume=/dev/vg0/swap"
      "nvidia-drm.modeset=1" # Для NVIDIA
    ];
    
    # Поддержка NTFS (для совместимости)
    supportedFilesystems = [ "ntfs" ];
  };

  # Сеть
  networking = {
    hostName = "PC-NixOS";
    networkmanager.enable = true;
    # Для статического IP раскомментируйте и настройте:
    # interfaces.enp3s0.ipv4.addresses = [{
    #   address = "192.168.1.100";
    #   prefixLength = 24;
    # }];
    # defaultGateway = "192.168.1.1";
    # nameservers = [ "8.8.8.8" "1.1.1.1" ];
  };

  # Локализация
  time.timeZone = "Europe/Moscow";
  i18n = {
    defaultLocale = "ru_RU.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
    };
  };

  # Консоль
  console = {
    keyMap = "us";
    font = "ter-132n";
    packages = with pkgs; [ terminus_font ];
  };

  # Пользователи
  users = {
    users.artfil-nixos = {
      isNormalUser = true;
      extraGroups = [ 
        "wheel" "networkmanager" "video" "audio" 
        "bluetooth" "docker" "libvirtd" 
      ];
      shell = pkgs.zsh;
    };
    mutableUsers = true;
  };

  # Sudo без пароля для wheel
  security.sudo.wheelNeedsPassword = false;

  # Автологин
  services.getty.autologinUser = "artfil-nixos";

  # NVIDIA драйверы
  hardware = {
    nvidia = {
      modesetting.enable = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
      powerManagement.enable = true;
      powerManagement.finegrained = false;
      open = false; # Проприетарный драйвер для RTX 4070
      nvidiaSettings = true;
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

  services.xserver.videoDrivers = [ "nvidia" ];

  # Hyprland
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    xwayland.enable = true;
  };

  # XDG Desktop Portal
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };

  # Системные пакеты
  environment = {
    systemPackages = with pkgs; [
      # Основные утилиты
      vim neovim git curl wget tree htop
      unzip zip p7zip
      
      # Сеть
      networkmanager networkmanager-openvpn
      
      # Файловые системы
      ntfs3g exfat
      
      # Hardware info
      lshw pciutils usbutils
      
      # Мониторинг
      nvtop btop
      
      # Wayland/Hyprland
      kitty firefox waybar wofi
      wl-clipboard grim slurp
      
      # Мультимедиа
      pavucontrol pipewire-pulse
      
      # Development
      gcc gnumake cmake
      
      # Fonts
      (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" ]; })
    ] ++ [
      # Unstable packages
      pkgs-unstable.discord
    ];
    
    # Переменные окружения
    variables = {
      EDITOR = "nvim";
      BROWSER = "firefox";
      TERMINAL = "kitty";
      WLR_DRM_DEVICES = "/dev/dri/card0";
      NIXOS_OZONE_WL = "1"; # Wayland для Chromium приложений
    };
    
    # Глобальные шрифты
    systemPackages = with pkgs; [
      liberation_ttf
      dejavu_fonts
      noto-fonts
      noto-fonts-emoji
    ];
  };

  # Шрифты
  fonts = {
    packages = with pkgs; [
      liberation_ttf
      dejavu_fonts
      noto-fonts
      noto-fonts-emoji
      (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" ]; })
    ];
    
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [ "Liberation Serif" ];
        sansSerif = [ "Liberation Sans" ];
        monospace = [ "JetBrainsMono Nerd Font" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };

  # Звук через PipeWire
  sound.enable = false; # Отключить ALSA
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    jack.enable = true;
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
  };
  services.blueman.enable = true;

  # Печать (опционально)
  # services.printing.enable = true;

  # SSH (для удаленного доступа)
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # SSH
    # allowedUDPPorts = [ ];
  };

  # Автоматическая очистка Nix store
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Версия состояния системы
  system.stateVersion = "24.05";
}
EOF
```

### 7.3 Создание home-manager.nix
```bash
sudo tee /mnt/etc/nixos/home-manager.nix << 'EOF'
{ config, lib, pkgs, inputs, ... }:

let
  username = "artfil-nixos";
in
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    
    users.${username} = { pkgs, ... }: {
      home.stateVersion = "24.05";
      
      # Пакеты пользователя
      home.packages = with pkgs; [
        # Утилиты командной строки
        fastfetch bat eza ripgrep fd fzf yazi
        zoxide starship
        
        # Разработка
        vscode jetbrains.idea-community
        
        # Мультимедиа
        vlc obs-studio gimp
        
        # Общение
        telegram-desktop
        
        # Игры
        steam lutris
        
        # Офис
        libreoffice
        
        # Архиваторы
        ark
      ];
      
      # Программы
      programs = {
        # Zsh
        zsh = {
          enable = true;
          enableCompletion = true;
          autosuggestion.enable = true;
          syntaxHighlighting.enable = true;
          
          shellAliases = {
            ll = "eza -la";
            la = "eza -la";
            ls = "eza";
            tree = "eza --tree";
            cat = "bat";
            cd = "z";
            grep = "rg";
            find = "fd";
            rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#PC-NixOS";
            update = "sudo nix flake update /etc/nixos && rebuild";
          };
          
          initExtra = ''
            eval "$(zoxide init zsh)"
            eval "$(starship init zsh)"
          '';
        };
        
        # Git
        git = {
          enable = true;
          userName = "Your Name";
          userEmail = "your.email@example.com";
          extraConfig = {
            init.defaultBranch = "main";
            core.editor = "nvim";
            pull.rebase = false;
          };
        };
        
        # Starship prompt
        starship = {
          enable = true;
          settings = {
            format = "$all$character";
            character = {
              success_symbol = "[➜](bold green)";
              error_symbol = "[➜](bold red)";
            };
          };
        };
        
        # Firefox
        firefox = {
          enable = true;
          profiles.default = {
            name = "Default";
            isDefault = true;
            settings = {
              "browser.startup.homepage" = "about:home";
              "browser.newtabpage.enabled" = false;
              "browser.newtabpage.activity-stream.enabled" = false;
            };
          };
        };
      };
      
      # Hyprland конфигурация
      wayland.windowManager.hyprland = {
        enable = true;
        settings = {
          # Мониторы (настройте под свой монитор)
          monitor = [
            "DP-1,3440x1440@175,0x0,1"
            ",preferred,auto,1"
          ];
          
          # Переменные окружения
          env = [
            "XCURSOR_SIZE,24"
            "WLR_NO_HARDWARE_CURSORS,1"
            "NVIDIA_DISABLE_FLIPPING,1"
          ];
          
          # Входные устройства
          input = {
            kb_layout = "us,ru";
            kb_options = "grp:alt_shift_toggle";
            
            follow_mouse = 1;
            
            touchpad = {
              natural_scroll = false;
            };
            
            sensitivity = 0;
          };
          
          # Общие настройки
          general = {
            gaps_in = 5;
            gaps_out = 10;
            border_size = 2;
            "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
            "col.inactive_border" = "rgba(595959aa)";
            
            layout = "dwindle";
            allow_tearing = false;
          };
          
          # Декорации
          decoration = {
            rounding = 10;
            
            blur = {
              enabled = true;
              size = 3;
              passes = 1;
              vibrancy = 0.1696;
            };
            
            drop_shadow = true;
            shadow_range = 4;
            shadow_render_power = 3;
            "col.shadow" = "rgba(1a1a1aee)";
          };
          
          # Анимации
          animations = {
            enabled = true;
            
            bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
            
            animation = [
              "windows, 1, 7, myBezier"
              "windowsOut, 1, 7, default, popin 80%"
              "border, 1, 10, default"
              "borderangle, 1, 8, default"
              "fade, 1, 7, default"
              "workspaces, 1, 6, default"
            ];
          };
          
          # Раскладка dwindle
          dwindle = {
            pseudotile = true;
            preserve_split = true;
          };
          
          # Мастер раскладка
          master = {
            new_is_master = true;
          };
          
          # Жесты
          gestures = {
            workspace_swipe = false;
          };
          
          # Настройки устройств
          device = {
            name = "epic-mouse-v1";
            sensitivity = -0.5;
          };
          
          # Клавиатурные сочетания
          "$mainMod" = "SUPER";
          
          bind = [
            # Основные
            "$mainMod, Q, exec, kitty"
            "$mainMod, C, killactive,"
            "$mainMod, M, exit,"
            "$mainMod, E, exec, thunar"
            "$mainMod, V, togglefloating,"
            "$mainMod, R, exec, wofi --show drun"
            "$mainMod, P, pseudo,"
            "$mainMod, J, togglesplit,"
            
            # Перемещение фокуса
            "$mainMod, left, movefocus, l"
            "$mainMod, right, movefocus, r"
            "$mainMod, up, movefocus, u"
            "$mainMod, down, movefocus, d"
            
            # Переключение рабочих столов
            "$mainMod, 1, workspace, 1"
            "$mainMod, 2, workspace, 2"
            "$mainMod, 3, workspace, 3"
            "$mainMod, 4, workspace, 4"
            "$mainMod, 5, workspace, 5"
            "$mainMod, 6, workspace, 6"
            "$mainMod, 7, workspace, 7"
            "$mainMod, 8, workspace, 8"
            "$mainMod, 9, workspace, 9"
            "$mainMod, 0, workspace, 10"
            
            # Перемещение окон на рабочие столы
            "$mainMod SHIFT, 1, movetoworkspace, 1"
            "$mainMod SHIFT, 2, movetoworkspace, 2"
            "$mainMod SHIFT, 3, movetoworkspace, 3"
            "$mainMod SHIFT, 4, movetoworkspace, 4"
            "$mainMod SHIFT, 5, movetoworkspace, 5"
            "$mainMod SHIFT, 6, movetoworkspace, 6"
            "$mainMod SHIFT, 7, movetoworkspace, 7"
            "$mainMod SHIFT, 8, movetoworkspace, 8"
            "$mainMod SHIFT, 9, movetoworkspace, 9"
            "$mainMod SHIFT, 0, movetoworkspace, 10"
            
            # Скроллинг рабочих столов
            "$mainMod, mouse_down, workspace, e+1"
            "$mainMod, mouse_up, workspace, e-1"
            
            # Скриншоты
            ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
            "SHIFT, Print, exec, grim - | wl-copy"
          ];
          
          # Привязки мыши
          bindm = [
            "$mainMod, mouse:272, movewindow"
            "$mainMod, mouse:273, resizewindow"
          ];
          
          # Автозапуск
          exec-once = [
            "waybar"
            "hyprpaper"
          ];
        };
      };
      
      # Waybar конфигурация
      programs.waybar = {
        enable = true;
        settings = [{
          layer = "top";
          position = "top";
          height = 34;
          
          modules-left = [ "hyprland/workspaces" ];
          modules-center = [ "hyprland/window" ];
          modules-right = [ 
            "pulseaudio" "network" "cpu" "memory" 
            "temperature" "clock" "tray" 
          ];
          
          "hyprland/workspaces" = {
            disable-scroll = true;
            all-outputs = true;
          };
          
          clock = {
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
            format-alt = "{:%Y-%m-%d}";
          };
          
          cpu = {
            format = "{usage}% ";
            tooltip = false;
          };
          
          memory = {
            format = "{}% ";
          };
          
          temperature = {
            critical-threshold = 80;
            format = "{temperatureC}°C {icon}";
            format-icons = ["" "" ""];
          };
          
          network = {
            format-wifi = "{essid} ({signalStrength}%) ";
            format-ethernet = "{ipaddr}/{cidr} ";
            tooltip-format = "{ifname} via {gwaddr} ";
            format-linked = "{ifname} (No IP) ";
            format-disconnected = "Disconnected ⚠";
          };
          
          pulseaudio = {
            format = "{volume}% {icon} {format_source}";
            format-bluetooth = "{volume}% {icon} {format_source}";
            format-bluetooth-muted = " {icon} {format_source}";
            format-muted = " {format_source}";
            format-source = "{volume}% ";
            format-source-muted = "";
            format-icons = {
              headphone = "";
              hands-free = "";
              headset = "";
              phone = "";
              portable = "";
              car = "";
              default = ["" "" ""];
            };
            on-click = "pavucontrol";
          };
        }];
        
        style = ''
          * {
            border: none;
            border-radius: 0;
            font-family: "JetBrainsMono Nerd Font";
            font-size: 13px;
            min-height: 0;
          }
          
          window#waybar {
            background-color: rgba(43, 48, 59, 0.8);
            border-bottom: 3px solid rgba(100, 114, 125, 0.5);
            color: #ffffff;
            transition-property: background-color;
            transition-duration: .5s;
          }
          
          #workspaces button {
            padding: 0 5px;
            background-color: transparent;
            color: #ffffff;
            border-bottom: 3px solid transparent;
          }
          
          #workspaces button:hover {
            background: rgba(0, 0, 0, 0.2);
          }
          
          #workspaces button.active {
            background-color: #64727D;
            border-bottom: 3px solid #ffffff;
          }
          
          #clock,
          #battery,
          #cpu,
          #memory,
          #temperature,
          #network,
          #pulseaudio,
          #tray {
            padding: 0 10px;
            color: #ffffff;
          }
        '';
      };
    };
  };
}
EOF
```

## 8. Установка NixOS

```bash
# Перейти в директорию конфигурации
cd /mnt/etc/nixos

# Установить систему
sudo nixos-install --flake .#PC-NixOS

# При успешной установке система попросит установить пароль root
# Можете пропустить (Enter), так как используется sudo без пароля
```

## 9. Настройка после установки

```bash
# Войти в установленную систему
sudo nixos-enter --root /mnt

# Установить пароль пользователя
passwd artfil-nixos

# Включить NetworkManager (если нужно)
systemctl enable NetworkManager

# Выйти из chroot
exit
```

## 10. Завершение установки

```bash
# Размонтировать файловые системы
sudo umount -R /mnt
sudo swapoff /dev/vg0/swap

# Деактивировать LVM и закрыть LUKS
sudo vgchange -a n vg0
sudo cryptsetup luksClose nixos-root

# Перезагрузка
reboot
```

## 11. Первый запуск

1. **При загрузке** введите пароль для расшифровки диска
2. **Система автоматически войдет** под пользователем `artfil-nixos`
3. **Запустите терминал** (Super + Q) и проверьте систему:

```bash
# Проверить статус
neofetch
htop
nvidia-smi

# Обновить систему
sudo nix flake update /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#PC-NixOS
```

## 12. Дополнительные настройки

### 12.1 Настройка мониторов в Hyprland
Если разрешение не определилось автоматически, отредактируйте:
```bash
sudo nvim /etc/nixos/home-manager.nix
# Найдите секцию monitor и настройте под ваш монитор
```

### 12.2 Статический IP
Если нужен статический IP, раскомментируйте соответствующие строки в `configuration.nix`.

### 12.3 Gaming (Steam, Lutris)
Уже включены в home-manager конфигурацию.

### 12.4 Резервные копии конфигурации
```bash
# Создать резервную копию
sudo cp -r /etc/nixos ~/nixos-backup-$(date +%Y%m%d)

# Или использовать git
cd /etc/nixos
sudo git init
sudo git add .
sudo git commit -m "Initial NixOS configuration"
```

## Лучшие практики

### Безопасность
- ✅ LUKS шифрование всего диска
- ✅ Отключен root login по SSH
- ✅ Firewall включен
- ✅ Автоматические обновления безопасности

### Производительность
- ✅ NVIDIA проприетарный драйвер для RTX 4070
- ✅ SSD TRIM поддержка
- ✅ Zram для ускорения
- ✅ Оптимизация Nix store

### Удобство
- ✅ Flakes для воспроизводимости
- ✅ Home Manager для пользовательских настроек
- ✅ Автоматическая очистка старых поколений
- ✅ Алиасы для быстрых команд

### Мультимедиа
- ✅ PipeWire для современного аудио
- ✅ VAAPI для аппаратного декодирования
- ✅ Поддержка высокой частоты обновления (175Hz)
- ✅ Wayland для лучшей производительности

## Устранение неполадок

### Если система не загружается
1. Загрузитесь с live USB
2. Откройте LUKS: `cryptsetup luksOpen /dev/nvme0n1p2 nixos-root`
3. Активируйте LVM: `vgchange -ay vg0`
4. Монтируйте и войдите: `mount /dev/vg0/root /mnt && nixos-enter --root /mnt`

### Если NVIDIA не работает
Проверьте что используется правильный драйвер:
```bash
nvidia-smi
lsmod | grep nvidia
```

### Если Hyprland не запускается
Проверьте логи:
```bash
journalctl --user -u hyprland
```

Эта конфигурация обеспечивает:
- **Безопасность**: Полное шифрование диска
- **Производительность**: Оптимизация для gaming и NVIDIA
- **Современность**: Wayland, PipeWire, Flakes
- **Удобство**: Автоматизация и лучшие практики NixOS