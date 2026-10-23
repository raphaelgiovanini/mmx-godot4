"""Gera os símbolos lisos (sem serrilhado) da placa do HUD em alta resolução.
Uso: python3 tools/make_emblems.py
  assets/fx/emblem_x.png     X vetorial nas cores do ícone da folha "Lifebars" (assets/fx/lifebar/000.png)
  assets/fx/emblem_zero.png  logo do Zero (assets/ref/zero_logo.png) sobre a mesma placa
O HUD desenha estes PNGs reduzidos com filtro linear; desenhados em 4x e reduzidos, as bordas saem
suavizadas.
"""
from PIL import Image, ImageDraw

W, H = 112, 128          # 14×16 da folha, 8×
SS = 4                   # supersample
OUT = "assets/fx/emblem_%s.png"
DARK, WHITE, GREY, LIGHT = (24, 24, 24), (248, 248, 248), (136, 136, 136), (192, 192, 192)
CYAN, BLUE = (40, 208, 248), (40, 120, 192)


def plate():
    im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = SS * 8 / 8.0
    d.rounded_rectangle((0, 0, W * SS - 1, H * SS - 1), radius=14 * s, fill=DARK)
    d.rounded_rectangle((7 * s, 6 * s, W * SS - 7 * s, H * SS - 18 * s), radius=10 * s, fill=WHITE)
    d.rounded_rectangle((7 * s, H * SS - 26 * s, W * SS - 7 * s, H * SS - 9 * s), radius=8 * s, fill=GREY)
    d.rectangle((7 * s, H * SS - 30 * s, W * SS - 7 * s, H * SS - 22 * s), fill=WHITE)
    return im, d, s


def finish(im, name):
    im.resize((W, H), Image.LANCZOS).save(OUT % name)


def make_x():
    im, d, s = plate()
    # X itálico de pontas cortadas, como o da folha: traço de trás em azul, o da frente em ciano.
    def stroke(pts, color):
        q = [(x * s, y * s) for x, y in pts]
        d.polygon(q, fill=DARK, outline=DARK, width=int(7 * s))
        d.polygon(q, fill=color)
    stroke([(24, 26), (46, 26), (92, 92), (70, 92)], BLUE)
    stroke([(20, 92), (42, 92), (94, 26), (72, 26)], CYAN)
    d.polygon([(x * s, y * s) for x, y in [(30, 86), (36, 86), (78, 32), (72, 32)]], fill=(190, 245, 255))
    finish(im, "x")


def make_zero():
    im, d, s = plate()
    logo = Image.open("assets/ref/zero_logo.png").convert("RGBA")
    # Tira o fundo e o contorno de adesivo (branco/cinza claro), deixa o Z e a estrela.
    px = logo.load()
    for y in range(logo.height):
        for x in range(logo.width):
            r, g, b, a = px[x, y]
            if r > 225 and g > 225 and b > 225:
                px[x, y] = (0, 0, 0, 0)
    logo = logo.crop(logo.getbbox())
    box = (int(10 * s), int(10 * s), int(W * SS - 10 * s), int(H * SS - 32 * s))
    bw, bh = box[2] - box[0], box[3] - box[1]
    k = min(bw / logo.width, bh / logo.height)
    logo = logo.resize((int(logo.width * k), int(logo.height * k)), Image.LANCZOS)
    im.alpha_composite(logo, (box[0] + (bw - logo.width) // 2, box[1] + (bh - logo.height) // 2))
    finish(im, "zero")


if __name__ == "__main__":
    make_x()
    make_zero()
    for n in ("x", "zero"):
        assert Image.open(OUT % n).size == (W, H)
    print("ok")
