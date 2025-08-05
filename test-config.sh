#!/usr/bin/env bash

# Скрипт для тестирования NixOS конфигурации

set -e

echo "🔍 Тестирование NixOS конфигурации..."

# Проверить наличие необходимых файлов
echo "📋 Проверка файлов..."
for file in flake.nix configuration.nix home.nix hardware-configuration.nix; do
    if [ -f "$file" ]; then
        echo "✅ $file найден"
    else
        echo "❌ $file отсутствует!"
        exit 1
    fi
done

# Проверить синтаксис flake
echo "🔧 Проверка синтаксиса flake..."
if nix flake check --no-build 2>&1; then
    echo "✅ Синтаксис flake правильный"
else
    echo "❌ Ошибки в flake.nix"
    exit 1
fi

# Попробовать показать конфигурацию
echo "📦 Проверка конфигурации..."
if nix eval .#nixosConfigurations.PC-NixOS.config.system.name 2>/dev/null; then
    echo "✅ Конфигурация доступна"
else
    echo "⚠️  Конфигурация может иметь проблемы"
fi

# Проверить что можно начать сборку
echo "🏗️  Проверка возможности сборки..."
if nix build .#nixosConfigurations.PC-NixOS.config.system.build.toplevel --dry-run 2>&1; then
    echo "✅ Сборка возможна"
else
    echo "❌ Проблемы со сборкой"
    exit 1
fi

echo "🎉 Конфигурация выглядит корректной!"
echo ""
echo "Следующие шаги:"
echo "1. Адаптируйте hardware-configuration.nix под ваше железо"
echo "2. Проверьте устройства в boot.initrd.luks.devices"
echo "3. Запустите: nixos-rebuild build --flake .#PC-NixOS"
echo "4. Если сборка успешна: nixos-install --flake .#PC-NixOS"