"""Fase de introdução do X1 a partir do mapa (rip de darksamus993, só local: assets/stages/ fica fora do git).
Uso: python3 tools/build_x1_intro.py <mapa.png>
O mapa tem a frente (pistas, pilares, postes) em y 4..467 e o fundo (cidade) em y 490..842, preto = vazio.
Saída em assets/stages/x1_intro/:
  fg_NN.png / bg_NN.png  faixas de 1024 px (1x) ampliadas 3x com Scale3x, para o jogo desenhar a 1/3 com
                         filtro linear: o contorno do pixel art fica liso em vez de serrilhado
  stage.json             tamanho das camadas e colisão: retângulos de blocos 16×16 onde a maioria dos pixels
                         é do verde da pista (postes, carros e a rampa do fundo ficam de fora)"""
import json, os, sys
from PIL import Image

FG = (0, 0, 7689, 480)
BG = (9, 490, 3554, 842)
STRIP = 1024
TILE = 16
## Peças soltas que o mapa desenha fora do lugar (x0, y0, x1, y1): a plataforma que cai repetida embaixo
## dela, as caixinhas ao lado, os pedaços da ponte quebrada caindo, as moitas atrás da pista final, o
## prédio verde de vidro e o poste perto dele (o verde deles parece pista).
## Topos de poste (1 bloco) também saem.
DROP = [(2130, 370, 2460, 440), (2140, 370, 2180, 440), (3960, 236, 4860, 310), (6580, 130, 7690, 192),
        (5400, 0, 5560, 112), (5770, 40, 5800, 144)]
OUT = os.path.join(os.path.dirname(__file__), "..", "assets/stages/x1_intro")


def transparent(im):
    im = im.convert("RGBA")
    im.putdata([(r, g, b, 0 if r == g == b == 0 else 255) for r, g, b, a in im.get_flattened_data()])
    return im


def scale3x(im):
    w, h = im.size
    src = list(im.get_flattened_data())
    out = Image.new("RGBA", (w * 3, h * 3))
    dst = [None] * (w * 3 * h * 3)
    W = w * 3
    for y in range(h):
        ym, yp = max(y - 1, 0), min(y + 1, h - 1)
        for x in range(w):
            xm, xp = max(x - 1, 0), min(x + 1, w - 1)
            A, B, C = src[ym * w + xm], src[ym * w + x], src[ym * w + xp]
            D, E, F = src[y * w + xm], src[y * w + x], src[y * w + xp]
            G, H, I = src[yp * w + xm], src[yp * w + x], src[yp * w + xp]
            e = [E] * 9
            if B != H and D != F:
                if D == B: e[0] = D
                if (D == B and E != C) or (B == F and E != A): e[1] = B
                if B == F: e[2] = F
                if (D == B and E != G) or (D == H and E != A): e[3] = D
                if (B == F and E != I) or (H == F and E != C): e[5] = F
                if D == H: e[6] = D
                if (D == H and E != I) or (H == F and E != G): e[7] = H
                if H == F: e[8] = F
            o = (y * 3) * W + x * 3
            dst[o:o + 3] = e[0:3]
            dst[o + W:o + W + 3] = e[3:6]
            dst[o + 2 * W:o + 2 * W + 3] = e[6:9]
    out.putdata(dst)
    return out


def strips(im, name):
    n = 0
    for x in range(0, im.width, STRIP):
        scale3x(im.crop((x, 0, min(x + STRIP, im.width), im.height))).save(os.path.join(OUT, f"{name}_{n:02d}.png"))
        n += 1
    return n


## Trechos só de pista (começo, plataforma que cai, topo dos pilares, pista final): as cores deles são
## as cores do "chão". Assim prédios de vidro esverdeado, postes e carros não viram parede.
DECK = [(48, 128, 800, 176), (2200, 276, 2470, 316), (4318, 78, 4380, 104), (7300, 192, 7680, 224)]


