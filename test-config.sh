#!/usr/bin/env bash

# Test script for NixOS configuration without LUKS encryption

set -e

echo "🔍 Testing NixOS configuration WITHOUT LUKS..."
echo "═══════════════════════════════════════════════════════"

# Проверить наличие необходимых файлов
echo "📋 Проверка структуры файлов..."
required_files=("flake.nix" "configuration.nix" "home.nix" "hardware-configuration.nix")
missing_files=()

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file найден"
    else
        echo "❌ $file отсутствует!"
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -ne 0 ]; then
    echo ""
    echo "💥 Критическая ошибка: отсутствуют обязательные файлы:"
    printf '   - %s\n' "${missing_files[@]}"
    exit 1
fi

echo ""

# Проверить размеры файлов
echo "📊 Информация о файлах:"
for file in "${required_files[@]}"; do
    size=$(du -h "$file" | cut -f1)
    lines=$(wc -l < "$file")
    echo "   $file: $size ($lines строк)"
done

echo ""

# Проверить синтаксис flake
echo "🔧 Проверка синтаксиса flake..."
if nix flake check --no-build 2>&1; then
    echo "✅ Синтаксис flake корректный"
else
    echo "❌ Ошибки в flake.nix"
    echo "   Попробуйте: nix flake check --show-trace"
    exit 1
fi

echo ""

# Проверить метаданные flake
echo "📦 Информация о flake:"
if nix flake metadata . 2>/dev/null; then
    echo "✅ Метаданные flake доступны"
else
    echo "⚠️  Проблемы с метаданными flake"
fi

echo ""

# Проверить доступность конфигурации
echo "🎯 Проверка конфигурации NixOS..."
if nix eval .#nixosConfigurations.PC-NixOS.config.system.name 2>/dev/null >/dev/null; then
    echo "✅ Конфигурация PC-NixOS доступна"
    
    # Показать базовую информацию о конфигурации
    echo "   Информация о системе:"
    system_name=$(nix eval --raw .#nixosConfigurations.PC-NixOS.config.system.name 2>/dev/null || echo "unknown")
    state_version=$(nix eval --raw .#nixosConfigurations.PC-NixOS.config.system.stateVersion 2>/dev/null || echo "unknown")
    echo "   - Имя системы: $system_name"
    echo "   - Версия состояния: $state_version"
else
    echo "❌ Конфигурация PC-NixOS недоступна"
    exit 1
fi

echo ""

# Проверить возможность сборки
echo "🏗️  Проверка возможности сборки..."
if nix build .#nixosConfigurations.PC-NixOS.config.system.build.toplevel --dry-run 2>&1 >/dev/null; then
    echo "✅ Dry-run сборки успешен"
else
    echo "❌ Проблемы с dry-run сборкой"
    echo "   Запустите: nix build .#nixosConfigurations.PC-NixOS.config.system.build.toplevel --dry-run"
    exit 1
fi

echo ""

# Проверить специфичные для конфигурации компоненты
echo "🔍 Проверка компонентов конфигурации..."

# Проверить Home Manager
if grep -q "home-manager" flake.nix; then
    echo "✅ Home Manager интегрирован"
else
    echo "⚠️  Home Manager может отсутствовать в flake"
fi

# Проверить Hyprland
if grep -q "hyprland" flake.nix; then
    echo "✅ Hyprland включен в inputs"
else
    echo "⚠️  Hyprland может отсутствовать"
fi

# Проверить NVIDIA конфигурацию
if grep -q "nvidia" configuration.nix; then
    echo "✅ NVIDIA драйверы настроены"
else
    echo "⚠️  NVIDIA конфигурация может отсутствовать"
fi

# Проверить LUKS конфигурацию
if grep -q "luks" configuration.nix; then
    echo "✅ LUKS шифрование настроено"
else
    echo "⚠️  LUKS конфигурация может отсутствовать"
fi

echo ""

# Проверить hardware-configuration.nix
echo "🔧 Анализ hardware-configuration.nix..."
if grep -q "fileSystems" hardware-configuration.nix; then
    echo "✅ Файловые системы определены"
    fs_count=$(grep -c "fileSystems\." hardware-configuration.nix)
    echo "   Найдено файловых систем: $fs_count"
else
    echo "❌ Файловые системы не определены в hardware-configuration.nix"
fi

if grep -q "swapDevices" hardware-configuration.nix; then
    echo "✅ Swap устройства определены"
else
    echo "⚠️  Swap устройства могут не быть определены"
fi

echo ""

# Финальные рекомендации
echo "🎉 Тестирование завершено!"
echo "═══════════════════════════════"

echo ""
echo "📋 Следующие шаги:"
echo ""

if [ -f "/mnt/etc/nixos/hardware-configuration.nix" ]; then
    echo "🚀 Готово к установке:"
    echo "   sudo nixos-install --flake .#PC-NixOS"
else
    echo "⚙️  Для установки выполните:"
    echo "   1. Разметьте диски согласно инструкции"
    echo "   2. Сгенерируйте hardware-configuration.nix:"
    echo "      nixos-generate-config --root /mnt"
    echo "   3. Скопируйте эту конфигурацию в /mnt/etc/nixos/"
    echo "   4. Запустите: nixos-install --flake .#PC-NixOS"
fi

echo ""
echo "🔧 Для тестовой сборки:"
echo "   nixos-rebuild build --flake .#PC-NixOS"
echo ""
echo "📚 Дополнительная информация:"
echo "   - Полная инструкция: nixos-installation-guide.md"
echo "   - Проверка с подробностями: nix flake check --show-trace"
echo "   - Показать конфигурацию: nix eval .#nixosConfigurations.PC-NixOS.config.environment.systemPackages"

echo ""
echo "✨ Конфигурация готова к использованию!"