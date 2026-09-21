# Лабораторная работа №1 — Dual Boot: Windows 11 ARM + Arch Linux ARM

> **Контекст:** Apple M1 Pro, VMware Fusion, одна VM с одним диском.
> Windows 11 ARM64 уже установлена (72 ГБ), остальное место свободно под Arch.
> Уровень задания: **7–9** (Arch без упрощённых установщиков + Dual Boot).
>
> ⚠️ Архитектурный нюанс: на M1 Pro работает только **Arch Linux ARM**
> (порт archlinuxarm.org), а не официальный Arch x86_64. У него нет
> установочного ISO — система разворачивается вручную из tarball.
> **Согласовать с преподавателем!** Плюс: ручная установка без archinstall
> как раз соответствует требованию задания.

## Файлы

| Файл | Размер | Назначение |
|---|---|---|
| `ubuntu-26.04.1-desktop-arm64.iso` | ~3.9 ГБ | Live-система, из которой ставим Arch |
| `ArchLinuxARM-aarch64-latest.tar.gz` | 791 МБ | Корневая файловая система Arch |
| `Win11_25H2_Russian_Arm64.iso` | 6.8 ГБ | Уже отработал — винда стоит |

Оба файла лежат в `~/Downloads` на маке.

---

## Часть А. Подготовка (винда работает)

### Шаг 1. Хеш имени пользователя — сделать ДО всего остального

Требование задания: пользователь `User-<hash>` на **обеих** системах.

1. Открыть сайт **sordum.org** → Hash generator (или найти поиском «sordum hash generator»)
2. Ввести полное ФИО на русском: `Иванов Иван Иванович` (3 слова через пробел)
3. Выбрать алгоритм **JOAAT**
4. Получить 8 символов, например `b5759a48`
5. Имя пользователя: **`User-b5759a48`** (подставить свой хеш)

Записать и не терять — проверяется и в следующих лабах.

**Если пользователь на винде назван иначе** → создать нового:
Параметры → Учётные записи → Другие пользователи → Добавить пользователя
(локальная учётка, имя `User-<hash>`).

### Шаг 2. Перекинуть tarball на виндовый диск

1. Перетащить `ArchLinuxARM-aarch64-latest.tar.gz` из `~/Downloads` мака
   в окно винды (drag&drop работает, если стоят VMware Tools)
2. Положить в **`C:\temp\`** (создать папку). Путь — только латиница, без пробелов

Альтернатива, если drag&drop не работает:
- VMware → Settings → Sharing → включить shared folder с `~/Downloads`,
  затем внутри Ubuntu live смонтировать его
- Или скачать tarball заново прямо в Firefox из live-Ubuntu (790 МБ, ~10 мин)

### Шаг 3. Выключить винду и настроить VM

1. В винде: **Пуск → Завершение работы** (штатное, не «Shut Down» из меню VMware)
2. VM выключена → **Settings → Advanced → снять галку Enable UEFI Secure Boot**

   ⚠️ **Критично.** GRUB от Arch Linux ARM не подписан сертификатами
   Microsoft — с включённым Secure Boot он не загрузится никогда.

3. **Settings → CD/DVD** → «Choose a disc or disc image...» → выбрать
   `ubuntu-26.04.1-desktop-arm64.iso` → галка **Connect CD/DVD Drive** включена

### Шаг 4. Скриншоты в винде для отчёта (пока не поздно)

- `Win+R` → `msinfo32`: BIOS-режим = UEFI (скриншот)
- `Win+R` → `diskmgmt.msc`: разметка диска с нераспределённым местом (скриншот)

---

## Часть Б. Live-Ubuntu и разметка диска

### Шаг 5. Загрузка в Ubuntu

1. Включить VM
2. **Сразу** щёлкнуть мышкой в окно VM и жать **Esc** до появления EFI-меню
3. Выбрать **EFI VMware Virtual SATA CDROM Drive**
4. В меню Ubuntu выбрать **Try Ubuntu** — ⚠️ именно **Try**, не Install!
5. Дождаться рабочего стола

**Edge case: вместо Ubuntu грузится винда** → ISO не подключён или не стоит
галка Connect. Выключить VM, проверить Settings → CD/DVD, попробовать снова.

**Edge case: Esc не успеваешь** → перезагрузить VM (VM → Restart) и пробовать
снова; щёлкать в окно нужно в первые полсекунды после включения.

### Шаг 6. Разметка в GParted

1. Открыть **GParted** (поиск приложений)
2. Убедиться, что выбран диск `/dev/nvme0n1` (если дисков несколько — верхний справа)
3. Найти серую полосу **unallocated** (нераспределённая — под Arch)
4. ПКМ по unallocated → New → **linux-swap**, 4096 MiB → Add
5. ПКМ по оставшемуся unallocated → New → **ext4** (всё место) → Add
6. Зелёная галка **Apply** → подтвердить
7. **Скриншот до и после разметки** — в отчёт

⚠️ **Виндовые разделы не трогать!** Ничего не удалять, не сдвигать,
не менять размер. EFI-раздел винды (первый, ~260 МБ, FAT) — тем более.

**Edge case: unallocated нет, весь диск занят виндой** → вернуться в винду,
`diskmgmt.msc` → ПКМ по C: → Сжать том → освободить ≥ 30 ГБ.

**Edge case: GParted не даёт создать раздел (значок «!» на разделе)** →
у винды «журналируемые» операции на диске; убедиться, что винда выключена
штатно, а не из спящего режима.

---

## Часть В. Установка Arch (терминал)

Открыть Terminal: **Ctrl+Alt+T**. Команды вводить по кускам.

### Шаг 7. Определить разделы и смонтировать

```bash
sudo -i
lsblk -f
```

Сверить по размерам и типам:

```
nvme0n1p1  vfat   ~260M   ← EFI-раздел (общий с виндой)
nvme0n1p2  ...            ← MSR (винда, не трогать)
nvme0n1p3  ntfs   ~72G    ← винда C:
nvme0n1p4  ntfs   ~1G     ← recovery (винда, не трогать)
nvme0n1p5  swap     4G    ← новый swap
nvme0n1p6  ext4   остальное ← новый root
```

⚠️ **Номера p5/p6 могут быть другими** — сверять только по размеру и типу!
Дальше в командах подставлять свои номера.

```bash
mkfs.ext4 /dev/nvme0n1p6
mkswap /dev/nvme0n1p5
swapon /dev/nvme0n1p5