def collision(fg):
    w, h = fg.size
    px = fg.load()
    deck = {c for box in DECK for c in fg.crop(box).get_flattened_data() if c[3] and c[1] >= c[0] + 10 and c[1] >= c[2] + 8}
    green = lambda p: p in deck
    solid = [[sum(green(px[tx * TILE + i, ty * TILE + j]) for i in range(TILE) for j in range(TILE)) * 2 >= TILE * TILE
              for tx in range(w // TILE)] for ty in range(h // TILE)]
    # Junta blocos vizinhos: faixas por linha, depois linhas iguais empilhadas.
    rects, open_ = [], {}
    for ty, row in enumerate(solid + [[False] * (w // TILE)]):
        runs, tx = set(), 0
        while tx < len(row):
            if row[tx]:
                s = tx
                while tx < len(row) and row[tx]:
                    tx += 1
                runs.add((s, tx))
            tx += 1
        for run in list(open_):
            if run not in runs:
                start = open_.pop(run)
                rects.append([run[0] * TILE, start * TILE, (run[1] - run[0]) * TILE, (ty - start) * TILE])
        for run in runs:
            open_.setdefault(run, ty)
    keep = lambda r: r[2] * r[3] > TILE * TILE and not any(
        x0 <= r[0] and r[0] + r[2] <= x1 and y0 <= r[1] and r[1] + r[3] <= y1 for x0, y0, x1, y1 in DROP)
    return slopes(fg, [r for r in rects if keep(r)], green)


## Rampas: em blocos de 16 px elas viram escada e o X trava no degrau. Onde o topo da pista sobe ou
## desce aos poucos (1 a 12 px a cada 8 px), troca os blocos por fatias inclinadas que seguem o desenho.
SLOPE_STEP = 8
SLOPE_DEPTH = 24


def slopes(fg, rects, green):
    w, h = fg.size
    px = fg.load()

    def top(x):
        run = 0
        for y in range(h):
            run = run + 1 if green(px[x, y]) else 0
            if run == 6:
                return y - 5
        return None

    surf = [top(x) for x in range(w)]
    cells = [x for x in range(0, w - SLOPE_STEP, SLOPE_STEP)
             if surf[x] is not None and surf[x + SLOPE_STEP] is not None and 1 <= abs(surf[x] - surf[x + SLOPE_STEP]) <= 12]
    zones, polys = [], []
    for x in cells:
        if zones and x - zones[-1][1] <= SLOPE_STEP:
            zones[-1][1] = x + SLOPE_STEP
        else:
            zones.append([x, x + SLOPE_STEP])
    # Rampa de verdade: larga e sempre no mesmo sentido (postes e bordas de pilar dão falsos trechos curtos).
    # As pontas podem ter um degrau no sentido contrário (emenda com a pista reta): saem antes do teste.
    def ramp(z):
        d = [surf[x + SLOPE_STEP] - surf[x] for x in range(z[0], z[1] - SLOPE_STEP + 1, SLOPE_STEP)]
        sign = 1 if sum(d) > 0 else -1
        while d and d[0] * sign < 0:
            d.pop(0)
            z[0] += SLOPE_STEP
        while d and d[-1] * sign < 0:
            d.pop()
            z[1] -= SLOPE_STEP
        return z[1] - z[0] >= 64 and all(v * sign >= 0 for v in d) and abs(sum(d)) >= 16
    zones = [z for z in zones if ramp(z)]
    for xa, xb in zones:
        xa, xb = max(xa - 2 * SLOPE_STEP, 0), min(xb + 2 * SLOPE_STEP, w - 1)
        bottom = max(surf[x] for x in range(xa, xb + 1) if surf[x] is not None) + SLOPE_DEPTH
        for x in range(xa, xb, SLOPE_STEP):
            a, b = surf[x], surf[min(x + SLOPE_STEP, w - 1)]
            if a is not None and b is not None:
                polys.append([[x, a], [x + SLOPE_STEP, b], [x + SLOPE_STEP, bottom], [x, bottom]])
        cut = []
        for r in rects:
            rx, ry, rw, rh = r
            if rx + rw <= xa or rx >= xb or ry >= bottom:
                cut.append(r)
                continue
            if rx < xa:
                cut.append([rx, ry, xa - rx, rh])
            if rx + rw > xb:
                cut.append([xb, ry, rx + rw - xb, rh])
            if ry + rh > bottom:
                x0, x1 = max(rx, xa), min(rx + rw, xb)
                cut.append([x0, bottom, x1 - x0, ry + rh - bottom])
        rects = cut
    # Topo de cada bloco no chão desenhado (a grade de 16 px deixa degraus de até 15 px nas emendas).
    for r in rects:
        near = sorted(surf[x] for x in range(r[0], min(r[0] + r[2], w)) if surf[x] is not None and abs(surf[x] - r[1]) <= 12)
        if len(near) * 2 >= r[2]:
            top = near[len(near) // 2]
            r[3] += r[1] - top
            r[1] = top
    return rects, polys


def main():
    src = Image.open(sys.argv[1])
    os.makedirs(OUT, exist_ok=True)
    fg = transparent(src.crop(FG))
    bg = transparent(src.crop(BG))
    rects, polys = collision(fg)
    meta = {"fg": {"size": fg.size, "strips": strips(fg, "fg")}, "bg": {"size": bg.size, "strips": strips(bg, "bg")},
            "strip": STRIP, "scale": 3, "solids": rects, "slopes": polys}
    json.dump(meta, open(os.path.join(OUT, "stage.json"), "w"))
    print(len(rects), "blocos de colisão,", len(polys), "fatias de rampa")


main()
