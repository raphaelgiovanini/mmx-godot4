#!/usr/bin/env python3
"""Copia os quadros de tiro recortados (tools/cut_shots.py) para assets/shots/<jogo>/ com shots.json.

Uso: install_shots.py <pasta_recortes> (ex.: ~/Games/mmx-lab/mesen2/shots)
A escolha de quadros abaixo foi feita olhando as capturas do Mesen 2 (docs/tiros.md):
quadros com partícula de carga, borda da tela ou colisão com inimigo ficaram de fora.
"""
import json
import os
import shutil
import sys

PICK = {
    "x1": {"lemon": ("x1", ["lemon_05"]),
           "form": ("x1", ["release_02", "release_03", "release_04"]),
           "fly": ("x1", ["release_05", "release_06", "release_07", "release_08", "release_09", "release_10"]),
           "medium_form": ("medium_x1", ["release_03", "release_04", "release_06"]),
           "medium_fly": ("medium_x1", ["release_07", "release_09"])},
    # Tiro simples do X2 não saiu limpo na captura (tiros do inimigo no caminho); é o mesmo desenho do X1.
    "x2": {"lemon": ("x1", ["lemon_05"]),
           "form": ("x2", ["release_03", "release_04", "release_05"]),
           "fly": ("x2", ["release_06"]),
           "medium_form": ("medium_x2", ["release_07", "release_09"]),
           "medium_fly": ("medium_x2", ["release_10"])},
    "x3": {"lemon": ("x3", ["lemon_05"]),
           "form": ("x3", ["release_03"]),
           "fly": ("x3", ["release_04", "release_05", "release_06", "release_07", "release_08", "release_09",
                          "release_10", "release_11", "release_12", "release_13"]),
           "medium_form": ("medium_x3", ["release_03", "release_04", "release_06"]),
           "medium_fly": ("medium_x3", ["release_07", "release_09"])},
}


def main():
    src = os.path.expanduser(sys.argv[1])
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "shots")
    for game, parts in PICK.items():
        out = os.path.join(root, game)
        os.makedirs(out, exist_ok=True)
        meta = {}
        for part, (from_game, frames) in parts.items():
            names = []
            for i, frame in enumerate(frames):
                name = f"{part}_{i}.png"
                shutil.copy(os.path.join(src, from_game, frame + ".png"), os.path.join(out, name))
                names.append(name)
            meta[part] = names
        with open(os.path.join(out, "shots.json"), "w") as f:
            json.dump(meta, f, indent=1)
        print(game, {k: len(v) for k, v in meta.items()})


if __name__ == "__main__":
    main()