mount /dev/nvme0n1p6 /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
```

**Edge case: EFI-раздел не p1** → найти по типу vfat и размеру до 500 МБ
в выводе `lsblk -f`, монтировать его.

**Edge case: `mount: wrong fs type`** → перепроверить номер раздела.
Форматирование `mkfs.ext4` делать ТОЛЬКО на новом ext4-разделе,
не на виндовых NTFS!

### Шаг 8. Достать tarball с виндового диска

```bash
mkdir /media/win
mount /dev/nvme0n1p3 /media/win
ls /media/win/temp          # должен показать tarball
```

(Если винда не на p3 — смотреть `lsblk -f`, большой NTFS-раздел.)

```bash
tar xzf /media/win/temp/ArchLinuxARM-aarch64-latest.tar.gz -C /mnt
```

Распаковка 2–5 минут. Это и есть «сборка» системы.

**Edge case: `ls /media/win/temp` пусто** → искать файл:
`find /media/win -name "ArchLinuxARM*" 2>/dev/null`
(если перетащил на рабочий стол — путь будет `/media/win/Users/<имя>/Desktop`).

**Edge case: tar пишет «not found»** → скачан не полностью (файл должен
быть 829 367 415 байт = 791 МБ). Перекачать.

### Шаг 9. Chroot — вход внутрь Arch

```bash
mount --bind /dev  /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys  /mnt/sys
cp /etc/resolv.conf /mnt/etc/
chroot /mnt /bin/bash
```

После `chroot` все команды настраивают уже Arch, а не Ubuntu.

### Шаг 10. Базовая настройка Arch

```bash
pacman-key --init
pacman-key --populate archlinuxarm
```

```bash
ln -sf /usr/share/zoneinfo/Europe/Minsk /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'archlinux' > /etc/hostname

