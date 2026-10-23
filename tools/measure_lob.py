#!/usr/bin/env python3
"""Mede o caminho de um tiro lançado (Acid Burst) na gravação e grava em meta.json["lob"].

A bola é o pedaço pequeno (até BALL px) de cada quadro; o caminho é o centro dela, quadro a quadro,
na janela gravada (âncora 48,120 = pés do X). O primeiro quadro em que o desenho fica largo é o
respingo no chão: dali em diante a gravação é o respingo, ancorado no ponto de contato (centro de baixo).
No jogo (scripts/player/lob_shot.gd) a bola segue esse caminho e espirra onde bater no cenário de verdade.

Uso: measure_lob.py <assets/weapons/x3/acid_burst>
"""
import json
import os
import sys

from PIL import Image

BALL = 12


def main(folder: str) -> None:
    path, start, land = [], None, None
    k = 0
    while os.path.exists(os.path.join(folder, f"shot_{k:03d}.png")):
        b = Image.open(os.path.join(folder, f"shot_{k:03d}.png")).getbbox()
        if b and start is None:
            start = k
        if b and start is not None and land is None:
            if b[2] - b[0] > BALL or b[3] - b[1] > BALL:
                land = k
            else:
                path.append([(b[0] + b[2]) / 2, (b[1] + b[3]) / 2])
        k += 1
    b = Image.open(os.path.join(folder, f"shot_{land:03d}.png")).getbbox()
    meta_path = os.path.join(folder, "meta.json")
    meta = json.load(open(meta_path))
    meta["lob"] = {"start": start, "land": land, "path": path, "splash": [(b[0] + b[2]) / 2, b[3]]}
    json.dump(meta, open(meta_path, "w"))
    print(f"bola {start}..{land - 1}, respingo em {land} ancorado em {meta['lob']['splash']}")


if __name__ == "__main__":
    main(sys.argv[1])
