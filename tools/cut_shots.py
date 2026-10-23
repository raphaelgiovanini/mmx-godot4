#!/usr/bin/env python3
"""Recorta os tiros das capturas do Mesen (fundo escondido: só sprites sobre a cor de fundo).

Uso: cut_shots.py <pasta_capturas> <pasta_saida> <prefixo> [<prefixo> ...]
Para cada captura <prefixo>_NN.png, pega o que está à frente do braço do X e na altura dele,
recorta numa caixa só e salva com fundo transparente em <saida>/<prefixo>_NN.png.
MAXX limita a área à direita (também na referência). MAIN=1 guarda só o corpo do tiro, sem faíscas. FLIP=1 espelha as capturas (X atirando para a esquerda). A posição do X vem de REF (padrão lemon_01.png): o maior componente fora da barra de vida.
O X fica parado na captura, então tudo à direita dessa caixa é tiro.
"""
import glob
import os
import sys

from PIL import Image


def components(mask, w, h):
    seen = bytearray(w * h)
    comps = []
    for start in range(w * h):
        if not mask[start] or seen[start]:
            continue
        stack, pix = [start], []
        seen[start] = 1
        while stack:
            i = stack.pop()
            pix.append(i)
            x, y = i % w, i // w
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    j = ny * w + nx
                    if 0 <= nx < w and 0 <= ny < h and mask[j] and not seen[j]:
                        seen[j] = 1
                        stack.append(j)
        xs = [i % w for i in pix]
        ys = [i // w for i in pix]
        comps.append((min(xs), min(ys), max(xs), max(ys), len(pix)))
    return comps


def load(path):
    im = Image.open(path).convert("RGB")
    if os.environ.get("FLIP"):  # X virado para a esquerda: espelha para o tiro ficar à direita
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    w, h = im.size
    px = list(im.get_flattened_data())
    bg = max(set(px), key=px.count)
    mask = bytearray(1 if p != bg else 0 for p in px)
    for y in range(h):
        for x in range(w // 8):  # barra de vida
            mask[y * w + x] = 0
    return im, w, h, bg, mask


def main():
    src, dst, prefixes = sys.argv[1], sys.argv[2], sys.argv[3:]
    os.makedirs(dst, exist_ok=True)
    _, w, h, _, mask = load(os.path.join(src, os.environ.get("REF", "lemon_01.png")))
    for y in range(h):
        for x in range(int(os.environ.get("MAXX", w)), w):
            mask[y * w + x] = 0
    player = max(components(mask, w, h), key=lambda c: c[4])
    right, mid = player[2], (player[1] + player[3]) / 2
    print(f"X de referência em x={player[0]}..{right}, y={player[1]}..{player[3]}")
    for prefix in prefixes:
        for path in sorted(glob.glob(os.path.join(src, prefix + "_*.png"))):
            im, w, h, bg, mask = load(path)
            maxx = int(os.environ.get("MAXX", w))  # ignora o que estiver depois de MAXX (ex.: um chefe)
            for y in range(h):
                for x in list(range(right + 1)) + list(range(maxx, w)):
                    mask[y * w + x] = 0
            shots = [c for c in components(mask, w, h) if abs((c[1] + c[3]) / 2 - mid) < 40]
            if not shots:
                continue
            if os.environ.get("MAIN"):  # só o corpo do tiro: maior componente e o que encosta nele
                big = max(shots, key=lambda c: c[4])
                shots = [c for c in shots if c[0] <= big[2] + 3 and c[2] >= big[0] - 3 and c[1] <= big[3] + 3 and c[3] >= big[1] - 3]
            box = (min(c[0] for c in shots), min(c[1] for c in shots), max(c[2] for c in shots) + 1, max(c[3] for c in shots) + 1)
            crop = im.crop(box).convert("RGBA")
            crop.putdata([(r, g, b, 0) if (r, g, b) == bg else (r, g, b, 255) for r, g, b, a in crop.get_flattened_data()])
            name = os.path.basename(path)
            crop.save(os.path.join(dst, name))
            print(f"{name}: {crop.size[0]}x{crop.size[1]} em x={box[0]},y={box[1]}")


if __name__ == "__main__":
    main()
