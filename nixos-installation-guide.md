# Полная инструкция по установке NixOS с оптимизированной конфигурацией

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

## 7. Установка оптимизированной конфигурации

### 7.1 Клонирование репозитория с конфигурацией
```bash
# Убедиться что git доступен
nix-shell -p git

# Перейти в директорию NixOS
cd /mnt/etc/nixos

# Удалить сгенерированный configuration.nix (оставим только hardware-configuration.nix)
sudo rm configuration.nix

# Клонировать оптимизированную конфигурацию
sudo git clone https://github.com/your-username/nixos-configuration.git temp-config

# Переместить файлы в правильное место
sudo cp temp-config/flake.nix /mnt/etc/nixos/
sudo cp temp-config/configuration.nix /mnt/etc/nixos/
sudo cp temp-config/home.nix /mnt/etc/nixos/
sudo rm -rf temp-config

# Проверить что файлы скопировались
ls -la /mnt/etc/nixos/
```

### 7.2 Проверка и адаптация конфигурации
```bash
# Проверить содержимое hardware-configuration.nix
cat /mnt/etc/nixos/hardware-configuration.nix

# Убедиться что configuration.nix импортирует hardware-configuration.nix
head -10 /mnt/etc/nixos/configuration.nix

# Адаптировать LUKS устройство если нужно
sudo nano /mnt/etc/nixos/configuration.nix
# Найти строку: device = "/dev/nvme0n1p2";
# Убедиться что это правильный раздел
```

### 7.3 Тестирование конфигурации
```bash
# Перейти в директорию конфигурации
cd /mnt/etc/nixos

# Проверить синтаксис flake.nix
nix flake check

# Попробовать собрать конфигурацию (dry-run)
nixos-rebuild build --flake .#PC-NixOS --dry-run

# Финальная сборка для проверки
nixos-rebuild build --flake .#PC-NixOS

# Если сборка успешна
echo "✅ Конфигурация готова к установке!"
```

## 8. Установка NixOS

### 8.1 Финальная проверка
```bash
# Проверить наличие всех файлов
ls -la /mnt/etc/nixos/

# Убедиться что все необходимые файлы присутствуют
for file in flake.nix configuration.nix home.nix hardware-configuration.nix; do
    if [ -f "$file" ]; then
        echo "✅ $file найден"
    else
        echo "❌ $file отсутствует!"
        exit 1
    fi
done
```

### 8.2 Установка системы
```bash
# Установить NixOS с оптимизированной конфигурацией
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
fastfetch
btop
nvidia-smi

# Обновить систему
sudo nix flake update /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#PC-NixOS

# Проверить что Hyprland работает
echo $XDG_CURRENT_DESKTOP  # Должно показать Hyprland
```

## 12. Дополнительные настройки

### 12.1 Настройка мониторов в Hyprland
```bash
# Проверить доступные мониторы
hyprctl monitors

# Если нужно изменить настройки монитора
sudo nvim /etc/nixos/home.nix
# Найти секцию monitor и настроить под ваш монитор
```

### 12.2 Установка дополнительных программ
```bash
# Добавить программы в home.nix
sudo nvim /etc/nixos/home.nix

# Или установить временно
nix-shell -p <package-name>
```

### 12.3 Gaming настройки
Уже включены:
- ✅ Steam
- ✅ NVIDIA оптимизации
- ✅ 32-bit библиотеки
- ✅ Низкая задержка звука

### 12.4 Резервные копии конфигурации
```bash
# Создать git репозиторий для отслеживания изменений
cd /etc/nixos
sudo git init
sudo git add .
sudo git commit -m "Initial optimized configuration"

# Добавить remote для backup
sudo git remote add origin https://github.com/your-username/nixos-config-backup.git
sudo git push -u origin main
```

## 13. Основные команды для управления

```bash
# Пересобрать систему
sudo nixos-rebuild switch --flake /etc/nixos#PC-NixOS

# Обновить flake зависимости
sudo nix flake update /etc/nixos

# Просмотреть поколения системы
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Откатиться к предыдущему поколению
sudo nixos-rebuild switch --rollback

# Очистить старые поколения
sudo nix-collect-garbage -d

# Оптимизировать Nix store
sudo nix-store --optimise
```

## Особенности оптимизированной конфигурации

### 🎯 Оптимизации для вашего железа:
- **Intel i5-11600** - термальные настройки, микрокод
- **RTX 4070** - производственный драйвер, VAAPI, низкая задержка
- **UWQHD 175Hz** - правильный DPI, scaling, переменные окружения
- **NVMe SSD** - TRIM, оптимизация файловой системы

### ⚡ Производительность:
- Автоматическая сборка мусора Nix
- Оптимизация ядра для игр
- Низкая задержка аудио (32 quantum)
- NVIDIA композитинг

### 🛡️ Безопасность:
- LUKS шифрование всего диска
- Firewall настроен
- SSH без пароля, только ключи
- Автоматические обновления безопасности

### 🎮 Gaming Ready:
- Steam предустановлен
- 32-bit поддержка
- NVIDIA оптимизации
- Низкая задержка ввода

Эта конфигурация обеспечивает максимальную производительность и удобство для вашей системы!

## Устранение неполадок

### Если система не загружается
```bash
# Загрузитесь с live USB
# Откройте LUKS
sudo cryptsetup luksOpen /dev/nvme0n1p2 nixos-root

# Активируйте LVM
sudo vgchange -ay vg0

# Монтируйте и войдите
sudo mount /dev/vg0/root /mnt
sudo mount /dev/nvme0n1p1 /mnt/boot
sudo nixos-enter --root /mnt
```

### Если нет места на диске
```bash
# Очистка в emergency режиме
sudo nix-collect-garbage -d
sudo nix-store --optimise
df -h
```

### Если NVIDIA не работает
```bash
# Проверить драйвер
nvidia-smi
lsmod | grep nvidia

# Проверить настройки
cat /proc/driver/nvidia/version
```