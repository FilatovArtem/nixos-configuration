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

## 7. Скачивание и интеграция конфигурации с GitHub

### 7.1 Установка Git и создание рабочей директории
```bash
# Убедиться что git доступен в live-среде
nix-shell -p git

# Перейти в директорию NixOS
cd /mnt/etc/nixos

# Удалить сгенерированный configuration.nix (оставим только hardware-configuration.nix)
sudo rm configuration.nix
```

### 7.2 Клонирование конфигурации с GitHub
```bash
# Клонировать вашу конфигурацию (замените на ваш репозиторий)
sudo git clone https://github.com/FilatovArtem/nixos-configuration.git temp-config

# Переместить файлы в правильное место
sudo cp temp-config/* /mnt/etc/nixos/
sudo rm -rf temp-config

# Проверить что файлы скопировались
ls -la /mnt/etc/nixos/
```

### 7.3 Интеграция с hardware-configuration.nix
```bash
# Проверить содержимое hardware-configuration.nix
cat /mnt/etc/nixos/hardware-configuration.nix

# Убедиться что в configuration.nix есть импорт hardware-configuration.nix
head -20 /mnt/etc/nixos/configuration.nix
```

### 7.4 Адаптация конфигурации под вашу систему
```bash
# Отредактировать configuration.nix для интеграции с hardware-configuration.nix
sudo nano /mnt/etc/nixos/configuration.nix
```

**Убедитесь что в вашем `configuration.nix` есть:**
```nix
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix  # ← Этот импорт обязателен!
  ];
  
  # Адаптируйте LUKS настройки под ваши разделы
  boot.initrd.luks.devices."nixos-root" = {
    device = "/dev/nvme0n1p2";  # ← Проверьте что это правильный раздел
    preLVM = true;
    allowDiscards = true;
  };
  
  # Остальная конфигурация...
}
```

### 7.5 Проверка конфигурации
```bash
# Перейти в директорию конфигурации
cd /mnt/etc/nixos

# Проверить синтаксис flake.nix
nix flake check

# Если есть ошибки - исправить их
# nix flake check --show-trace  # для подробной диагностики

# Попробовать собрать конфигурацию (dry-run)
nixos-rebuild build --flake .#PC-NixOS --dry-run

# Проверить что все импорты работают
nix eval .#nixosConfigurations.PC-NixOS.config.system.build.toplevel
```

### 7.6 Финальная сборка для проверки
```bash
# Собрать конфигурацию без установки
nixos-rebuild build --flake .#PC-NixOS

# Если сборка успешна, посмотреть что получилось
ls -la result/

# Проверить размер результата
du -sh result/
```

### 7.7 Создание backup сгенерированной конфигурации
```bash
# Сохранить hardware-configuration.nix в git репозиторий
sudo cp hardware-configuration.nix /tmp/hardware-backup.nix

# Если нужно создать git репозиторий в конфигурации
cd /mnt/etc/nixos
sudo git init
sudo git add .
sudo git commit -m "Initial configuration with hardware-configuration.nix"

# Можно добавить remote для резервных копий
# sudo git remote add origin https://github.com/your-username/nixos-config-backup.git
```

### 7.8 Альтернативный метод - интеграция через скрипт
Создайте скрипт для автоматической интеграции:

```bash
sudo tee /mnt/etc/nixos/integrate-hardware.sh << 'EOF'
#!/usr/bin/env bash

# Скрипт интеграции hardware-configuration.nix с GitHub конфигурацией

set -e

HARDWARE_FILE="/mnt/etc/nixos/hardware-configuration.nix"
CONFIG_FILE="/mnt/etc/nixos/configuration.nix"

echo "🔧 Интеграция hardware-configuration.nix..."

# Проверить что hardware-configuration.nix существует
if [ ! -f "$HARDWARE_FILE" ]; then
    echo "❌ Файл $HARDWARE_FILE не найден!"
    exit 1
fi

# Извлечь важные параметры из hardware-configuration.nix
LUKS_DEVICE=$(grep -o '/dev/[^"]*' "$HARDWARE_FILE" | head -1 || echo "/dev/nvme0n1p2")
FILESYSTEMS=$(grep -A 10 'fileSystems\.' "$HARDWARE_FILE" || true)
SWAP_DEVICES=$(grep -A 5 'swapDevices' "$HARDWARE_FILE" || true)

echo "📋 Найденные параметры:"
echo "   LUKS устройство: $LUKS_DEVICE"
echo "   Файловые системы обнаружены: $(echo "$FILESYSTEMS" | wc -l) строк"
echo "   Swap устройства обнаружены: $(echo "$SWAP_DEVICES" | wc -l) строк"

# Проверить что imports содержит hardware-configuration.nix
if ! grep -q "hardware-configuration.nix" "$CONFIG_FILE"; then
    echo "⚠️  Добавляю импорт hardware-configuration.nix в configuration.nix"
    sudo sed -i '/imports = \[/a\    ./hardware-configuration.nix' "$CONFIG_FILE"
fi

# Обновить LUKS устройство в configuration.nix если найдено
if [ -n "$LUKS_DEVICE" ]; then
    echo "🔐 Обновляю LUKS устройство на $LUKS_DEVICE"
    sudo sed -i "s|device = \"/dev/[^\"]*\";|device = \"$LUKS_DEVICE\";|g" "$CONFIG_FILE"
fi

echo "✅ Интеграция завершена!"
echo "🔨 Запуск проверки конфигурации..."

# Проверка конфигурации
cd /mnt/etc/nixos
nix flake check

echo "🏗️  Запуск тестовой сборки..."
nixos-rebuild build --flake .#PC-NixOS

echo "🎉 Конфигурация готова к установке!"
EOF

# Сделать скрипт исполняемым и запустить
sudo chmod +x /mnt/etc/nixos/integrate-hardware.sh
sudo /mnt/etc/nixos/integrate-hardware.sh
```

## 8. Установка NixOS

После успешной интеграции конфигурации можно приступать к установке:

```bash
# Перейти в директорию конфигурации
cd /mnt/etc/nixos

# Финальная проверка перед установкой
echo "🔍 Проверка файлов конфигурации..."
ls -la /mnt/etc/nixos/

# Убедиться что все необходимые файлы присутствуют
if [ ! -f "flake.nix" ]; then echo "❌ flake.nix отсутствует!"; exit 1; fi
if [ ! -f "configuration.nix" ]; then echo "❌ configuration.nix отсутствует!"; exit 1; fi
if [ ! -f "hardware-configuration.nix" ]; then echo "❌ hardware-configuration.nix отсутствует!"; exit 1; fi

echo "✅ Все файлы присутствуют"

# Установить NixOS с вашей конфигурацией
echo "🚀 Начинаю установку NixOS..."
sudo nixos-install --flake .#PC-NixOS

# При успешной установке система может попросить установить пароль root
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