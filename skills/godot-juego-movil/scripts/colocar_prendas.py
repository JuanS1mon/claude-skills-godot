"""Coloca las prendas (piezas limpias) sobre los cuadros de reposo de Zarita y guarda las capas del tamaño de cada cuadro.
Parámetros por prenda y vista: (cx, arriba, ancho, alto) = centro horizontal de la parte de arriba de la prenda, su borde de
arriba, y el tamaño final, en píxeles del cuadro de Zarita."""
import json
import sys
from PIL import Image

ZA = "D:/zarita-la zarigueya/assets/zarita/caminata/"
MARCOS = {"abajo": "abajo/zarita_abajo_2.png", "arriba": "arriba/zarita_arriba_2.png", "derecha": "derecha/zarita_derecha_2.png"}
VISTA_DE = {"abajo": "frente", "arriba": "espalda", "derecha": "costado"}

# (cx, arriba, ancho, alto)
PARAMS = {
    "poncho": {
        "abajo": (153, 214, 250, 160),
        "arriba": (133, 212, 232, 160),
        "derecha": (228, 214, 135, 160),
    },
    "bufanda": {
        "abajo": (152, 216, 126, 132),
        "arriba": (133, 214, 124, 80),
        "derecha": (232, 214, 96, 136),
    },
}
if len(sys.argv) > 1:
    PARAMS.update(json.load(open(sys.argv[1])))


def capa(prenda, direccion):
    marco = Image.open(ZA + MARCOS[direccion]).convert("RGBA")
    pieza = Image.open(f"limpia_{prenda}_{VISTA_DE[direccion]}.png")
    cx, arriba, ancho, alto = PARAMS[prenda][direccion]
    pieza = pieza.resize((ancho, alto), Image.LANCZOS)
    # los píxeles semitransparentes del reescalado pasan a opacos o transparentes
    a = pieza.getchannel("A").point(lambda v: 255 if v > 120 else 0)
    pieza.putalpha(a)
    lienzo = Image.new("RGBA", marco.size, (0, 0, 0, 0))
    lienzo.alpha_composite(pieza, (int(cx - ancho / 2), int(arriba)))
    return marco, lienzo


for prenda in PARAMS:
    previas = []
    for d in MARCOS:
        marco, c = capa(prenda, d)
        c.save(f"capa_{prenda}_{d}.png")
        base = Image.new("RGBA", marco.size, (235, 225, 205, 255))
        base.alpha_composite(marco)
        base.alpha_composite(c)
        previas.append(base)
    W = Image.new("RGBA", (sum(p.width for p in previas) + 20 * 4, 500), (235, 225, 205, 255))
    x = 20
    for p in previas:
        W.alpha_composite(p, (x, 10))
        x += p.width + 20
    W.save(f"prueba_ropa_{prenda}.png")
print("ok")
