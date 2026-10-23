#!/usr/bin/env python3
"""Recorta a aura de carga original das capturas do Mesen 2 (scripts/charge_fx.lua).

Uso: cut_charge.py <out_mesen> <assets/charge>   (lê aura_x1, aura_x2, aura_x3)
Cada captura charge_NNN.png é o frame NNN desde o aperto do tiro, com o X parado e o fundo escondido.
Saída por jogo: sparks_NNN.png (só as faíscas: pixels que eram fundo no frame -02, numa janela de
80×80 centrada no X, âncora nos pés) e charge.json com:
  first  primeiro frame com faíscas (início visual da carga)
  full   primeiro frame com faíscas quentes (carga cheia: vermelho > azul)
  last   último frame capturado (depois dele, repete de full até last)
  flash  {frame: [r, g, b]} variação média de cor do próprio X (paleta piscando), em 0..1
"""
import json
import os
import sys
from collections import Counter

from PIL import Image

WIN = 80
RADIUS = 28


def cut(src, dest):
    base = Image.open(os.path.join(src, "charge_-02.png")).convert("RGB")
    W, H = base.size
    bg = Counter(base.getdata()).most_common(1)[0][0]
    bp = base.load()
    # O X: pixels não-fundo entre a barra de vida (x < 40) e x = 170 (inimigos à direita no X2).
    pts = [(x, y) for y in range(H) for x in range(40, 170) if bp[x, y] != bg]
    x0, x1 = min(p[0] for p in pts), max(p[0] for p in pts)
    feet = max(p[1] for p in pts)
    cx = (x0 + x1) // 2
    cy = (min(p[1] for p in pts) + feet) // 2
    left, top = cx - WIN // 2, feet - WIN + 8
    os.makedirs(dest, exist_ok=True)
    meta = {"first": None, "full": None, "last": 0, "flash": {}, "feet": WIN - 8}
    k = 0
    hot_run = 0
    while os.path.exists(os.path.join(src, "charge_%03d.png" % k)):
        im = Image.open(os.path.join(src, "charge_%03d.png" % k)).convert("RGB")
        q = im.load()
        out = Image.new("RGBA", (WIN, WIN))
        o = out.load()
        hot = cold = 0
        delta = [0, 0, 0]
        n = 0
        for y in range(WIN):
            for x in range(WIN):
                X, Y = left + x, top + y
                if not (0 <= X < W and 0 <= Y < H):
                    continue
                a, b = bp[X, Y], q[X, Y]
                # Faíscas só perto do X: tiros e fumaça de inimigos (X2) ficam de fora.
                near = (X - cx) ** 2 + (Y - cy) ** 2 <= RADIUS ** 2
                if a == bg and b != bg and near:
                    o[x, y] = b + (255,)
                    hot += b[0] > b[2]
                    cold += b[0] <= b[2]
                elif a != bg and a != b and k >= 30:
                    n += 1
                    for i in range(3):
                        delta[i] += b[i] - a[i]
        # Antes do frame 30 o X ainda está na pose de tiro do primeiro aperto: sem aura.
        if k >= 30 and hot + cold > 0:
            if meta["first"] is None:
                meta["first"] = k
            hot_run = hot_run + 1 if hot > cold else 0
            if meta["full"] is None and hot_run == 3:
                meta["full"] = k - 2
            out.save(os.path.join(dest, "sparks_%03d.png" % k))
        if k >= 30 and n > 0:
            meta["flash"][k] = [round(d / n / 255, 3) for d in delta]
        meta["last"] = k
        k += 1
        if hot + cold == 0:
            hot_run = 0
    json.dump(meta, open(os.path.join(dest, "charge.json"), "w"))
    print(dest, {key: meta[key] for key in ("first", "full", "last")}, "flash", len(meta["flash"]))


for game in ("x1", "x2", "x3"):
    cut(os.path.join(sys.argv[1], "aura_" + game), os.path.join(sys.argv[2], game))
