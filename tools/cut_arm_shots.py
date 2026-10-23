#!/usr/bin/env python3
"""Tiro carregado do braço de cada armadura, gravado no Mesen (tools/mesen/weapons.lua com N=0,
HOLD=230 até o nível super, SECOND=20 para o segundo tiro) → assets/weapons/x1/arm_x1|arm_x2|arm_x3.

Uso: cut_arm_shots.py <out_mesen> <assets/weapons/x1>
X1 (Light): buster espiral. X2 (Giga): carregado + segundo tiro. X3 (Tri/Gold): carregado + tiro em cruz.
No X2 o chefe da abertura fica 100 px à direita: a janela é cortada antes dele.
"""
import os
import sys

from cut_weapons_x1 import cut

if __name__ == "__main__":
    src, dest = sys.argv[1:3]
    # X1 na fase do Chill Penguin (sem inimigos); X2/X3 na abertura com os inimigos desligados (ENEMIES).
    for game, folder, right in (("x1", "f1arm", 224), ("x2", "g2arm", 224), ("x3", "g3arm", 224)):
        # X2/X3: o X pisca na carga e ficava no recorte; no X1 a silhueta comeria o crescente.
        cut(os.path.join(src, folder), 1, os.path.join(dest, "arm_" + game), right, flash=game != "x1")
