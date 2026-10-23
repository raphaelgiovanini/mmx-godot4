#!/bin/sh
# Copia os sons do mmx8 usados pelo jogo para assets/sfx/ (fora do git). Uso: tools/install_sfx.sh ../mmx8-16bit
set -e
src="$1"; dest="$(dirname "$0")/../assets/sfx"
mkdir -p "$dest"
for f in CHARGE CHARGE_MAX_LONG CHARGED_SHOT; do cp "$src/src/Sounds/$f.wav" "$dest/"; done
cp "$src/src/Sounds/01 - MMX - X Regular Shot.wav" "$dest/LEMON.wav"
for i in 1 2 3; do cp "$src/src/Actors/Player/skins/zero/saber/zashiko/saber_$i.ogg" "$dest/"; done
