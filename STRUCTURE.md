# Структура проекта NixOS Configuration

## 📁 Актуальные файлы

### 🔧 Основные конфигурационные файлы
- **`flake.nix`** - Основной flake с зависимостями и inputs
- **`configuration.nix`** - Оптимизированная системная конфигурация NixOS
- **`home.nix`** - Пользовательская конфигурация через Home Manager
- **`hardware-configuration.nix`** - Автогенерируемая конфигурация железа

### 📚 Документация
- **`README.md`** - Основная информация о проекте
- **`nixos-installation-guide.md`** - Полная пошаговая инструкция по установке
- **`INSTALLATION.md`** - Сравнение методов установки и быстрый старт
- **`STRUCTURE.md`** - Этот файл с описанием структуры

### 🛠️ Утилиты и скрипты
- **`automated-install.sh`** - Полностью автоматизированный установщик
- **`semi-automated-install.sh`** - Полуавтоматизированный установщик (рекомендуется)
- **`test-config.sh`** - Скрипт для тестирования конфигурации
- **`.gitignore`** - Исключения для Git

## 🎯 Особенности конфигурации

### Оптимизирована для:
- Intel i5-11600 + NVIDIA RTX 4070
- UWQHD монитор 3440x1440 @ 175Hz
- NVMe SSD с LUKS шифрованием
- Gaming и high-performance задачи

### Включает:
- ✅ Hyprland compositor
- ✅ NVIDIA production драйвер
- ✅ PipeWire с низкой задержкой
- ✅ Steam и gaming оптимизации
- ✅ Автоматический Nix garbage collection
- ✅ Полное LUKS шифрование

## 🚀 Использование

1. **Тестирование**: `./test-config.sh`
2. **Установка**: Следуйте `nixos-installation-guide.md`
3. **Управление**: `sudo nixos-rebuild switch --flake .#PC-NixOS`

## 📋 Размеры файлов
- `configuration.nix`: 7.1KB (299 строк) - расширенная системная конфигурация
- `home.nix`: 2.9KB (142 строки) - пользовательские настройки
- `flake.nix`: 988B (39 строк) - минималистичный flake
- `nixos-installation-guide.md`: 12KB (414 строк) - подробная инструкция

Все файлы оптимизированы и готовы к использованию!