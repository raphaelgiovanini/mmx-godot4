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
    return [r for r in rects if keep(r)]


def main():
    src = Image.open(sys.argv[1])
    os.makedirs(OUT, exist_ok=True)
    fg = transparent(src.crop(FG))
    bg = transparent(src.crop(BG))
    rects = collision(fg)
    meta = {"fg": {"size": fg.size, "strips": strips(fg, "fg")}, "bg": {"size": bg.size, "strips": strips(bg, "bg")},
            "strip": STRIP, "scale": 3, "solids": rects}
    json.dump(meta, open(os.path.join(OUT, "stage.json"), "w"))
    print(len(rects), "blocos de colisão")


main()
