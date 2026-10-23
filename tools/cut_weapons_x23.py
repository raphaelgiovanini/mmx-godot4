#!/usr/bin/env python3
"""Recorta as 16 armas do X2/X3 gravadas no Mesen (tools/mesen/weapons.lua com ENEMIES=0D18-1098,
inimigos desligados; energia no byte alto 1FBB/1FBC; ONLY=n, uma execução por arma).

Uso: cut_weapons_x23.py <out_mesen> <assets/weapons>   (lê g2/ e g3/)
Ordem do R a partir do buster = IDs nativos 1..8 (docs do recomp, x-weapons-source-notes.md).
"""
import os
import sys

from cut_weapons_x1 import cut

X2 = ["crystal_hunter", "bubble_splash", "silk_shot", "spin_wheel", "sonic_slicer", "strike_chain",
      "magnet_mine", "speed_burner"]
X3 = ["acid_burst", "parasitic_bomb", "triad_thunder", "spinning_blade", "ray_splasher", "gravity_well",
      "frost_shield", "tornado_fang"]
if __name__ == "__main__":
    src, dest = sys.argv[1:3]
    for game, folder, names in (("x2", "g2", X2), ("x3", "g3", X3)):
        for i, name in enumerate(names):
            cut(os.path.join(src, folder), i + 1, os.path.join(dest, game, name))