pacman -Sy grub os-prober sudo
```

**Edge case: `pacman -Sy` падает с `GPGME error` / `signature unknown`**
(стандартная болячка Arch ARM, почти гарантированно встретится):

```bash
rm -rf /etc/pacman.d/gnupg
pacman-key --init && pacman-key --populate archlinuxarm
pacman -Sy archlinuxarm-keyring
```

и повторить `pacman -Sy grub os-prober sudo`.

**Edge case: сети нет (`pacman` не резолвит хосты)** → `ping 8.8.8.8`.
Если пинг идёт, а имена не резолвятся: `echo 'nameserver 8.8.8.8' > /etc/resolv.conf`.
Если пинга нет — в VMware проверить сетевой адаптер (NAT, Connect).

### Шаг 11. Пользователь по заданию ⚠️

Подставить **свой** хеш из Шага 1:

```bash
useradd -m -G wheel -s /bin/bash User-СВОЙХЕШ
passwd User-СВОЙХЕШ
passwd          # пароль root — придумать и запомнить
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
```

**Скриншот** — пользователь должен быть виден в отчёте.

### Шаг 12. Загрузчик GRUB (рождение dual boot)

```bash
grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
```

```bash
echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/' /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg
```

В выводе искать строку:

```
Found Windows Boot Manager on /dev/nvme0n1p1@/EFI/Microsoft/Boot/bootmgfw.efi
```

Она означает, что винда попала в меню GRUB. **Скриншот вывода.**

**Edge case: строки про Windows нет** → EFI-раздел не был смонтирован
в `/boot/efi` в момент запуска `grub-mkconfig`. Исправить:

```bash
mount /dev/nvme0n1p1 /boot/efi
grub-mkconfig -o /boot/grub/grub.cfg
```

**Edge case: `grub-install` пишет ошибку про efivars** → смонтировать
efivarfs: `mount -t efivarfs efivarfs /sys/firmware/efi/efivars`

### Шаг 13. Выход и перезагрузка

```bash
exit
umount -R /mnt
reboot
```

⚠️ Сразу при перезагрузке: VMware → **Settings → CD/DVD → Disconnect**
(иначе снова грузанётся в Ubuntu live).

---

## Часть Г. Первая загрузка Arch

### Шаг 14. Меню GRUB и логин

1. Появляется **меню GRUB** (10 секунд): Arch Linux / Windows Boot Manager
   — **скриншот, главный кадр отчёта**
2. Выбрать Arch → консоль логина
3. Логин: `User-СВОЙХЕШ` + пароль
4. **Скриншот** успешного входа + `uname -a` (покажет aarch64 и имя ядра)

**Edge case: вместо меню сразу грузится винда** → UEFI запомнил виндовый
загрузчик приоритетным. При старте VM жать **Esc** → выбрать **GRUB**.
Чтобы закрепить: в Arch выполнить `efibootmgr` (посмотреть порядок),
затем `efibootmgr -o XXXX,YYYY` — GRUB первым.

**Edge case: вместо меню сразу грузится Arch без выбора** → GRUB всё же
стоит первым, просто не грузился в винду; проверить Шаг 12 (os-prober).

**Edge case: чёрный экран / «Security Violation» при загрузке GRUB** →
Secure Boot не выключен. Вернуться к Шагу 3.

**Edge case: Arch не загружается, `mount: unknown filesystem type ext4`**
или паника ядра → скорее всего `/etc/fstab` не сгенерирован или неверен
(tarball Arch ARM не включает fstab под этот диск). Лечится из live-Ubuntu:

```bash
sudo -i
mount /dev/nvme0n1p6 /mnt
mount /dev/nvme0n1p1 /mnt/boot/efi
mount --bind /dev /mnt/dev && mount --bind /proc /mnt/proc && mount --bind /sys /mnt/sys
chroot /mnt /bin/bash

cat > /etc/fstab <<'EOF'
/dev/nvme0n1p6  /          ext4   defaults  0 1
/dev/nvme0n1p1  /boot/efi  vfat   defaults  0 2
/dev/nvme0n1p5  none       swap   defaults  0 0
EOF

exit
```

(номера — свои!), перезагрузка.

### Шаг 15. Графическое окружение (опционально)

После первого входа, для удобства остальных скриншотов:

```bash
sudo pacman -S xorg plasma sddm konsole firefox
sudo systemctl enable sddm
sudo reboot
```

Получится рабочий стол KDE. GUI-утилита для железа (по заданию консоль
для сбора информации использовать нельзя): `sudo pacman -S hardinfo` —
запускать из графической сессии.

### Шаг 16. VMware Tools (чтобы курсор и разрешение работали)

```bash
sudo pacman -S open-vm-tools
sudo systemctl enable --now vmtoolsd
```

В винде VMware Tools уже ставятся автоматически (всплывающее окно при
первом запуске).

---

## После установки — не забыть

- [ ] Скриншоты этапов установки Windows (если не снял — переустановить
      винду с записью экрана, или использовать существующие)
- [ ] Скриншоты всех этапов Arch (GParted, tar, chroot, useradd, grub)
- [ ] Меню GRUB с двумя системами
- [ ] Логин `User-<hash>` в обеих системах
- [ ] Инфа о железе через **GUI-утилиты** на **обеих** системах:
      винда — HWiNFO64 / msinfo32 / diskmgmt; Arch — hardinfo
      (консольные команды для сбора — **запрещены заданием**)
- [ ] Рукотворная схема шинной архитектуры с конкретными устройствами
- [ ] Удалить `C:\temp\ArchLinuxARM-*.tar.gz` с винды (791 МБ)
- [ ] Проработать вопросы самоконтроля 9–12 (для 7–9): состав системной
      шины, BIOS vs UEFI, загрузчики (Windows: Windows Boot Manager/bootmgfw,
      Linux: GRUB), что такое Dual Boot

## Требования по оформлению отчёта

Оформление — по `labs/ТребованияОформления (2).pdf`. Скриншоты снабдить
текстовым описанием: что происходит на скрине и каково назначение этапа.
Всё придётся объяснять преподавателю **устно, без отчёта**.
