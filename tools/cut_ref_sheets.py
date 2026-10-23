"""Recorta das folhas de referência (assets/ref/, The Spriters Resource) o que não foi gravado dos originais.

Cada região é uma faixa da folha; os quadros são separados por colunas vazias (fundo da folha).
Saída: assets/fx/<nome>/NNN.png e assets/weapons/icons/<id>.png. Uso: python3 tools/cut_ref_sheets.py
"""
import json
from collections import Counter
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
REF = ROOT / "assets/ref"

# (folha, nome, caixa x0,y0,x1,y1, colunas vazias que separam quadros)
REGIONS = [
    ("x_effects.png", "dash_spark", (15, 124, 295, 155), 3),
    ("x_effects.png", "dash_smoke", (0, 170, 170, 192), 1),
    ("x_effects.png", "wall_kick", (0, 200, 14, 214), 1),
    ("x_effects.png", "wall_slide", (0, 225, 110, 241), 1),
    ("x_weapons_items.png", "zsaber_wave", (95, 726, 248, 776), 2),
    ("x_weapons_items.png", "zsaber_hit", (248, 726, 460, 776), 2),
    ("x_weapons_items.png", "zsaber_slash", (460, 726, 675, 776), 2),
    ("x_weapons_items.png", "hadouken", (46, 976, 162, 998), 3),
    ("x_weapons_items.png", "shoryuken", (803, 1066, 864, 1104), 3),
    ("x_weapons_items.png", "item_tracer", (488, 1220, 866, 1254), 3),
    ("x_weapons_items.png", "life_small", (0, 134, 72, 147), 1),
    ("x_weapons_items.png", "life_big", (0, 147, 72, 164), 1),
    ("x_weapons_items.png", "weapon_small", (78, 134, 128, 147), 1),
    ("x_weapons_items.png", "weapon_big", (78, 147, 128, 164), 1),
    ("x_weapons_items.png", "one_up", (132, 140, 175, 164), 1),
    ("x_weapons_items.png", "heart_tank", (178, 140, 240, 164), 1),
    ("x_weapons_items.png", "sub_tank", (244, 138, 292, 166), 1),
    ("x_weapons_items.png", "lifebar", (0, 10, 612, 72), 1),
]

# Ícones do menu de armas (linha y=75..91), na ordem do menu de cada jogo.
ICON_ROW = (75, 91)
ICONS = {
    "x1": (2, ["buster", "homing_torpedo", "chameleon_sting", "rolling_shield", "fire_wave",
               "storm_tornado", "electric_spark", "boomerang_cutter", "shotgun_ice", "exit"]),
    "x2": (190, ["buster", "crystal_hunter", "bubble_splash", "silk_shot", "spin_wheel", "sonic_slicer",
                 "strike_chain", "magnet_mine", "speed_burner", "giga_crush", "item_tracer", "exit"]),
    "x3": (414, ["buster", "acid_burst", "parasitic_bomb", "triad_thunder", "spinning_blade", "ray_splasher",
                 "gravity_well", "frost_shield", "tornado_fang", "hyper_charge", "exit"]),
}
ICON_PITCH = 18


def keyed(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    bg = Counter(im.convert("RGB").getdata()).most_common(1)[0][0]
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][:3] == bg:
                px[x, y] = (0, 0, 0, 0)
    return im


def frames(im: Image.Image, box, gap):
    x0, y0, x1, y1 = box
    px = im.load()
    used = [any(px[x, y][3] for y in range(y0, y1)) for x in range(x0, x1)]
    spans, start, blank = [], None, 0
    for i, u in enumerate(used + [False] * (gap + 1)):
        if u:
            start = i if start is None else start
            blank, last = 0, i
        elif start is not None:
            blank += 1
            if blank > gap:
                spans.append((x0 + start, x0 + last + 1))
                start = None
    for a, b in spans:
        crop = im.crop((a, y0, b, y1))
        yield crop.crop(crop.getbbox())


def main() -> None:
    sheets = {}
    for sheet, name, box, gap in REGIONS:
        im = sheets.setdefault(sheet, keyed(REF / sheet))
        out = ROOT / "assets/fx" / name
        out.mkdir(parents=True, exist_ok=True)
        for old in out.glob("*.png"):
            old.unlink()
        n = 0
        for n, f in enumerate(frames(im, box, gap), 1):
            f.save(out / f"{n - 1:03d}.png")
        print(f"{name}: {n} quadros")
    im = sheets["x_weapons_items.png"]
    out = ROOT / "assets/weapons/icons"
    out.mkdir(parents=True, exist_ok=True)
    for game, (x, ids) in ICONS.items():
        for i, wid in enumerate(ids):
            a = x + i * ICON_PITCH
            im.crop((a, ICON_ROW[0], a + 16, ICON_ROW[1])).save(out / f"{game}_{wid}.png")
    print("ícones:", sum(len(v[1]) for v in ICONS.values()))
    # Onda do Z-Saber como tiro do buster (Projectile, style "zsaber"): cresce, voa no último quadro, impacto.
    zs = ROOT / "assets/shots/zsaber"
    zs.mkdir(parents=True, exist_ok=True)
    meta = {}
    for anim, (src, idx) in {"form": ("zsaber_wave", [0, 1, 2]), "fly": ("zsaber_wave", [3]),
                             "hit": ("zsaber_hit", [0, 1, 2, 3])}.items():
        meta[anim] = []
        for n, i in enumerate(idx):
            name = f"{anim}_{n}.png"
            Image.open(ROOT / "assets/fx" / src / f"{i:03d}.png").save(zs / name)
            meta[anim].append(name)
    (zs / "shots.json").write_text(json.dumps(meta, indent=1))


if __name__ == "__main__":
    main()
