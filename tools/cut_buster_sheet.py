"""Buster do X1, X2 e X3 recortado da folha de referência (assets/ref/x_weapons_items.png).

Cada linha da folha vai da saída do cano ao impacto: pontinhos, formação, voo e anéis do impacto.
Os índices abaixo são os quadros da linha, na ordem da folha (separados por coluna vazia).
Saída: assets/shots/<x1|x2|x3>/ com shots.json (lemon, lemon_hit, medium_form, medium_fly, medium_hit,
form, fly, hit). Quadros do voo ficam alinhados pela frente do tiro (borda direita); os do impacto, pelo centro.
Uso: python3 tools/cut_buster_sheet.py
"""
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from cut_ref_sheets import REF, ROOT, frames, keyed  # noqa: E402

# Linhas da folha: (x0, y0, x1, y1)
ROWS = {
    "lemon_x12": (112, 248, 200, 264),
    "lv1_x12": (112, 266, 640, 294),
    "lv2_x1": (112, 308, 640, 346),
    "lv2_x2": (112, 428, 640, 468),
    "lemon_x3": (112, 526, 200, 546),
    "lv1_x3": (112, 554, 640, 585),
    "lv2_x3": (112, 584, 640, 625),
}
LV1_X12 = {"medium_form": ("lv1_x12", [3, 4, 5, 6]), "medium_fly": ("lv1_x12", [7, 8, 9, 10]),
           "medium_hit": ("lv1_x12", list(range(11, 19)))}
GAMES = {
    "x1": {"lemon": ("lemon_x12", [0]), "lemon_hit": ("lemon_x12", [1, 2, 3]), **LV1_X12,
           "form": ("lv2_x1", [4, 5]), "fly": ("lv2_x1", [6, 7, 8]), "hit": ("lv2_x1", list(range(9, 17)))},
    "x2": {"lemon": ("lemon_x12", [0]), "lemon_hit": ("lemon_x12", [1, 2, 3]), **LV1_X12,
           "form": ("lv2_x2", [3, 4]), "fly": ("lv2_x2", [5, 6, 7]), "hit": ("lv2_x2", list(range(8, 16)))},
    "x3": {"lemon": ("lemon_x3", [0]), "lemon_hit": ("lemon_x3", [1, 2, 3]),
           "medium_form": ("lv1_x3", [2, 3, 4, 5]), "medium_fly": ("lv1_x3", [6, 7, 8, 9]),
           "medium_hit": ("lv1_x3", list(range(10, 18))),
           "form": ("lv2_x3", [4, 5]), "fly": ("lv2_x3", [6, 7, 8]), "hit": ("lv2_x3", list(range(13, 21)))},
}


def pad(imgs, front: bool):
    """Mesma tela para todos os quadros: alinhados pela frente (direita) ou pelo centro."""
    w = max(i.width for i in imgs)
    h = max(i.height for i in imgs)
    out = []
    for i in imgs:
        c = Image.new("RGBA", (w, h))
        c.paste(i, (w - i.width if front else (w - i.width) // 2, (h - i.height) // 2))
        out.append(c)
    return out


def main() -> None:
    sheet = keyed(REF / "x_weapons_items.png")
    rows = {k: list(frames(sheet, box, 1)) for k, box in ROWS.items()}
    for game, anims in GAMES.items():
        out = ROOT / "assets/shots" / game
        out.mkdir(parents=True, exist_ok=True)
        for old in [*out.glob("*.png"), *out.glob("*.png.import")]:
            old.unlink()
        meta = {}
        for anim, (row, idx) in anims.items():
            imgs = pad([rows[row][i] for i in idx], front=not anim.endswith("hit"))
            meta[anim] = []
            for n, img in enumerate(imgs):
                name = f"{anim}_{n}.png"
                img.save(out / name)
                meta[anim].append(name)
        json.dump(meta, open(out / "shots.json", "w"), indent=1)
        print(game, {a: len(v) for a, v in meta.items()})


if __name__ == "__main__":
    main()
