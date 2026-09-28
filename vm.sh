#!/bin/zsh
# vm.sh — управление Windows 11 ARM без окна Fusion.
# Почему без окна: бета macOS 27.2 роняет UI Fusion при отрисовке окна ВМ,
# поэтому машина запускается headless (vmrun nogui), а экран смотрится через VNC.
#
# Копии ВМ (приоритет сверху вниз):
#   1. /Volumes/KingstonSXS/Windows 11 64-bit Arm.vmwarevm  — флешка
#   2. ~/Virtual Machines.localized/Windows 11 64-bit Arm.vmwarevm — локально
# Если флешка подключена — ВМ запускается с неё и все изменения остаются на
# флешке; локальная копия при этом НЕ обновляется (держи только одну рабочую
# копию, иначе состояния разъедутся).
#
# Использование:
#   ./vm.sh start   — запустить ВМ (без окна)
#   ./vm.sh vnc     — открыть экран ВМ (Finder VNC)
#   ./vm.sh stop    — выключить ВМ (сначала мягко)
#   ./vm.sh status  — что сейчас запущено и с какого носителя

VMRUN="/Applications/VMware Fusion.app/Contents/Library/vmrun"
VNC_URL="vnc://localhost:5901"
BUNDLE="Windows 11 64-bit Arm.vmwarevm"
VMFILE="Windows 11 64-bit Arm.vmx"

FLASH_VM="/Volumes/KingstonSXS/$BUNDLE/$VMFILE"
LOCAL_VM="$HOME/Virtual Machines.localized/$BUNDLE/$VMFILE"

PASS=$(security find-generic-password -l "VMware Fusion encryption" -w 2>/dev/null)
if [ -z "$PASS" ]; then
  echo "Пароль шифрования ВМ недоступен — macOS должна показать диалог связки ключей, нажми «Разрешить»."
  security find-generic-password -l "VMware Fusion encryption" -w || exit 1
fi

# Выбор копии: флешка в приоритете.
if [ -f "$FLASH_VM" ]; then
  VMX="$FLASH_VM"
  SRC="флешка KingstonSXS"
elif [ -f "$LOCAL_VM" ]; then
  VMX="$LOCAL_VM"
  SRC="локальный диск"
else
  echo "ВМ не найдена: ни на флешке, ни локально."
  echo "  ждал: $FLASH_VM"
  echo "  или:  $LOCAL_VM"
  exit 1
fi
VMDIR="$(dirname "$VMX")"

# Путь реально запущенного экземпляра (если есть) — из vmrun list.
RUNNING=$("$VMRUN" -T fusion list | grep "Windows 11 64-bit Arm.vmx$" | head -1)

case "$1" in
  start)
    if [ -n "$RUNNING" ]; then
      echo "ВМ уже запущена: $RUNNING"
      echo "Экран ВМ: Finder → ⌘K → vnc://localhost:5901  (пароль в vmx)"
      exit 0
    fi
    echo "Источник: $SRC"
    echo "Запуск, подожди немного..."
    OUT=$("$VMRUN" -T fusion -vp "$PASS" start "$VMX" nogui 2>&1)
    if echo "$OUT" | grep -q "already in use"; then
      pgrep -x vmware-vmx >/dev/null || {
        echo "Старые локи после краша — чищу..."
        rm -rf "$VMDIR"/*.lck
        OUT=$("$VMRUN" -T fusion -vp "$PASS" start "$VMX" nogui 2>&1)
      }
    fi
    "$VMRUN" -T fusion list
    echo "Экран ВМ: Finder → ⌘K → vnc://localhost:5901  (пароль в vmx)"
    ;;
  vnc)
    open "vnc://localhost:5901"
    ;;
  stop)
    if [ -z "$RUNNING" ]; then
      echo "ВМ не запущена."
      exit 0
    fi
    RVMX="$(echo "$RUNNING" | xargs)"
    "$VMRUN" -T fusion -vp "$PASS" stop "$RVMX" soft 2>/dev/null \
      || "$VMRUN" -T fusion -vp "$PASS" stop "$RVMX" hard
    echo "ВМ выключена (копия: $RVMX)."
    ;;
  help|-h|--help)
    echo "vm.sh — управление Windows 11 ARM без окна Fusion."
    echo ""
    echo "Команды:"
    echo "  start    запустить ВМ headless (vmrun nogui)"
    echo "  vnc      открыть экран ВМ через Finder VNC"
    echo "  stop     выключить ВМ (сначала soft, потом hard)"
    echo "  status   показать запущенные ВМ и выбранную копию"
    echo ""
    echo "Копии ВМ: флешка KingstonSXS в приоритете, локальный диск — запасной."
    echo "Если ВМ запускается с флешки, изменения остаются на флешке; локальная"
    echo "копия устаревает. Не запускай одну и ту же ВМ с двух копий по очереди,"
    echo "не скопировав изменения обратно."
    echo ""
    echo "Контекст: бета macOS 27.2 роняет окно ВМ в Fusion, поэтому"
    echo "машина запускается без UI, а экран смотрится через встроенный"
    echo "VNC: Finder → ⌘K → vnc://localhost:5901 (пароль задан в vmx)."
    ;;
  status|*)
    echo "Копия для запуска: $([ -f "$FLASH_VM" ] && echo "флешка ($FLASH_VM)" || echo "локально ($LOCAL_VM)")"
    "$VMRUN" -T fusion list
    ;;
esac