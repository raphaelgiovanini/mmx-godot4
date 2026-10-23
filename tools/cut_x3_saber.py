#!/usr/bin/env python3
"""Golpe de Z-Saber do X3 com armadura, montado das camadas da folha (assets/ref/x_sprites_x1-x3.png).

A folha separa o X3 em camadas na mesma posição, só deslocadas na vertical (seções de 362–369 px):
capacete (base com capacete) +1845, braços +2207, botas +2569, corpo +2931. Empilhadas nessa ordem
(a da folha: base/capacete, braços, botas, corpo) dão o X com a Tri-Armor fazendo o golpe da linha ROW.
Cada quadro vai para uma tela 96×96 com o centro das botas no mesmo ponto dos pés do idle do mmx8,
como a animação "zsaber" de x_tri; a Gold é a mesma com as cores trocadas cor a cor (x_tri → x_gold,
comparando os mesmos pixels dos quadros de idle).

Uso: python3 tools/cut_x3_saber.py
"""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "assets/ref/x_sprites_x1-x3.png"
BG = (50, 96, 166)
ROW = (950, 241, 1415, 295)          # golpe no chão (11 quadros)
LAYERS = [1845, 2207, 2569, 2931]    # capacete, braços, botas, corpo
BOOTS = 2569
# Tela de 128 (a lâmina passa dos 96 do mmx8) com o mesmo centro: os pés do idle_0 de x_tri (52, 68 na
# tela de 96) ficam 16 px mais para dentro em cada eixo.
CANVAS = 128
FEET = (52 + 16, 68 + 16)
FPS = 20
ARC = {(32, 160, 32), (224, 232, 224), (112, 224, 112), (64, 192, 64), (160, 224, 160)}  # cores da lâmina


def layer(im, dy):
    x0, y0, x1, y1 = ROW
    c = im.crop((x0, y0 + dy, x1, y1 + dy))
    p = c.load()
    for y in range(c.height):
        for x in range(c.width):
            if p[x, y][:3] == BG:
                p[x, y] = (0, 0, 0, 0)
    return c


def spans(used, gap=2):
    out, start, blank = [], None, 0
    for i, u in enumerate(used + [False] * (gap + 1)):
        if u:
            start = i if start is None else start
            blank, last = 0, i
        elif start is not None:
            blank += 1
            if blank > gap:
                out.append((start, last + 1))
                start = None
    return out


def split(comp, body, boots):
    """Quadros da linha: um por peitoral da camada do corpo (os X às vezes se encostam). Cada pixel do X
    vai para o peitoral mais perto na horizontal; cada pedaço de lâmina (cores ARC) para o quadro com que
    mais se sobrepõe, ou o mais perto. Devolve (quadro, pés): pés = centro de baixo das botas dele."""
    p = comp.load()
    w, h = comp.size
    blade = lambda x, y: p[x, y][3] and p[x, y][:3] in ARC
    bp = body.load()
    xs = spans([any(bp[x, y][3] for y in range(h)) for x in range(w)])
    near = lambda x: min(range(len(xs)), key=lambda i: abs(x - (xs[i][0] + xs[i][1]) / 2))
    owner = [[] for _ in xs]
    seen = set()
    for y in range(h):
        for x in range(w):
            if not p[x, y][3] or (x, y) in seen:
                continue
            if not blade(x, y):
                owner[near(x)].append((x, y))
                continue
            stack, piece = [(x, y)], []
            seen.add((x, y))
            while stack:
                cx, cy = stack.pop()
                piece.append((cx, cy))
                for nx in range(cx - 1, cx + 2):
                    for ny in range(cy - 1, cy + 2):
                        if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and blade(nx, ny):
                            seen.add((nx, ny))
                            stack.append((nx, ny))
            lo, hi = min(a for a, _ in piece), max(a for a, _ in piece) + 1
            mid = (lo + hi) / 2
            overlap = [max(0, min(hi, b) - max(lo, a)) for a, b in xs]
            k = max(range(len(xs)), key=lambda i: (overlap[i], -abs(mid - (xs[i][0] + xs[i][1]) / 2)))
            owner[k].extend(piece)
    feet = [[] for _ in xs]
    tp = boots.load()
    for y in range(h):
        for x in range(w):
            if tp[x, y][3]:
                feet[near(x)].append((x, y))
    out = []
    for piece, ft in zip(owner, feet):
        f = Image.new("RGBA", comp.size)
        q = f.load()
        for a, b in piece:
            q[a, b] = p[a, b]
        fx = (min(a for a, _ in ft) + max(a for a, _ in ft) + 1) // 2
        out.append((f, (fx, max(b for _, b in ft) + 1)))
    return out


def gold_map():
    """Cor da Tri → cor da Gold, pelos mesmos pixels dos quadros de idle do mmx8."""
    m = {}
    for i in range(4):
        t = Image.open(ROOT / f"assets/characters/x_tri/idle_{i}.png").convert("RGBA").load()
        g = Image.open(ROOT / f"assets/characters/x_gold/idle_{i}.png").convert("RGBA")
        gp = g.load()
        for y in range(g.height):
            for x in range(g.width):
                if t[x, y][3] and gp[x, y][3]:
                    m.setdefault(t[x, y][:3], gp[x, y][:3])
    return m


def main() -> None:
    im = Image.open(SHEET).convert("RGBA")
    comp = layer(im, LAYERS[0])
    for dy in LAYERS[1:]:
        comp.alpha_composite(layer(im, dy))
    boots = layer(im, BOOTS)
    gmap = gold_map()
    frames = []
    for f, (feet_x, feet_y) in split(comp, layer(im, LAYERS[3]), boots):
        canvas = Image.new("RGBA", (CANVAS, CANVAS))
        canvas.alpha_composite(f, (FEET[0] - feet_x, FEET[1] - feet_y))
        frames.append(canvas)
    for skin, recolor in (("x_tri", None), ("x_gold", gmap)):
        out = ROOT / "assets/characters" / skin
        names = []
        for n, f in enumerate(frames):
            if recolor:
                f = f.copy()
                p = f.load()
                for y in range(f.height):
                    for x in range(f.width):
                        if p[x, y][3] and p[x, y][:3] in recolor:
                            p[x, y] = (*recolor[p[x, y][:3]], 255)
            name = f"zsaber_{n}.png"
            f.save(out / name)
            names.append(name)
        meta = json.loads((out / "frames.json").read_text())
        meta["zsaber"] = {"fps": FPS, "frames": names, "loop": False}
        (out / "frames.json").write_text(json.dumps(meta))
    print(len(frames), "quadros")


if __name__ == "__main__":
    main()
