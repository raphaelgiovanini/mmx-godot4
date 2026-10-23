#!/usr/bin/env python3
"""Recorta as poses de um chefe das capturas do Mesen (fundo escondido) e guarda só as distintas.

Uso: cut_boss.py <pasta_capturas> <pasta_saida> [area_minima=150]
- Ignora as barras de vida (1/8 de cada lado) e a caixa do X, achada como o que aparece parado em
  quase todas as capturas (o X fica imóvel enquanto o chefe age).
- Em cada captura, o chefe é o maior componente fora dessa caixa, mais o que encosta nele.
- Poses repetidas (mesmos pixels) são descartadas; espelhadas também (o chefe vira de lado).
Saída: <saida>/pose_NNN.png (fundo transparente, virado para a esquerda como no jogo) e poses.txt
com a captura de origem e a posição dos pés.
"""
import glob
import hashlib
import os
import sys
from collections import Counter

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cut_shots import components  # noqa: E402


def main():
    src, dst = sys.argv[1], sys.argv[2]
    min_area = int(sys.argv[3]) if len(sys.argv) > 3 else 150
    os.makedirs(dst, exist_ok=True)
    files = sorted(glob.glob(os.path.join(src, "f*.png")))
    ims = [Image.open(f).convert("RGB") for f in files]
    w, h = ims[0].size
    datas = [list(im.get_flattened_data()) for im in ims]
    bg = Counter(datas[0]).most_common(1)[0][0]
    # pixel "parado": diferente do fundo em >70% das capturas. O X é o maior bloco parado
    # fora das barras de vida (1/8 de cada lado da tela).
    edge = w // 8
    still = bytearray(1 if edge < i % w < w - edge and sum(1 for d in datas if d[i] != bg) > 0.7 * len(datas) else 0 for i in range(w * h))
    blocks = components(still, w, h)
    x = max(blocks, key=lambda c: c[4]) if blocks else (0, 0, -1, -1, 0)
    xbox = (x[0] - 4, x[1] - 4, x[2] + 4, x[3] + 4)
    print("caixa do X:", xbox)
    seen, n, lines = set(), 0, []
    for f, im, d in zip(files, ims, datas):
        mask = bytearray(1 if p != bg else 0 for p in d)
        for y in range(h):
            for x in range(w):
                if x < edge or x >= w - edge or (xbox[0] <= x <= xbox[2] and xbox[1] <= y <= xbox[3]):
                    mask[y * w + x] = 0
        comps = [c for c in components(mask, w, h) if c[4] >= 4]
        if not comps:
            continue
        big = max(comps, key=lambda c: c[4])
        if big[4] < min_area:
            continue
        group = [c for c in comps if c[0] <= big[2] + 2 and c[2] >= big[0] - 2 and c[1] <= big[3] + 2 and c[3] >= big[1] - 2]
        box = (min(c[0] for c in group), min(c[1] for c in group), max(c[2] for c in group) + 1, max(c[3] for c in group) + 1)
        crop = im.crop(box).convert("RGBA")
        crop.putdata([(r, g, b, 0) if (r, g, b) == bg else (r, g, b, 255) for r, g, b, a in crop.get_flattened_data()])
        # Normaliza para olhar à esquerda: se o lado mais "pesado" do sprite não bate, compara as duas versões.
        key = hashlib.sha1(crop.tobytes()).hexdigest()
        key_m = hashlib.sha1(crop.transpose(Image.FLIP_LEFT_RIGHT).tobytes()).hexdigest()
        if key in seen or key_m in seen:
            continue
        seen.add(key)
        name = f"pose_{n:03d}.png"
        crop.save(os.path.join(dst, name))
        lines.append(f"{name}\t{os.path.basename(f)}\tx={box[0]}\ty={box[1]}\tw={crop.width}\th={crop.height}\tpes={box[3]}")
        n += 1
    open(os.path.join(dst, "poses.txt"), "w").write("\n".join(lines) + "\n")
    print(n, "poses distintas")


if __name__ == "__main__":
    main()
