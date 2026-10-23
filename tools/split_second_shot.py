#!/usr/bin/env python3
"""Separa a carga dupla (X2/X3) gravada com SECOND=20 em dois tiros, como no original:
soltar dispara o primeiro (charged_NNN), apertar de novo dispara o segundo (second_NNN).

Uso: split_second_shot.py <assets/weapons/x1/arm_x2> [press=20]
Cada pedaço desenhado é seguido de quadro em quadro: o que encosta (até R px) no primeiro tiro do
quadro anterior continua sendo dele; o que nasce a partir do aperto (quadro press) é do segundo.
second_000 = quadro do aperto, para manter o atraso original até o tiro aparecer.
"""
import glob
import os
import sys

from PIL import Image

R = 8   # distância máxima entre um pedaço e o mesmo tiro no quadro anterior


def components(img):
    """Pedaços opacos (8-vizinhança) como conjuntos de pixels."""
    a = img.getchannel("A").load()
    w, h = img.size
    seen, out = set(), []
    for y in range(h):
        for x in range(w):
            if a[x, y] and (x, y) not in seen:
                stack, comp = [(x, y)], set()
                seen.add((x, y))
                while stack:
                    px, py = stack.pop()
                    comp.add((px, py))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            q = (px + dx, py + dy)
                            if 0 <= q[0] < w and 0 <= q[1] < h and q not in seen and a[q]:
                                seen.add(q)
                                stack.append(q)
                out.append(comp)
    return out


def near(comp, mask):
    if not mask:
        return 0
    return sum(1 for (x, y) in comp
               if any((x + dx, y + dy) in mask for dx in (-R, 0, R) for dy in (-R, 0, R)))


def split(folder, press=20):
    files = sorted(glob.glob(os.path.join(folder, "charged_*.png")))
    first_prev, second_prev = set(), set()
    firsts, seconds = [], []
    for k, f in enumerate(files):
        img = Image.open(f).convert("RGBA")
        first, second = set(), set()
        for comp in components(img):
            a, b = near(comp, first_prev), near(comp, second_prev)
            if a == 0 and b == 0:
                (second if k >= press else first).update(comp)
            else:
                (first if a >= b else second).update(comp)
        for mask, out in ((first, firsts), (second, seconds)):
            part = Image.new("RGBA", img.size)
            src, dst = img.load(), part.load()
            for p in mask:
                dst[p] = src[p]
            out.append(part)
        first_prev, second_prev = first, second
    for f in files:
        os.remove(f)
    for k, part in enumerate(firsts):
        part.save(os.path.join(folder, f"charged_{k:03d}.png"))
    for k, part in enumerate(seconds[press:]):
        part.save(os.path.join(folder, f"second_{k:03d}.png"))
    print(folder, "primeiro", len(firsts), "segundo", len(seconds) - press)


if __name__ == "__main__":
    split(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 20)
