#!/usr/bin/env python3
"""Completa a parte de baixo do tiro em cruz do X3 (arm_x3/second_NNN.png).

A janela gravada tem só 40 px abaixo dos pés do X (âncora 48,120 em 272×160): no original o X estava
no chão e os braços de baixo da cruz saíram da tela. A cruz é simétrica na linha do tiro (centro da
bola, y=LINE), então cada pixel de cima (fora da faixa do próprio tiro) é espelhado para baixo onde
está vazio. A tela cresce para baixo; a âncora (canto de cima) não muda.

Uso: mirror_cross.py <assets/weapons/x1/arm_x3>   (rodar depois de cut_arm_shots/split_second_shot)
"""
import glob
import os
import sys

from PIL import Image

LINE = 102      # centro da bola em second_024 (bbox y 94..110)
BAND = 10       # faixa do tiro rosa em volta da linha: não espelha
HEIGHT = 2 * LINE + 4


def mirror(path: str) -> None:
    src = Image.open(path).convert("RGBA")
    if src.height >= HEIGHT:
        return  # já espelhado
    out = Image.new("RGBA", (src.width, HEIGHT))
    out.paste(src, (0, 0))
    a, b = src.load(), out.load()
    for y in range(0, LINE - BAND):
        ty = 2 * LINE - y
        for x in range(src.width):
            if a[x, y][3] and not b[x, ty][3]:
                b[x, ty] = a[x, y]
    out.save(path)


if __name__ == "__main__":
    for f in sorted(glob.glob(os.path.join(sys.argv[1], "second_*.png"))):
        mirror(f)
    print("ok")
