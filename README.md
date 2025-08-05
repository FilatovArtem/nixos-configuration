# 🎮 NixOS Gaming Configuration

Простая и надежная конфигурация NixOS для геймеров с NVIDIA RTX 4070 и UWQHD монитором.

## 🖥️ Целевая система
- **CPU**: Intel i5-11600
- **GPU**: NVIDIA RTX 4070  
- **Monitor**: UWQHD 3440x1440 @ 175Hz
- **Storage**: NVMe 500GB без шифрования (простая установка)
- **Network**: Ethernet

## ✨ Основные особенности

### 🎯 Производительность
- Hyprland compositor для максимальной производительности
- NVIDIA производственный драйвер с оптимизациями
- Низкая задержка аудио (PipeWire)
- Автоматическая оптимизация Nix store

### 🛡️ Простота установки
- **БЕЗ LUKS шифрования** - простая загрузка без паролей
- Автоматическая загрузка с установленными паролями
- Отсутствие сложностей с initrd

### 🎮 Gaming Ready
- Steam предустановлен
- NVIDIA VAAPI для hardware decode
- 32-bit библиотеки
- GameMode для оптимизации производительности
- Низкая задержка аудио (32 quantum)

### 🖥️ UWQHD Оптимизации
- DPI scaling для 34" мониторов
- Hyprland настроен для 3440x1440@175Hz
- Шрифты JetBrains Mono + Nerd Fonts

## 📁 Структура проекта

```
nixos-configuration/
├── semi-automated-install-no-luks-en.sh  # 🚀 Основной скрипт установки
├── flake.nix                             # Flake конфигурация
├── configuration.nix                     # Системная конфигурация  
├── home.nix                              # Home Manager настройки
├── hardware-configuration.nix            # Аппаратная конфигурация
├── test-config.sh                        # Тестирование конфигурации
└── README.md                             # Этот файл
```

## 🚀 Быстрый старт

### 🔧 Полуавтоматическая установка (рекомендуется)

```bash
# 1. Загрузитесь с NixOS Live USB
# 2. Клонируйте репозиторий
nix-shell -p git
git clone https://github.com/your-username/nixos-configuration.git
cd nixos-configuration

# 3. Запустите установку
chmod +x semi-automated-install-no-luks-en.sh
sudo ./semi-automated-install-no-luks-en.sh
```

**Особенности:**
- ✅ **Проверки на каждом этапе** - безопасно
- ✅ **Контроль процесса** - можно остановиться и проверить
- ✅ **БЕЗ LUKS** - простая загрузка без проблем
- ✅ **Пошаговые подтверждения** 

## 🔐 Данные для входа

После установки система автоматически настроит:

**Пользователь:**
- Логин: `artfil-nixos`
- Пароль: `nixos123`

**Root:**
- Логин: `root`  
- Пароль: `root123`

⚠️ **Важно**: Смените пароли после первого входа:
```bash
passwd artfil-nixos
sudo passwd root
```

## 🛠️ Что включено

### 📦 Системные пакеты
- **Terminal**: kitty
- **Editor**: neovim  
- **Browser**: firefox
- **Compositor**: Hyprland + waybar + wofi
- **Gaming**: steam
- **Utils**: fastfetch, btop, ripgrep, fzf, eza, bat, yazi

### 🎵 Аудио система
- **PipeWire** с низкой задержкой (32 quantum)
- **ALSA/PulseAudio** совместимость
- **Bluetooth** поддержка

### 🖥️ Дисплей и графика
- **Hyprland** Wayland compositor
- **NVIDIA RTX 4070** производственный драйвер
- **Hardware acceleration** для видео
- **UWQHD** оптимизации

### ⌨️ Hyprland горячие клавиши
- `SUPER + Q` - Терминал (kitty)
- `SUPER + C` - Закрыть окно
- `SUPER + M` - Выход из Hyprland
- `SUPER + R` - Запустить приложение (wofi)
- `SUPER + V` - Переключить плавающий режим
- `SUPER + 1-5` - Переключение рабочих столов
- `ALT + SHIFT` - Переключение раскладки (EN/RU)

## 🔧 Управление системой

### 📝 Редактирование конфигурации
```bash
# Основная конфигурация
sudo nano /etc/nixos/configuration.nix

# Home Manager настройки  
sudo nano /etc/nixos/home.nix

# Применить изменения
sudo nixos-rebuild switch
```

### 🧹 Очистка системы
```bash
# Очистить старые поколения
nix-collect-garbage -d

# Оптимизировать store
sudo nix-store --optimise

# Перезагрузить для применения
sudo reboot
```

### 📊 Информация о системе
```bash
# Информация о системе
fastfetch

# Мониторинг ресурсов
btop

# GPU информация
nvidia-smi
```

## 🎯 Итоговая рекомендация

Используйте **полуавтоматическую установку** для надежного результата:

```bash
sudo ./semi-automated-install-no-luks-en.sh
```

**Почему именно эта версия?**
- ✅ **Надежность** - отсутствие проблем с LUKS
- ✅ **Простота** - автоматический вход в систему  
- ✅ **Контроль** - проверки на каждом этапе
- ✅ **Gaming готово** - все оптимизации включены
- ✅ **UWQHD оптимизации** - идеально для вашего монитора

После установки получите **полнофункциональную gaming систему** с Hyprland, Steam, и всеми необходимыми оптимизациями! 🚀