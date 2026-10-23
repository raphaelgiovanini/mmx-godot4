"""Copia os inimigos do mmx8-16bit (folhas do Aseprite: PNG + JSON) para assets/enemies/.
Arte de Alysson da Paz, licença do mmx8 (uso livre, sem monetização). Lido por scripts/enemies/enemy.gd.
Uso: python3 tools/install_mmx8_enemies.py [caminho do mmx8-16bit]"""
import os, shutil, sys

MMX8 = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Projects/iGio/mmx8-16bit")
SRC = os.path.join(MMX8, "src/Actors/Enemies")
OUT = os.path.join(os.path.dirname(__file__), "..", "assets/enemies")
ENEMIES = {"metool": "Metool/metool", "batton": "SmallBat/sbat", "turret": "Turret/turret", "spiky": "Sprites/wheeler",
           "yeti": "../Bosses/boss_sprites/yeti"}   # chefe do build público (no lugar do Chill Penguin da ROM)

os.makedirs(OUT, exist_ok=True)
for name, path in ENEMIES.items():
    for ext in ("png", "json"):
        shutil.copy(os.path.join(SRC, f"{path}.{ext}"), os.path.join(OUT, f"{name}.{ext}"))
    print(name)
shutil.copy(os.path.join(SRC, "../Bosses/boss_sprites/icespike.png"), os.path.join(OUT, "icespike.png"))
# Morte: estouro 4×4 de 48 px, pedaços 6×3 de 32 px (o morcego tem os dele), estouro grande do chefe e som.
FX = {"Effects/Textures/explosion.png": "explosion.png", "Effects/Textures/remains.png": "remains.png",
      "Actors/Enemies/SmallBat/bat_remains.png": "batton_remains.png", "Effects/Textures/big_explosion.png": "big_explosion.png",
      "Effects/Textures/big_explosion.json": "big_explosion.json", "Sounds/56 - MMX - Enemy Death.wav": "enemy_death.wav"}
for src, dst in FX.items():
    shutil.copy(os.path.join(MMX8, "src", src), os.path.join(OUT, dst))
