#!/usr/bin/env bash
# Liquid Glass — informations « À propos de ce Mac » (une ligne clé=valeur par info).
# Lecture seule : aucune entrée externe, rien n'est exécuté depuis les données.
# Aucune lecture du terminal ; chaque outil externe a un délai maximal.
exec </dev/null
dmi() { tr -d '\n' < "/sys/class/dmi/id/$1" 2>/dev/null; }
vendor="$(dmi sys_vendor)"
model="$(dmi product_version)"
[ -z "$model" ] || [ "$model" = "None" ] && model="$(dmi product_name)"
echo "name=$model"
echo "vendor=$vendor"
echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | sed 's/.*: //; s/(R)//g; s/(TM)//g; s/ CPU//; s/  */ /g')"
echo "cores=$(nproc 2>/dev/null)"
mem_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
echo "memory=$(( (mem_kb + 524288) / 1048576 )) Go"
# Carte graphique : identifiants PCI lus dans /sys, nom dans pci.ids (pas de lspci).
gpu=""
for d in /sys/class/drm/card?/device; do
  v="$(cat "$d/vendor" 2>/dev/null)"; p="$(cat "$d/device" 2>/dev/null)"
  [ -n "$v" ] || continue
  v="${v#0x}"; p="${p#0x}"
  gpu="$(awk -v v="$v" -v p="$p" 'index($0, v "  ") == 1 {inv=1; next} inv && /^\t[0-9a-f]/ && $1==p {sub(/^\t[0-9a-f]+ +/, ""); print; exit} inv && /^[0-9a-f]/ {exit}' /usr/share/hwdata/pci.ids 2>/dev/null)"
  break
done
case "$gpu" in *"["*"]"*) gpu="$(sed 's/.*\[\(.*\)\].*/\1/' <<<"$gpu")";; esac
echo "gpu=$gpu"
echo "omarchy=$(timeout 2 omarchy version 2>/dev/null | sed 's/-.*//')"
echo "kernel=$(uname -r)"
echo "host=$(cat /etc/hostname 2>/dev/null)"
read -r size used avail <<<"$(df -B1 --output=size,used,avail / | tail -1)"
echo "disk_size=$size"
echo "disk_used=$used"
echo "disk_avail=$avail"
res="$(timeout 1 hyprctl monitors -j 2>/dev/null | python3 -c '
import json, sys
m = json.load(sys.stdin)[0]
w, h, k = m["width"], m["height"], m["scale"]
print("%d × %d (ressemble à %d × %d)" % (w, h, round(w / k), round(h / k)))' 2>/dev/null)"
echo "display=$res"
echo "uptime=$(uptime -p 2>/dev/null | sed 's/^up //; s/hours\?/h/; s/minutes\?/min/; s/days\?/j/; s/weeks\?/sem./')"
