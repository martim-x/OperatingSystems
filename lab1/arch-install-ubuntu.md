# Установка Arch Linux ARM из-под live-Ubuntu — гайд с пояснениями к каждой команде

> Контекст: VMware Fusion, Apple M1 Pro. Windows уже стоит.
> Загружен live-Ubuntu (Try Ubuntu), открыт терминал (**Ctrl+Alt+T**).
>
> **Нумерация команд:** у каждой команды свой ID (Команда 1 … Команда 53).
> Когда показываешь скрин или спрашиваешь — называй ID, например «команда 22».
>
> Раздел винды НЕ монтируем: tarball Arch скачивается прямо в live-Ubuntu
> через Firefox (сеть в виртуалке идёт через NAT мака).

✅ **Фактическая разметка этой установки (проверено по lsblk):**

```
nvme0n1p1  ~300M   EFI винды (общий, сюда ставим GRUB)
nvme0n1p2  16M     MSR винды (не трогать)
nvme0n1p3  ~1G     recovery винды (не трогать)
nvme0n1p4  ~83G    C: винды, NTFS (не монтируем, не трогаем)
nvme0n1p5  2G      новый swap (создан в GParted первым)
nvme0n1p6  ~13G    новый root, ext4 (создан в GParted вторым)
```

Сверка: swap — 2G (p5), ext4 — ~13G (p6). Ничего не трогаем кроме p5/p6/p1.

Разметка диска (в GParted, до команд ниже): из unallocated создать
**linux-swap 2048 MiB**, из остатка — **ext4**. Применить (зелёная галка).

---

## Этап 1. Монтирование разделов

**Команда 1:**
```bash
sudo -i
```
Получить права root в live-системе, чтобы не писать sudo перед каждой командой.

**Команда 2:**
```bash
lsblk -f
```
Список всех разделов с типами файловых систем. Сверяешь номера разделов:
EFI (vfat, ~300M), винда (ntfs, большой), новый ext4, новый swap.

**Команда 3:**
```bash
lsblk -o NAME,TYPE,SIZE
```
То же самое, но компактно: имя, тип, размер. Удобно для быстрой сверки,
какой раздел какой — и для скриншота в отчёт.

**Команда 4:**
```bash
mkfs.ext4 /dev/nvme0n1p6
```
Создать файловую систему ext4 на новом корневом разделе (p6, ~13G).
⚠️ ТОЛЬКО на новом разделе! На NTFS-разделах винды — никогда (убьёшь винду).

**Команда 5:**
```bash
mkswap /dev/nvme0n1p5
```
Подготовить раздел подкачки (p5, 2G).

**Команда 6:**
```bash
swapon /dev/nvme0n1p5
```
Включить подкачку прямо сейчас.

**Команда 7:**
```bash
mount /dev/nvme0n1p6 /mnt
```
Смонтировать корневой раздел в /mnt — сюда распакуется Arch.

**Команда 8:**
```bash
mkdir -p /mnt/boot/efi
```
Создать пустой каталог, куда сейчас смонтируется EFI-раздел.

**Команда 9:**
```bash
mount /dev/nvme0n1p1 /mnt/boot/efi
```
Смонтировать EFI-раздел винды в /mnt/boot/efi. GRUB поставится именно сюда.
Общий EFI-раздел — и есть то, что делает dual boot возможным.

---

## Этап 2. Скачивание и распаковка Arch

**Действие 10 (не терминал, а браузер):**
Открыть Firefox в live-Ubuntu и скачать
`ArchLinuxARM-aarch64-latest.tar.gz` (791 МБ, ~10 минут) по прямой ссылке
`http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz`
(со страницы платформы: `https://archlinuxarm.org/platforms/armv8/generic`).
Файл сохранится в `/home/ubuntu/Downloads`.
⚠️ Путь именно `/os/` (не /arm/ — тот отдаёт 404).

Альтернатива одной командой в терминале (если сеть уже работает):
```bash
wget -c http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
```
(-c — докачка, если оборвётся; из-под root файл ляжет в /root, а не в Downloads!)

**Команда 11:**
```bash
ls -lh /home/ubuntu/Downloads
```
Проверить, что tarball скачался. Полный размер правильного файла —
829 367 415 байт (791 МБ); недокачанный не распакуется.

**Команда 12:**
```bash
tar xzf /home/ubuntu/Downloads/ArchLinuxARM-aarch64-latest.tar.gz -C /mnt
```
Распаковать корневую файловую систему Arch Linux ARM в /mnt.
**Это и есть «установка».** Идёт 2–5 минут без прогресс-бара, не прерывать.
(Если качал через wget от root — путь будет /root/ArchLinuxARM-...tar.gz)

---

## Этап 3. Вход внутрь Arch (chroot)

