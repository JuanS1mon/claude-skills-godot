"""Compone la animación de Zarita tomando mate sobre su cuadro de reposo de frente.

Pone el termo en la mano izquierda (de la imagen) y el mate en la derecha; para tomar,
levanta el mate hasta el hocico moviendo la mano con él y dibujando el antebrazo.
Los props salen de tools/dibujar_props_mate.py.

Uso:
    python tools/componer_mate.py carpeta_props carpeta_salida
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
BASE = RAIZ / "assets" / "zarita" / "caminata" / "abajo" / "zarita_abajo_2.png"
K = 4  # los props se amplían x4 (el cuadro tiene píxeles de unos 3-4 px)

MANO_TERMO = (28, 304, 76, 356)    # mano izquierda de la imagen (caja)
MANO_MATE = (214, 312, 262, 360)   # mano derecha de la imagen (caja)
PUNO = (238, 316)                  # donde acaba la manga del brazo que levanta
HOCICO = (150, 210)
CONTORNO = (62, 36, 38, 255)


def oscuro(px):
    return px[3] > 0 and px[0] < 125 and px[1] < 95 and px[2] < 85


def solo_mano(img, caja):
    """Recorta la mano marrón (con su contorno) y deja el resto transparente."""
    x0, y0, x1, y1 = caja
    mano = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    for y in range(y0, y1):
        for x in range(x0, x1):
            p = img.getpixel((x, y))
            if oscuro(p):
                mano.putpixel((x - x0, y - y0), p)
    return mano


def borrar_mano(img, caja):
    x0, y0, x1, y1 = caja
    for y in range(y0, y1):
        for x in range(x0, x1):
            if oscuro(img.getpixel((x, y))):
                img.putpixel((x, y), (0, 0, 0, 0))


def color_manga(img):
    muestra = [img.getpixel((x, y)) for x in range(224, 238) for y in range(268, 286)]
    muestra = [p for p in muestra if p[3] > 0]
    return tuple(sorted(c[i] for c in muestra)[len(muestra) // 2] for i in range(3)) + (255,)


def ampliar(p):
    return p.resize((p.width * K, p.height * K), Image.NEAREST)


def brazo(lienzo, a, b, relleno):
    d = ImageDraw.Draw(lienzo)
    for ancho, color in ((34, CONTORNO), (26, relleno)):
        d.line([a, b], fill=color, width=ancho)
        for p in (a, b):
            r = ancho // 2
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=color)


def componer(mate, termo, mate_pos, levantado, relleno):
    """mate_pos = esquina superior izquierda del mate."""
    lienzo = Image.open(BASE).convert("RGBA")
    pata_termo = solo_mano(lienzo, MANO_TERMO)
    pata_mate = solo_mano(lienzo, MANO_MATE)

    # termo en la mano izquierda: detrás de la pata
    cx = (MANO_TERMO[0] + MANO_TERMO[2]) // 2
    lienzo.alpha_composite(termo, (cx - termo.width // 2 - 2, MANO_TERMO[1] + 22 - termo.height // 2))
    lienzo.alpha_composite(pata_termo, MANO_TERMO[:2])

    mx, my = mate_pos
    if levantado:
        borrar_mano(lienzo, MANO_MATE)
        base = (mx + mate.width // 2, my + mate.height - 12)
        brazo(lienzo, PUNO, base, relleno)
        lienzo.alpha_composite(mate, (mx, my))
        lienzo.alpha_composite(pata_mate, (base[0] - pata_mate.width // 2, base[1] - pata_mate.height // 2 - 6))
    else:
        # reposo: el mate apoyado sobre la pata (la pata sigue siendo la del cuadro original)
        lienzo.alpha_composite(mate, (mx, my))
        lienzo.alpha_composite(pata_mate, MANO_MATE[:2])
    return lienzo


if __name__ == "__main__":
    props = Path(sys.argv[1])
    salida = Path(sys.argv[2])
    salida.mkdir(parents=True, exist_ok=True)
    mate = ampliar(Image.open(props / "mate.png").convert("RGBA"))
    termo = ampliar(Image.open(props / "termo.png").convert("RGBA"))
    relleno = color_manga(Image.open(BASE).convert("RGBA"))

    # reposo: el mate descansa sobre la pata derecha, un poco más abajo del puño
    reposo = (238 - mate.width // 2, 338 - mate.height + 10)
    # al sorber, la punta de la bombilla (arriba a la derecha del mate) toca el hocico
    punta = (12 * K, 0)
    sorbo = (HOCICO[0] - punta[0], HOCICO[1] - punta[1])
    medio = ((reposo[0] + sorbo[0]) // 2 + 8, (reposo[1] + sorbo[1]) // 2)

    cuadros = [
        ("1_reposo", reposo, False),
        ("2_sube", medio, True),
        ("3_sorbo", sorbo, True),
        ("4_sorbo_abajo", (sorbo[0], sorbo[1] + 4), True),
        ("5_baja", medio, True),
        ("6_reposo", reposo, False),
    ]
    for nombre, pos, levantado in cuadros:
        componer(mate, termo, pos, levantado, relleno).save(salida / f"mate_{nombre}.png")
        print(nombre, pos)
