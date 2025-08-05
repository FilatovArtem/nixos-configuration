# 🚨 Устранение проблем загрузки NixOS с LUKS

## Проблема: "An error occurred in stage 1 of the boot process"

Эта ошибка возникает когда NixOS не может смонтировать корневую файловую систему из-за проблем с LUKS конфигурацией.

## 🔧 Быстрое исправление

### 1. Загрузитесь с NixOS Live USB

### 2. Запустите скрипт исправления:
```bash
# Скачайте файлы конфигурации (если их нет)
nix-shell -p git
git clone https://github.com/your-username/nixos-configuration.git
cd nixos-configuration

# Запустите исправление
chmod +x fix-boot-luks.sh
sudo ./fix-boot-luks.sh
```

## 🔍 Ручное исправление

### Шаг 1: Откройте LUKS и смонтируйте систему
```bash
# Найдите LUKS раздел
lsblk
blkid | grep crypto_LUKS

# Откройте LUKS (обычно /dev/nvme0n1p2 или /dev/sda2)
sudo cryptsetup luksOpen /dev/nvme0n1p2 nixos-root

# Активируйте LVM
sudo vgchange -ay

# Смонтируйте файловые системы
sudo mount /dev/vg0/root /mnt
sudo mount /dev/nvme0n1p1 /mnt/boot  # EFI раздел
sudo mount /dev/vg0/home /mnt/home   # если есть
```

### Шаг 2: Проверьте конфигурацию LUKS
```bash
# Проверьте текущую конфигурацию
cat /mnt/etc/nixos/configuration.nix | grep -A 5 "luks"

# Должно быть примерно так:
# boot.initrd.luks.devices."nixos-root" = {
#   device = "/dev/nvme0n1p2";  # ваш LUKS раздел
#   preLVM = true;
# };
```

### Шаг 3: Исправьте конфигурацию (если нужно)
```bash
# Отредактируйте конфигурацию
sudo nano /mnt/etc/nixos/configuration.nix

# Убедитесь что есть правильная LUKS конфигурация:
```

Добавьте в `configuration.nix`:
```nix
{
  imports = [ ./hardware-configuration.nix ];

  # ОБЯЗАТЕЛЬНО: LUKS конфигурация
  boot.initrd.luks.devices."nixos-root" = {
    device = "/dev/nvme0n1p2";  # ЗАМЕНИТЕ на ваш LUKS раздел
    preLVM = true;
  };

  # ОБЯЗАТЕЛЬНО: Модули ядра для LUKS + LVM
  boot.initrd.kernelModules = [ "dm-crypt" "dm-mod" "dm-snapshot" ];
  
  # Остальная конфигурация...
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # ... остальные настройки
}
```

### Шаг 4: Пересоберите систему
```bash
cd /mnt/etc/nixos

# Если используете flake:
sudo nixos-install --root /mnt --flake .#PC-NixOS --no-root-passwd

# Если стандартную конфигурацию:
sudo nixos-install --root /mnt --no-root-passwd
```

### Шаг 5: Размонтируйте и перезагрузитесь
```bash
sudo umount -R /mnt
sudo vgchange -a n vg0
sudo cryptsetup luksClose nixos-root
reboot
```

## ❓ Наиболее частые причины проблемы

### 1. ❌ Неправильное LUKS устройство
**Проблема**: В `configuration.nix` указан неправильный путь к LUKS разделу
```nix
# НЕПРАВИЛЬНО - устройство не существует
device = "/dev/sda2";

# ПРАВИЛЬНО - проверьте lsblk
device = "/dev/nvme0n1p2";
```

### 2. ❌ Отсутствует `preLVM = true`
**Проблема**: LUKS должен открываться ДО инициализации LVM
```nix
# ПРАВИЛЬНО
boot.initrd.luks.devices."nixos-root" = {
  device = "/dev/nvme0n1p2";
  preLVM = true;  # ОБЯЗАТЕЛЬНО для LVM поверх LUKS
};
```

### 3. ❌ Отсутствуют модули ядра
**Проблема**: initrd не содержит модули для LUKS и LVM
```nix
# Добавьте в configuration.nix
boot.initrd.kernelModules = [ "dm-crypt" "dm-mod" "dm-snapshot" ];
```

### 4. ❌ Неправильное имя LUKS устройства
**Проблема**: Имя устройства не совпадает с именем в crypttab
```nix
# Имя должно совпадать с тем, что использовалось при установке
boot.initrd.luks.devices."nixos-root" = {  # "nixos-root" - это имя
  device = "/dev/nvme0n1p2";
  preLVM = true;
};
```

## 🔄 Проверка после исправления

После перезагрузки система должна:
1. ✅ Запросить пароль LUKS на раннем этапе загрузки
2. ✅ Успешно смонтировать корневую файловую систему
3. ✅ Продолжить нормальную загрузку до рабочего стола

## 🆘 Если проблема не решается

### Проверьте hardware-configuration.nix:
```bash
cat /mnt/etc/nixos/hardware-configuration.nix
```

Убедитесь что там правильно указаны:
- `fileSystems."/"`
- `fileSystems."/boot"` 
- `swapDevices`

### Логи загрузки:
После неудачной загрузки вы можете посмотреть логи:
```bash
# В emergency shell или после загрузки с live USB
journalctl -xb
dmesg | grep -i luks
```

### Альтернативное решение:
Если ничего не помогает, можно переустановить систему используя исправленные скрипты:
- `automated-install-fixed.sh`
- `semi-automated-install-fixed.sh`

## 📞 Дополнительная помощь

Если проблема не решается:
1. Проверьте [NixOS Manual - LUKS](https://nixos.org/manual/nixos/stable/index.html#sec-luks)
2. Спросите в [NixOS Discourse](https://discourse.nixos.org/)
3. Создайте issue в репозитории с логами ошибок