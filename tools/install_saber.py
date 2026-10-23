#!/usr/bin/env python3
"""Acrescenta os golpes de sabre do mmx8 aos sprites do Zero e do Black Zero (assets/characters/).

Uso: install_saber.py <mmx8-16bit>   (rodar depois de tools/export_mmx8_skins.gd)
Fonte: src/Actors/Player/skins/zero/saber/frames/ (Zashiko Mod, uso não comercial).
Os quadros do sabre (208×96) são centrados como os do corpo (96×96), então entram direto no
frames.json. 30 fps: os quadros cobrem start+active+recovery do golpe (ex.: saber_a 15 quadros = 30 frames).
"""
import json
import os
import re
import shutil
import sys

src = os.path.join(sys.argv[1], "src/Actors/Player/skins/zero/saber/frames")
root = os.path.join(os.path.dirname(__file__), "..", "assets/characters")
anims = {}
for f in os.listdir(src):
    m = re.fullmatch(r"(.+)_(\d+)\.png", f)
    if m:
        anims.setdefault(m.group(1), []).append((int(m.group(2)), f))
for skin, prefix in (("zero", ""), ("zero_black", "black_")):
    dest = os.path.join(root, skin)
    meta_path = os.path.join(dest, "frames.json")
    meta = json.load(open(meta_path))
    for name, files in anims.items():
        if not name.startswith(prefix) or (prefix == "" and name.startswith("black_")) or name == "wave":
            continue
        anim = name[len(prefix):]
        frames = []
        for _, f in sorted(files):
            out = "sb_" + f
            shutil.copy(os.path.join(src, f), os.path.join(dest, out))
            frames.append(out)
        meta[anim] = {"fps": 30, "frames": frames, "loop": False}
    json.dump(meta, open(meta_path, "w"))
    print(skin, sorted(a for a in meta if a.startswith("saber")))