**Команда 13:**
```bash
mount --bind /dev  /mnt/dev
```
Пробросить виртуальную ФС устройств внутрь /mnt.

**Команда 14:**
```bash
mount --bind /proc /mnt/proc
```
Пробросить виртуальную ФС процессов (без неё не видны процессы и сеть).

**Команда 15:**
```bash
mount --bind /sys  /mnt/sys
```
Пробросить виртуальную ФС параметров ядра.

**Команда 16:**
```bash
cp /etc/resolv.conf /mnt/etc/
```
Скопировать настройки DNS из Ubuntu в Arch. Без этого внутри chroot имена
не резолвятся → pacman не скачает пакеты.

**Команда 17:**
```bash
chroot /mnt /bin/bash
```
Сменить корень: все следующие команды выполняются уже в Arch, а не в Ubuntu.
Приглашение сменится на `[root@alarm /]#`.

---

## Этап 4. ⚠️ МИНИМУМ БЕЗ КОТОРОГО СИСТЕМА НЕ ЗАГРУЗИТСЯ

Пропустишь что-то отсюда — kernel panic, чёрный экран или невозможность войти.

### 4.1 Связка ключей pacman (иначе пакеты не поставятся)

**Команда 18:**
```bash
pacman-key --init
```
Создать GnuPG-связку ключей пакетного менеджера.

**Команда 19:**
```bash
pacman-key --populate archlinuxarm
```
Импортировать ключи разработчиков Arch ARM — pacman проверяет подписи
каждого пакета, без ключей любая установка падает с GPGME error.

### 4.2 Пароль root (иначе не сможешь войти)

**Команда 20:**
```bash
passwd
```
Задать пароль суперпользователя. Без него в консоль логина не войти.

### 4.3 Файл /etc/fstab (иначе kernel panic при загрузке)

Tarball НЕ содержит fstab — таблицы «что и куда монтировать при старте».

**Команда 21:**
```bash
cat > /etc/fstab <<'EOF'
/dev/nvme0n1p6  /          ext4   defaults  0 1
/dev/nvme0n1p1  /boot/efi  vfat   defaults  0 2
/dev/nvme0n1p5  none       swap   defaults  0 0
EOF
```
Формат строки: устройство → точка монтирования → тип ФС → параметры →
dump → порядок проверки. Пробелы вместо табов — нормально. Номера под
твою разметку (root=p6, EFI=p1, swap=p5) — лишний раз сверь с Командой 2.

### 4.4 Загрузчик GRUB (иначе улетишь в винду или «No bootloader»)

**Команда 22:**
```bash
pacman -Sy grub os-prober efibootmgr
```
Обновить базы пакетов и поставить: **grub** — сам загрузчик;
**os-prober** — утилиту, которая найдёт винду и добавит её в меню GRUB;
**efibootmgr** — утилиту регистрации загрузочной записи в NVRAM (grub-install
вызывает её сам, но пакетом-зависимостью она не тянется — без неё будет
«efibootmgr not found»).
⚠️ НИКАКИХ `pacman -Syu` и `pacman -S systemd` — в прошлый раз именно
systemd ломал зависимости (261.3 против 261.2). Минимум хватает.

**Команда 23:**
```bash
grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
```
Записать GRUB в EFI-раздел (общий с виндой p1). `--target=arm64-efi` —
потому что у нас ARM64-машина.

**Команда 24:**
```bash
echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
```
Разрешить GRUB искать чужие ОС. Без этой строки os-prober молчит и пункта
Windows в меню не будет.

**Команда 25:**
```bash
grub-mkconfig -o /boot/grub/grub.cfg
```
Собрать итоговый конфиг загрузчика. В выводе ОБЯЗАТЕЛЬНО ищи строку:
`Found Windows Boot Manager on /dev/nvme0n1p1@/EFI/Microsoft/Boot/bootmgfw.efi`
Нет строки → EFI не смонтирован в /boot/efi: Команда 9 и повтори Команду 25.
**Скриншот вывода — главный кадр отчёта (dual boot родился).**

Система загрузоспособна. Дальше — настройка.

---

## Этап 5. Настройка (пользователь сделан, остальное опционально)

### 5.1 Пользователь по заданию — ✅ СДЕЛАНО

Пользователь `User-6d4ec851` создан, пароль задан, sudo включён. Команды
оставлены здесь для отчёта (нужны описания к скринам):

**Команда 26:**
```bash
useradd -m -G wheel -s /bin/bash User-6d4ec851
```
Создать пользователя: -m — с домашним каталогом, -G wheel — в группу,
члены которой могут делать sudo, -s — оболочка bash.

**Команда 27:**
```bash
passwd User-6d4ec851
```
Пароль пользователя. **Скриншот — пользователь должен быть виден в отчёте.**

**Команда 28:**
```bash
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
```
Раскомментировать строку, дающую группе wheel право на sudo.

