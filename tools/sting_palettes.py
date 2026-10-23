#!/usr/bin/env python3
"""Ciclo de cores do Chameleon Sting carregado (X1) → "sting_0".."sting_7" em assets/weapons/palettes.json.

Uso: sting_palettes.py <rom_x1> [assets/weapons]
A rotina do carregado (chargeShot_camaFlash, 83:9B88) troca a paleta do X a cada 6 frames por 480 frames.
As 8 paletas vêm da tabela de cargas de paleta 86:8133 + $1A0 + fase (fases 0, 2 … 14), como no recomp
(MmxRenderAssetsStingPalette): listas de 4 bytes [qtd, ptr 16 bits no banco 85, índice de CGRAM]; o corpo
do X está nos índices 144–159. A paleta padrão do X é achada na ROM como a sequência de 32 bytes igual a
todas as fases nos índices que nenhuma fase muda (mesmo método do weapon_palettes.py). Ordem da saída =
ordem do jogo (a gravação começa na fase 2: laranja, verde, verde-escuro, azul, preto, roxo, vinho, vermelho).
"""
import json
import os
import sys


def bgr555(v):
    return [(v & 31) << 3, (v >> 5 & 31) << 3, (v >> 10 & 31) << 3]


rom = open(sys.argv[1], "rb").read()
rom = rom[512:] if len(rom) % 32768 == 512 else rom
dest = sys.argv[2] if len(sys.argv) > 2 else "assets/weapons"
word = lambda a: rom[a] | rom[a + 1] << 8

phases = []
for ph in range(0, 16, 2):
    cols = {}
    lst = 0x30000 + (word(0x30133 + 0x1A0 + ph) & 0x7FFF)
    while rom[lst]:
        src = 0x28000 + (word(lst + 1) & 0x7FFF)
        for i in range(rom[lst]):
            e = rom[lst + 3] + i - 144
            if 0 <= e < 16:
                cols[e] = word(src + i * 2)
        lst += 4
    phases.append(cols)

fixed = [i for i in range(16) if all(i in p for p in phases) and len({p[i] for p in phases}) == 1]
changed = [i for i in range(16) if i not in fixed and all(i in p for p in phases)]
default = None
for off in range(0, len(rom) - 32, 2):
    if all(word(off + i * 2) == phases[0][i] for i in fixed):
        pal = [word(off + i * 2) for i in range(16)]
        if all(pal[i] != p[i] for p in phases for i in changed[:1]) and len(set(pal)) >= 12:
            default = pal
            break
assert default, "paleta padrão do X não achada"

path = os.path.join(dest, "palettes.json")
out = json.load(open(path))
order = phases[1:] + phases[:1]
for k, p in enumerate(order):
    out["sting_%d" % k] = [[bgr555(default[i]) for i in changed], [bgr555(p[i]) for i in changed]]
json.dump(out, open(path, "w"))
print("sting: %d cores trocadas, padrão %s" % (len(changed), [bgr555(default[i]) for i in changed]))
