# NixOS Configuration - Оптимизированная конфигурация

Готовая к использованию конфигурация NixOS с Hyprland, оптимизированная для современного gaming ПК.

## 🖥️ Целевая система
- **CPU**: Intel i5-11600
- **GPU**: NVIDIA RTX 4070  
- **Monitor**: UWQHD 3440x1440 @ 175Hz
- **Storage**: NVMe 500GB с LUKS шифрованием
- **Network**: Ethernet

## ✨ Основные особенности

### 🎯 Производительность
- Hyprland compositor для максимальной производительности
- NVIDIA производственный драйвер с оптимизациями
- Низкая задержка аудио (PipeWire)
- Автоматическая оптимизация Nix store

### 🛡️ Безопасность  
- **Два варианта**: с LUKS шифрованием или без (проще)
- LVM для гибкого управления разделами
- SSH только по ключам
- Firewall настроен

### 🔧 Простота установки
- **Версии без LUKS** - решают проблемы загрузки
- Автоматическая загрузка без паролей
- Отсутствие сложностей с initrd

### 🎮 Gaming Ready
- Steam предустановлен
- NVIDIA VAAPI для hardware decode
- 32-bit библиотеки
- Оптимизация для низкой задержки

### 🖥️ UWQHD оптимизация
- Правильный DPI scaling
- Оптимизированные шрифты
- Переменные окружения для высоких разрешений

## 📁 Структура файлов

```
├── flake.nix                    # Основной flake с зависимостями
├── configuration.nix            # Системная конфигурация NixOS  
├── home.nix                     # Пользовательская конфигурация (Home Manager)
├── hardware-configuration.nix   # Автогенерируемая конфигурация железа
├── nixos-installation-guide.md  # Полная инструкция по установке
├── test-config.sh              # Скрипт для тестирования конфигурации
└── README.md                   # Этот файл
```

## 🚀 Быстрый старт

### 3 способа установки:

#### 1. 🤖 Автоматизированная установка
```bash
# С LUKS шифрованием (сложнее)
sudo ./automated-install.sh           # Русский
sudo ./automated-install-en.sh        # English

# БЕЗ шифрования (проще, рекомендуется)
sudo ./automated-install-no-luks.sh    # Русский
sudo ./automated-install-no-luks-en.sh # English
```

#### 2. 🔧 Полуавтоматизированная (рекомендуется)
```bash
# С LUKS шифрованием (сложнее)
sudo ./semi-automated-install.sh      # Русский
sudo ./semi-automated-install-en.sh   # English

# БЕЗ шифрования (проще, рекомендуется)
sudo ./semi-automated-install-no-luks.sh    # Русский
sudo ./semi-automated-install-no-luks-en.sh # English
```

#### 3. 📖 Ручная установка
Следуйте [подробной инструкции](nixos-installation-guide.md)

#### 🔧 Проблемы с кириллицей в TTY?
```bash
sudo ./fix-tty-encoding.sh
```

#### 🚨 Проблемы загрузки после установки?
```bash
# Русский интерфейс
sudo ./fix-boot-luks.sh

# English interface
sudo ./fix-boot-luks-en.sh
```

**Подробности**: [INSTALLATION.md](INSTALLATION.md) | [BOOT-TROUBLESHOOTING.md](BOOT-TROUBLESHOOTING.md)

### Тестирование конфигурации
```bash
chmod +x test-config.sh
./test-config.sh
```

## 🔧 Управление системой

```bash
# Пересборка системы
sudo nixos-rebuild switch --flake /etc/nixos#PC-NixOS

# Обновление зависимостей
sudo nix flake update /etc/nixos

# Очистка старых поколений
sudo nix-collect-garbage -d
```

## 📋 Включенные программы

### Системные
- Kitty (терминал)
- Firefox (браузер)
- Waybar (панель)
- Wofi (launcher)

### Development
- Neovim + Vim
- Git с настройками
- GCC, Make, CMake
- Python3

### Мультимедиа
- PipeWire (аудио)
- Grim + Slurp (скриншоты)
- NVIDIA декодирование

## ⚙️ Горячие клавиши Hyprland

- `Super + Q` - Терминал (Kitty)
- `Super + C` - Закрыть окно
- `Super + M` - Выход из Hyprland
- `Super + R` - Launcher (Wofi)
- `Super + V` - Плавающий режим
- `Super + 1-5` - Переключение рабочих столов
- `Super + Shift + 1-5` - Перемещение на рабочий стол

## 🔍 Мониторинг системы

```bash
# Информация о системе
fastfetch

# Мониторинг ресурсов
btop

# Статус NVIDIA
nvidia-smi

# Статус Hyprland
hyprctl monitors
```

## 🆘 Поддержка

- [Полная инструкция по установке](nixos-installation-guide.md)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Hyprland Wiki](https://wiki.hyprland.org/)

## 📝 Лицензия

MIT License - используйте свободно для своих проектов.