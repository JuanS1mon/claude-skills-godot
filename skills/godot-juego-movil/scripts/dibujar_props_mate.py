"""Dibuja a mano (mapa de píxeles) el mate y el termo como sprites sueltos con transparencia.

SD 1.5 no sabe dibujar un mate, así que los props se definen píxel a píxel.
Uso:
    python tools/dibujar_props_mate.py carpeta_salida
"""
import sys
from pathlib import Path

from PIL import Image

PALETA = {
    "K": (43, 26, 20),     # contorno marrón oscuro
    "k": (40, 40, 48),     # tapa negra del termo
    "D": (90, 96, 110),    # acero oscuro
    "S": (170, 178, 190),  # acero
    "s": (205, 212, 222),  # acero claro
    "W": (245, 247, 250),  # brillo
    "B": (150, 90, 45),    # calabaza
    "b": (185, 120, 65),   # calabaza clara
    "d": (105, 62, 32),    # calabaza sombra
    "G": (120, 170, 60),   # yerba
    "g": (80, 125, 40),    # yerba oscura
}

MATE = [
    "...........sS...",
    "..........sS....",
    ".........sS.....",
    "........sS......",
    ".......sS.......",
    "...KKKKsKKKKKK..",
    "..KGGGSGGGGGGK..",
    "..KGgGGGGgGGGK..",
    ".KKbbbbbbbbbbKK.",
    ".KBBBBBBBBBBBBK.",
    ".KBBbBBBBBBBBBK.",
    ".KBBbBBBBBBBBBK.",
    ".KBBBBBBBBBBBdK.",
    ".KBBBBBBBBBBddK.",
    "..KBBBBBBBBddK..",
    "...KBBBBBBddK...",
    "....KKBBBBKK....",
    "......KKKK......",
]

CUERPO = ".KsWSSSsDDK."
BANDA = ".KDDDDDDDDK."
TERMO = (
    ["...KKKKKK..."]
    + ["..KkkkkkK...", "..KkkkkkK..."]
    + [".KKDDDDDDKK."]
    + [CUERPO] * 4 + [BANDA] + [CUERPO] * 11 + [BANDA] + [CUERPO] * 3
    + [".KKDDDDDDKK.", "..KKKKKKKK.."]
)


def dibujar(mapa):
    ancho = len(mapa[0])
    assert all(len(f) == ancho for f in mapa), "filas de distinto largo"
    img = Image.new("RGBA", (ancho, len(mapa)), (0, 0, 0, 0))
    for y, fila in enumerate(mapa):
        for x, c in enumerate(fila):
            if c != ".":
                img.putpixel((x, y), PALETA[c] + (255,))
    return img


if __name__ == "__main__":
    salida = Path(sys.argv[1])
    salida.mkdir(parents=True, exist_ok=True)
    for nombre, mapa in (("mate", MATE), ("termo", TERMO)):
        img = dibujar(mapa)
        img.save(salida / f"{nombre}.png")
        print(nombre, img.size)
