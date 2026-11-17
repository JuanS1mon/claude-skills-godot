"""Recorta las texturas de una hoja generada por IA: rectángulos separados por bordes verdes (#00FF00).

Uso: python cortar_texturas.py hoja.jpg carpeta_salida nombre1,nombre2,...   (orden: filas de arriba abajo, izq a der)
Un nombre "-" descarta ese rectángulo. Recorta MARGEN px hacia adentro para no arrastrar el borde verdoso del JPG.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

MARGEN = 6


def main():
    hoja, salida, nombres = sys.argv[1], Path(sys.argv[2]), sys.argv[3].split(",")
    salida.mkdir(parents=True, exist_ok=True)
    rgb = np.array(Image.open(hoja).convert("RGB")).astype(int)
    verde = (rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2])) > 60
    etiquetas, n = ndimage.label(~verde)
    cajas = [c for c in ndimage.find_objects(etiquetas)
             if (c[0].stop - c[0].start) * (c[1].stop - c[1].start) > 0.02 * verde.size]
    cajas.sort(key=lambda c: (round(c[0].start / 80), c[1].start))
    for caja, nombre in zip(cajas, nombres):
        y0, y1 = caja[0].start + MARGEN, caja[0].stop - MARGEN
        x0, x1 = caja[1].start + MARGEN, caja[1].stop - MARGEN
        print(f"{nombre}: x {x0}-{x1}, y {y0}-{y1} ({x1 - x0}x{y1 - y0})")
        if nombre != "-":
            Image.open(hoja).convert("RGB").crop((x0, y0, x1, y1)).save(salida / f"{nombre}.png")


if __name__ == "__main__":
    main()
