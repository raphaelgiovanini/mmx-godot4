#!/bin/sh
# Copia os sons do mmx8 usados pelo jogo para assets/sfx/ (versionados: licença do mmx8).
# Uso: tools/install_sfx.sh ../mmx8-16bit
set -e
src="$1/src/Sounds"; dest="$(dirname "$0")/../assets/sfx"
mkdir -p "$dest"
for f in CHARGE CHARGE_MAX_LONG CHARGED_SHOT MEDIUM_SHOT JUMP LAND DASH DAMAGE HIT HIT_BOSS BOSS_DEATH; do
	cp "$src/$f.wav" "$dest/"
done
cp "$src/01 - MMX - X Regular Shot.wav" "$dest/LEMON.wav"
cp "$src/11 - MMX - X Die.wav" "$dest/X_DIE.wav"
cp "$src/12 - MMX - X Life Gain.wav" "$dest/LIFE_GAIN.wav"
cp "$src/38 - MMX - Boss Alert.wav" "$dest/BOSS_ALERT.wav"
cp "$src/FX - teleport.wav" "$dest/TELEPORT.wav"
cp "$src/FX - Teleport End.wav" "$dest/TELEPORT_END.wav"
cp "$src/Door - Open.wav" "$dest/DOOR_OPEN.wav"
cp "$src/Door - Close.wav" "$dest/DOOR_CLOSE.wav"
cp "$src/Ice Break.wav" "$dest/ICE_BREAK.wav"
cp "$src/MMX - Enemy Helmet Hit.ogg" "$dest/DEFLECT.ogg"
for i in 1 2 3; do cp "$1/src/Actors/Player/skins/zero/saber/zashiko/saber_$i.ogg" "$dest/"; done