Часовой пояс, локали и имя хоста НЕ настраиваем сейчас — сделаем это позже
в графической сессии (Этап 8), на загрузку они не влияют.

---

## Этап 6. Графическая оболочка — KDE Plasma

Ставим **KDE Plasma (облегчённый вариант `plasma-desktop`)**: полноценное
окружение (панель, меню, окна, Dolphin), скачается ~500 МБ, встанет ~3 ГБ —
на root-раздел 13 ГБ помещается с запасом. Полный `plasma` ставить не
рекомендую (~6 ГБ), `kde-applications` — не влезет.

Сначала проверь свободное место:

**Команда 29:**
```bash
df -h /
```
Показать занятость корневого раздела. Свободно должно быть ~10 ГБ
(система заняла ~2,5–3 ГБ). Если меньше 5 ГБ — сначала `pacman -Sc`
(очистить кэш пакетов).

**Команда 30:**
```bash
pacman -S xorg plasma-desktop sddm konsole firefox
```
Установить графику: xorg — графический сервер; plasma-desktop — ядро KDE
Plasma (панель, окна, настройки, файловый менеджер Dolphin); sddm — экран
входа; konsole — терминал; firefox — для скриншотов в отчёт.
Скачается ~500 МБ, pacman покажет Total Download / Installed Size перед
подтверждением.

**Команда 31:**
```bash
systemctl enable sddm
```
Включить автозапуск экрана входа при загрузке (без этого после ребута
будет голая консоль).

**Команда 32:**
```bash
pacman -S hardinfo
```
Графическая утилита железа для отчёта (по заданию — только GUI, консоль
запрещена): процессор, память, PCI, диски, сеть. Запускать из графики.

**Команда 33:**
```bash
pacman -S open-vm-tools
```
Инструменты гипервизора: курсор, разрешение, буфер обмена.

**Команда 34:**
```bash
systemctl enable --now vmtoolsd
```
Запустить VMware Tools сразу и включить при загрузке.

---

## Этап 7. Выход и перезагрузка

**Команда 35:**
```bash
exit
```
Выйти из chroot обратно в Ubuntu.

**Команда 36:**
```bash
umount -R /mnt
```
Отмонтировать всё, что монтировали в /mnt (гарантия, что данные дописаны).

**Команда 37:**
```bash
reboot
```
Перезагрузка. ⚠️ Сразу в меню VMware: **CD/DVD → Disconnect** — иначе снова
грузанётся в live-Ubuntu.

⚠️ И напоминание: перед установкой Arch в Settings → Advanced снять галку
**Enable UEFI Secure Boot** (иначе GRUB не загрузится — Security Violation).

При старте: Esc (если сразу пошла винда) → выбрать GRUB → меню с двумя
системами → Arch → логин User-6d4ec851.

---

## Этап 8. После первой загрузки — настройка и скриншоты

Система загружена. Всё ниже выполняется **от root или через sudo**.
Это отложенная настройка из старого Этапа 5.

### 8.0 Сеть после первой загрузки — ОБЯЗАТЕЛЬНО

Свежий Arch сам сеть не настраивает: в chroot работал DHCP от live-Ubuntu,
а после загрузки реальной системы сетевого демона нет → `network is
unreachable`. Лечится встроенным systemd-networkd, ничего скачивать не надо:

**Команда 47:**
```bash
ip a
```
Узнать имя сетевого интерфейса (обычно `ens33` или `eth0`). Если интерфейса
нет вовсе — VMware Settings → Network Adapter → галка Connect Network Adapter.

**Команда 48:**
```bash
cat > /etc/systemd/network/20-wired.network <<'EOF'
[Match]
Name=en*
Name=eth*

[Network]
DHCP=yes
EOF
```
Конфиг встроенного сетевого демона: получать адрес автоматически (DHCP)
на любом проводном интерфейсе.

**Команда 49:**
```bash
systemctl enable --now systemd-networkd
```
Запустить сеть сейчас и включить при каждой загрузке.

**Команда 50:**
```bash
rm -f /etc/resolv.conf
printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > /etc/resolv.conf
```
DNS-серверы (rm -f обязателен: resolv.conf бывает битой ссылкой, и запись
через > в неё не попадает).

**Команда 51 (проверка — оба пинга должны пройти):**
```bash
ping -c 2 8.8.8.8 && ping -c 2 mirror.archlinuxarm.org
```

Если KDE ещё не ставился (перезагрузились до Команды 30) — ставим уже
из загруженной системы, сетью через networkd:

**Команда 52 (если Команда 30 не выполнялась в chroot):**
```bash
pacman -S xorg plasma-desktop sddm konsole firefox networkmanager hardinfo open-vm-tools
```
Тот же набор + networkmanager (апплет сети для KDE).

