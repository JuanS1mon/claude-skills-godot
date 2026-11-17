"""Centra la cabeza de los cuadros de la derecha en el medio del lienzo y crea los de la izquierda espejados."""
import sys
import numpy as np
from PIL import Image, ImageOps

carpeta_der, carpeta_izq = sys.argv[1], sys.argv[2]


def centro_cabeza(im):
    al = np.array(im.getchannel("A")) > 8
    ys = np.where(al.any(axis=1))[0]
    alto = ys.max() - ys.min() + 1
    zona = al[ys.min(): ys.min() + int(alto * 0.35)]
    xs = np.where(zona.any(axis=0))[0]
    return (xs.min() + xs.max()) / 2


cuadros = [Image.open(f"{carpeta_der}/zarita_derecha_{i}.png").convert("RGBA") for i in range(1, 5)]
centros = [centro_cabeza(c) for c in cuadros]
print("centros de cabeza antes:", [round(c, 1) for c in centros])
izq = max(centros)
der = max(c.width - cb for c, cb in zip(cuadros, centros))
mitad = int(np.ceil(max(izq, der)))
W = 2 * mitad
print("ancho nuevo:", W, "(antes", cuadros[0].width, ")")

for i, (c, cb) in enumerate(zip(cuadros, centros), start=1):
    lienzo = Image.new("RGBA", (W, c.height), (0, 0, 0, 0))
    lienzo.alpha_composite(c, (int(round(mitad - cb)), 0))
    lienzo.save(f"{carpeta_der}/zarita_derecha_{i}.png")
    ImageOps.mirror(lienzo).save(f"{carpeta_izq}/zarita_izquierda_{i}.png")
    print("cuadro", i, "centro cabeza ahora:", round(centro_cabeza(lienzo), 1))
