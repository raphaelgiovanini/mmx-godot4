#!/usr/bin/env python3
"""Recorta armas gravadas no Mesen (tools/mesen/weapons.lua; EVERY=1, um quadro por frame).

Uso: cut_weapons_x1.py <f1> <assets/weapons/x1>   (as 8 armas do X1)
Também usado por cut_weapons_x23.py e cut_arm_shots.py.
Cada sequência (shot_NNN, charged_NNN) vira PNGs numa janela fixa presa ao X na hora do disparo:
a animação reproduz o movimento original (trajetória, espalhamento). O fundo some (camadas de
fundo escondidas no Mesen) e, numa caixa em volta do X que cobre o braço esticado, somem só os
pixels com as cores do próprio X (quadro de seleção, já na paleta da arma). A barra de vida
(x < 40) fica de fora. Âncora: pés do X em (LEFT, UP).
"""
import json
import os
import sys
from collections import Counter
from multiprocessing import Pool

from PIL import Image, ImageChops

NAMES = ["homing_torpedo", "chameleon_sting", "rolling_shield", "fire_wave",
         "storm_tornado", "electric_spark", "boomerang_cutter", "shotgun_ice"]
LEFT, RIGHT, UP, DOWN = 48, 224, 120, 40   # janela em volta dos pés do X


def _frame(args):
    path, out, box, bg, xcolors, xbox, body = args
    screen = Image.open(path).convert("RGB")
    window = screen.crop(box)
    w, h = window.size
    # Tudo que difere do fundo vira opaco.
    alpha = ImageChops.difference(window, Image.new("RGB", (w, h), bg)).convert("L").point(lambda v: 255 if v else 0)
    # Fora da tela do SNES (a janela pode passar da borda) e barra de vida (x < 40) ficam de fora.
    sw, sh = screen.size
    alpha.paste(0, (0, 0, max(0, 40 - box[0]), h))
    alpha.paste(0, (max(0, sw - box[0]), 0, w, h))
    alpha.paste(0, (0, 0, w, max(0, -box[1])))
    alpha.paste(0, (0, max(0, sh - box[1]), w, h))
    # Caixa do X: só as cores dele saem (o tiro que passa por ali fica).
    px, a = window.load(), alpha.load()
    x0, y0, x1, y1 = xbox
    seen = 0
    for y in range(max(0, y0), min(h, y1)):
        for x in range(max(0, x0), min(w, x1)):
            if a[x, y] and px[x, y] in xcolors:
                a[x, y] = 0
                seen += 1
    # X visível (tiros do braço): o contorno dele usa cores do tiro; some a silhueta inteira.
    if body and seen >= 20:
        for (x, y) in body:
            if 0 <= x < w and 0 <= y < h:
                a[x, y] = 0
    result = window.convert("RGBA")
    result.putalpha(alpha)
    result.save(out)


def cut(src, n, out, right=RIGHT, flash=False):
    """Recorta a arma n (w<n>_*) de src para out; right limita a janela.
    flash: o X pisca enquanto carrega (tiros do braço) e as cores dele mudam; junta às cores do X
    as que aparecem dentro da silhueta dele e nunca fora da caixa do X (as do tiro saem dela)."""
    sel = Image.open(os.path.join(src, f"w{n}_select.png")).convert("RGB")
    W, H = sel.size
    bg = Counter(sel.getdata()).most_common(1)[0][0]
    sp = sel.load()
    pts = [(x, y) for y in range(H) for x in range(40, W) if sp[x, y] != bg]
    # O X é o bloco mais à esquerda (no X2 o chefe da abertura pode estar na mesma tela).
    left_x = min(p[0] for p in pts)
    pts = [p for p in pts if p[0] < left_x + 40]
    x0, x1 = min(p[0] for p in pts), max(p[0] for p in pts)
    y0, feet = min(p[1] for p in pts), max(p[1] for p in pts)
    ax = (x0 + x1) // 2
    box = (ax - LEFT, feet - UP, ax + min(right, RIGHT), feet + DOWN)
    xcolors = {sp[x, y] for y in range(y0, feet + 1) for x in range(x0, x1 + 1) if sp[x, y] != bg}
    # Caixa do X em coordenadas da janela, com o braço esticado à direita.
    xbox = (x0 - 4 - box[0], y0 - 4 - box[1], x1 + 15 - box[0], feet + 2 - box[1])
    if flash:
        body = [(x, y) for (x, y) in pts if x0 <= x <= x1]
        inside, outside = set(), set()
        bx0, by0, bx1, by1 = x0 - 4, y0 - 4, x1 + 15, feet + 2
        for name in sorted(os.listdir(src)):
            if name.startswith(f"w{n}_") and name != f"w{n}_select.png":
                im = Image.open(os.path.join(src, name)).convert("RGB")
                fp = im.load()
                inside |= {fp[x, y] for (x, y) in body}
                for y in range(max(0, box[1]), min(H, box[3])):
                    for x in range(max(40, box[0]), min(W, box[2])):
                        if not (bx0 <= x < bx1 and by0 <= y < by1):
                            outside.add(fp[x, y])
        xcolors |= inside - outside - {bg}
        # Silhueta do X parado, 1 px mais larga, em coordenadas da janela.
        body = {(x + dx - box[0], y + dy - box[1]) for (x, y) in body for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
    else:
        body = set()
    os.makedirs(out, exist_ok=True)
    jobs, counts = [], {}
    for kind in ("shot", "charged"):
        k = 0
        while os.path.exists(os.path.join(src, f"w{n}_{kind}_{k:03d}.png")):
            jobs.append((os.path.join(src, f"w{n}_{kind}_{k:03d}.png"), os.path.join(out, f"{kind}_{k:03d}.png"),
                         box, bg, xcolors, xbox, body))
            k += 1
        counts[kind] = k
    with Pool() as pool:
        pool.map(_frame, jobs)
    # Borda direita da tela do SNES na janela: daí em diante o tiro aparece cortado.
    json.dump({"edge": W - box[0]}, open(os.path.join(out, "meta.json"), "w"))
    print(out, counts, "borda", W - box[0])


if __name__ == "__main__":
    src, dest = sys.argv[1:3]
    for i, name in enumerate(NAMES):
        cut(src, i + 1, os.path.join(dest, name))