**Команда 53:**
```bash
systemctl disable systemd-networkd
systemctl enable NetworkManager sddm vmtoolsd
```
networkd отключаем (конфликтует с NetworkManager), включаем NetworkManager
(сеть в графической сессии), экран входа sddm и VMware Tools.

### 8.1 Часовой пояс

**Команда 38:**
```bash
sudo ln -sf /usr/share/zoneinfo/Europe/Minsk /etc/localtime
```
Часовой пояс Минска (символическая ссылка; sudo — потому что не root).

**Команда 39:**
```bash
sudo hwclock --systohc
```
Синхронизировать аппаратные часы с системным временем.

### 8.2 Локали

**Команда 40:**
```bash
sudo sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
```
Включить локаль en_US.UTF-8 в списке генерируемых.

**Команда 41:**
```bash
sudo locale-gen
```
Сгенерировать локали.

**Команда 42:**
```bash
echo 'LANG=en_US.UTF-8' | sudo tee /etc/locale.conf
```
Назначить системную локаль (через tee, т.к. `sudo echo >` не работает).

### 8.3 Имя хоста

**Команда 43:**
```bash
echo 'archlinux' | sudo tee /etc/hostname
```
Имя машины.

### 8.4 Опционально

**Команда 44 (почистить кэш пакетов, освободит ~500 МБ):**
```bash
sudo pacman -Sc
```

**Команда 45 (таймаут меню GRUB — 10 секунд на выбор системы):**
```bash
sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/' /etc/default/grub
```

**Команда 46:**
```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```
Пересобрать конфиг загрузчика с новым таймаутом.

### 8.5 Скриншоты для отчёта (снимать в этой сессии)

- Экран входа SDDM с пользователем User-6d4ec851
- Рабочий стол KDE Plasma
- Konsole: `uname -a` (видно aarch64 и имя ядра)
- hardinfo: разделы Devices, Memory, Processor (GUI-сбор железа по заданию)
- Параметры системы KDE → Дата и время (часовой пояс после Команды 38)

---

## Типовые грабли (реально встретились при прошлой установке)

| Симптом | Причина | Лечение |
|---|---|---|
| `GPGME error` / `signature unknown` у pacman | битая связка ключей | `rm -rf /etc/pacman.d/gnupg` → Команды 18-19 → `pacman -Sy archlinuxarm-keyring` |
| Зеркало лежит / скорость 0 | перегружено/лежит зеркало (eu был мёртв, живое основное) | `sed -i 's|^Server = .*|Server = http://mirror.archlinuxarm.org/$arch/$repo|' /etc/pacman.d/mirrorlist` |
| `Could not resolve host` внутри chroot | resolv.conf — битая ссылка/заглушка 127.0.0.53 | `rm -f /etc/resolv.conf` → `echo 'nameserver 8.8.8.8' > /etc/resolv.conf` |
| `EFI variables are not supported` у grub-install | не смонтирована efivarfs | `mount -t efivarfs efivarfs /sys/firmware/efi/efivars` (если «already mounted» — ищи проблему в /boot/efi) |
| `efibootmgr not found` у grub-install | не установлен efibootmgr | `pacman -S efibootmgr` (уже входит в Команду 22) |
| Нет строки `Found Windows Boot Manager` | EFI не смонтирован в /boot/efi при grub-mkconfig | Команда 9 → повторить Команду 25 |
| Паника ядра при первой загрузке | нет/кривой /etc/fstab | из live-Ubuntu: Этапы 1, 3 → пересоздать fstab (Команда 21) |
| Грузится винда, а не GRUB | UEFI запомнил винду приоритетной | Esc при старте → GRUB; закрепить: `efibootmgr` → `efibootmgr -o XXXX,YYYY` (GRUB первым) |
| `Security Violation` при загрузке GRUB | включён Secure Boot в VMware | Settings → Advanced → снять галку Enable UEFI Secure Boot |
| `network is unreachable` после первой загрузки | свежий Arch не настраивает сеть сам (в chroot её настраивала Ubuntu) | Команды 47-50 (systemd-networkd + DHCP), затем Команда 53 |

## Чеклист скриншотов

- [ ] GParted до и после разметки
- [ ] Команда 3: lsblk -o NAME,TYPE,SIZE с разделами
- [ ] Действие 10: скачивание tarball (wget /os/)
- [ ] Команда 12: распаковка tar
- [ ] Команда 17: chroot и приглашение Arch
- [ ] Команды 26-27: пользователь User-6d4ec851 виден
- [ ] Команда 25: вывод со строкой Found Windows Boot Manager
- [ ] Меню GRUB с двумя системами (главный кадр)
- [ ] Экран входа SDDM с User-6d4ec851 (KDE)
- [ ] Логин User-6d4ec851 + uname -a
- [ ] hardinfo в графической сессии
