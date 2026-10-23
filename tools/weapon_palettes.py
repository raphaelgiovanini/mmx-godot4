#!/usr/bin/env python3
"""Paleta do X para cada arma, como nos jogos originais → assets/weapons/palettes.json.

Uso: weapon_palettes.py <weapons_x1 do Mesen> <recomp> <rom_x2> <rom_x3> <assets/weapons>
Cores em 5 bits por canal deslocadas << 3, o formato dos sprites exportados do mmx8 (paleta do X1).
  X1: compara, pixel a pixel, o X parado com o buster (w9_select) e com cada arma (wN_select).
  X2/X3: paleta de corpo de cada arma (x_weapon_assets.json, lida da ROM); a paleta padrão do X é
  achada na ROM como a sequência de 32 bytes igual a todas as paletas de arma nos índices que nenhuma
  arma muda. Troca índice a índice: padrão[i] → arma[i].
Saída: {arma: [[de], [para]]}; de/para em 0..255.
"""
import json
import os
import sys
from collections import Counter, defaultdict

from PIL import Image

X1 = ["homing_torpedo", "chameleon_sting", "rolling_shield", "fire_wave",
      "storm_tornado", "electric_spark", "boomerang_cutter", "shotgun_ice"]


def snes(c):
    """Cor do Mesen ((v << 3) | (v >> 2)) → 5 bits << 3."""
    return tuple((v >> 3) << 3 for v in c)


def bgr555(lo, hi):
    c = lo | hi << 8
    return ((c & 31) << 3, (c >> 5 & 31) << 3, (c >> 10 & 31) << 3)


src, recomp, x2, x3, dest = sys.argv[1:6]
out = {}
base = Image.open(os.path.join(src, "w9_select.png")).convert("RGB")
bp = base.load()
W, H = base.size
bg = Counter(base.getdata()).most_common(1)[0][0]
xs = [(x, y) for y in range(H) for x in range(40, W) if bp[x, y] != bg]
X0, Y0 = min(p[0] for p in xs), min(p[1] for p in xs)
X1_, Y1 = max(p[0] for p in xs), max(p[1] for p in xs)
for i, name in enumerate(X1):
    im = Image.open(os.path.join(src, f"w{i + 1}_select.png")).convert("RGB")
    q = im.load()
    snes_bg = Counter(im.getdata()).most_common(1)[0][0]
    pairs = defaultdict(Counter)
    # Só a caixa do X parado; arma e fundo ficam de fora.
    for y in range(Y0, Y1 + 1):
        for x in range(X0, X1_ + 1):
            if bp[x, y] == bg or q[x, y] == snes_bg:
                continue
            a, b = snes(bp[x, y]), snes(q[x, y])
            if q[x, y] == snes_bg:
                continue
            if a != b:
                pairs[a][b] += 1
    # Só trocas consistentes (o fundo e outros objetos mudam sem padrão).
    mapping = {a: c.most_common(1)[0][0] for a, c in pairs.items() if c.most_common(1)[0][1] >= 8}
    out[name] = [[list(a) for a in mapping], [list(b) for b in mapping.values()]]
    print(name, len(mapping))

rom_data = {}
for game, path in ((2, x2), (3, x3)):
    data = open(path, "rb").read()
    rom_data[game] = data[512:] if len(data) % 32768 == 512 else data
entries = json.load(open(os.path.join(recomp, "tools/data/x_weapon_assets.json")))
for game in (2, 3):
    rom = rom_data[game]
    pals = {e["name"]: rom[int(e["body_palette"], 16):int(e["body_palette"], 16) + 32] for e in entries if e["game"] == game}
    fixed = [i for i in range(16) if len({p[i * 2:i * 2 + 2] for p in pals.values()}) == 1]
    first = next(iter(pals.values()))
    default = None
    for off in range(0, len(rom) - 32, 2):
        chunk = rom[off:off + 32]
        if all(chunk[i * 2:i * 2 + 2] == first[i * 2:i * 2 + 2] for i in fixed) and chunk not in pals.values():
            if len({chunk[i * 2:i * 2 + 2] for i in range(16)}) >= 12:
                default = chunk
                break
    print("X%d default palette %s, fixed %d" % (game, "found" if default else "MISSING", len(fixed)))
    for name, pal in pals.items():
        frm, to = [], []
        for i in range(16):
            if i in fixed or default is None:
                continue
            frm.append(list(bgr555(default[i * 2], default[i * 2 + 1])))
            to.append(list(bgr555(pal[i * 2], pal[i * 2 + 1])))
        out[name.lower().replace(" ", "_")] = [frm, to]
json.dump(out, open(os.path.join(dest, "palettes.json"), "w"))
