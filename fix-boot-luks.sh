#!/usr/bin/env bash

# Скрипт для исправления проблем загрузки с LUKS после установки NixOS
# Используйте после загрузки с live USB

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}INFO: $1${NC}"; }
success() { echo -e "${GREEN}SUCCESS: $1${NC}"; }
warning() { echo -e "${YELLOW}WARNING: $1${NC}"; }
error() { echo -e "${RED}ERROR: $1${NC}"; }

if [ "$EUID" -ne 0 ]; then
    error "Запустите с sudo"
    exit 1
fi

echo "════════════════════════════════════════════════════════════════"
echo "🔧 Исправление проблем загрузки NixOS с LUKS"
echo "════════════════════════════════════════════════════════════════"
echo

# Шаг 1: Поиск LUKS раздела
info "Шаг 1: Поиск LUKS разделов"
echo "Доступные диски:"
lsblk
echo

echo "Поиск LUKS разделов..."
LUKS_PARTITIONS=$(blkid | grep "TYPE=\"crypto_LUKS\"" | cut -d: -f1 || true)

if [ -z "$LUKS_PARTITIONS" ]; then
    error "LUKS разделы не найдены! Проверьте установку."
    exit 1
fi

echo "Найдены LUKS разделы:"
echo "$LUKS_PARTITIONS"
echo

# Выбор LUKS раздела
if [ $(echo "$LUKS_PARTITIONS" | wc -l) -eq 1 ]; then
    LUKS_DEVICE="$LUKS_PARTITIONS"
    info "Автоматически выбран: $LUKS_DEVICE"
else
    echo "Выберите LUKS раздел:"
    echo "$LUKS_PARTITIONS" | nl
    read -p "Введите номер: " NUM
    LUKS_DEVICE=$(echo "$LUKS_PARTITIONS" | sed -n "${NUM}p")
fi

if [ -z "$LUKS_DEVICE" ]; then
    error "LUKS устройство не выбрано"
    exit 1
fi

info "Используется LUKS устройство: $LUKS_DEVICE"

# Шаг 2: Открытие LUKS и монтирование
info "Шаг 2: Открытие LUKS контейнера"
echo "Введите пароль для расшифровки диска:"

if ! cryptsetup luksOpen "$LUKS_DEVICE" nixos-root; then
    error "Не удалось открыть LUKS контейнер. Проверьте пароль."
    exit 1
fi

success "LUKS контейнер открыт"

# Активация LVM
info "Активация LVM..."
vgchange -ay || true

# Проверка LVM томов
if [ ! -b "/dev/vg0/root" ]; then
    error "LVM том /dev/vg0/root не найден"
    lvs
    exit 1
fi

# Монтирование файловых систем
info "Шаг 3: Монтирование файловых систем"

mount /dev/vg0/root /mnt

# Поиск EFI раздела
EFI_PARTITION=""
for part in /dev/nvme0n1p1 /dev/sda1 /dev/vda1; do
    if [ -b "$part" ] && file -s "$part" | grep -q "FAT"; then
        EFI_PARTITION="$part"
        break
    fi
done

if [ -z "$EFI_PARTITION" ]; then
    warning "EFI раздел не найден автоматически"
    lsblk
    read -p "Введите EFI раздел (например /dev/nvme0n1p1): " EFI_PARTITION
fi

mkdir -p /mnt/boot
mount "$EFI_PARTITION" /mnt/boot

if [ -b "/dev/vg0/home" ]; then
    mkdir -p /mnt/home
    mount /dev/vg0/home /mnt/home
fi

success "Файловые системы смонтированы"

# Шаг 4: Проверка и исправление конфигурации
info "Шаг 4: Проверка конфигурации NixOS"

if [ ! -f "/mnt/etc/nixos/configuration.nix" ]; then
    error "Конфигурация NixOS не найдена в /mnt/etc/nixos/"
    exit 1
fi

info "Текущая LUKS конфигурация:"
grep -A 5 "boot.initrd.luks.devices" /mnt/etc/nixos/configuration.nix || echo "LUKS конфигурация не найдена!"

echo
warning "Проверяем правильность LUKS устройства в конфигурации..."

# Получаем UUID LUKS устройства
LUKS_UUID=$(blkid -s UUID -o value "$LUKS_DEVICE")
info "UUID LUKS устройства: $LUKS_UUID"

# Проверяем конфигурацию
if grep -q "boot.initrd.luks.devices" /mnt/etc/nixos/configuration.nix; then
    if grep -q "$LUKS_DEVICE\|$LUKS_UUID" /mnt/etc/nixos/configuration.nix; then
        success "LUKS устройство правильно настроено в конфигурации"
    else
        warning "LUKS устройство в конфигурации не соответствует реальному!"
        echo "Исправляем конфигурацию..."
        
        # Создаем backup
        cp /mnt/etc/nixos/configuration.nix /mnt/etc/nixos/configuration.nix.backup
        
        # Исправляем устройство
        sed -i "s|device = \".*\";|device = \"$LUKS_DEVICE\";|" /mnt/etc/nixos/configuration.nix
        success "Конфигурация исправлена"
    fi
else
    error "LUKS конфигурация отсутствует в configuration.nix!"
    echo "Добавляем LUKS конфигурацию..."
    
    # Находим строку с imports и добавляем LUKS конфигурацию после неё
    sed -i '/imports = \[/a\\n  # LUKS configuration\n  boot.initrd.luks.devices."nixos-root" = {\n    device = "'$LUKS_DEVICE'";\n    preLVM = true;\n  };' /mnt/etc/nixos/configuration.nix
    
    success "LUKS конфигурация добавлена"
fi

# Шаг 5: Проверка и добавление необходимых модулей ядра
info "Шаг 5: Проверка модулей ядра"

if ! grep -q "boot.initrd.kernelModules" /mnt/etc/nixos/configuration.nix; then
    info "Добавляем необходимые модули ядра..."
    sed -i '/boot.initrd.luks.devices/a\\n  # Required kernel modules for LUKS + LVM\n  boot.initrd.kernelModules = [ "dm-crypt" "dm-mod" "dm-snapshot" "dm-raid" ];' /mnt/etc/nixos/configuration.nix
fi

# Шаг 6: Пересборка системы
info "Шаг 6: Пересборка загрузчика"

cd /mnt/etc/nixos

# Проверяем есть ли flake
if [ -f "flake.nix" ]; then
    info "Пересборка с flake конфигурацией..."
    nixos-install --root /mnt --flake .#PC-NixOS --no-root-passwd
else
    info "Пересборка со стандартной конфигурацией..."
    nixos-install --root /mnt --no-root-passwd
fi

success "Система пересобрана"

echo
echo "════════════════════════════════════════════════════════════════"
echo "✅ Исправление завершено!"
echo
echo "📋 Что было исправлено:"
echo "• Проверена и исправлена LUKS конфигурация"
echo "• Добавлены необходимые модули ядра"  
echo "• Пересобран initrd с правильными настройками"
echo
echo "🔄 Следующие шаги:"
echo "1. Извлеките live USB"
echo "2. Перезагрузите систему"
echo "3. Введите пароль LUKS при загрузке"
echo "4. Система должна загрузиться нормально"
echo "════════════════════════════════════════════════════════════════"

# Размонтирование
info "Размонтирование файловых систем..."
umount -R /mnt || true
vgchange -a n vg0 || true
cryptsetup luksClose nixos-root || true

warning "Перезагрузите систему и проверьте загрузку"
read -p "Перезагрузить сейчас? (y/N): " REBOOT
if [[ $REBOOT =~ ^[Yy]$ ]]; then
    reboot
fi