"""Suma cuadros nuevos (de otra hoja de IA) a un personaje ya recortado, a la misma escala.

Uso: python unir_cuadros.py <carpeta_personaje> <carpeta_nuevos> <cuadro_viejo_ref> <cuadro_nuevo_ref>
- Escala los nuevos para que <cuadro_nuevo_ref> tenga la misma altura visible que <cuadro_viejo_ref>
  (elegir dos poses equivalentes, p. ej. la pose de cargar de cada hoja).
- Copia los nuevos a la carpeta del personaje (reemplazando los del mismo nombre) y lleva TODOS los
  cuadros a un lienzo común: centrados en x (los lienzos ya vienen simétricos al torso) y pies abajo.
Imprime el tamaño del lienzo final: hay que ajustar la altura del sprite en Godot ((alto/2 - 2) * pixel_size).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def alto_visible(im: Image.Image) -> int:
    a = np.array(im)[..., 3] > 80
    ys = np.nonzero(a.any(axis=1))[0]
    return int(ys.max() - ys.min() + 1)


def main():
    personaje, nuevos, ref_viejo, ref_nuevo = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], sys.argv[4]
    escala = alto_visible(Image.open(personaje / f"{ref_viejo}.png")) / alto_visible(Image.open(nuevos / f"{ref_nuevo}.png"))
    print(f"escala de los nuevos: {escala:.3f}")
    for p in nuevos.glob("*.png"):
        im = Image.open(p)
        im = im.resize((round(im.width * escala), round(im.height * escala)), Image.LANCZOS)
        im.save(personaje / p.name)

    cuadros = {p: Image.open(p) for p in personaje.glob("*.png")}
    ancho = max(im.width for im in cuadros.values())
    ancho += ancho % 2
    alto = max(im.height for im in cuadros.values())
    for p, im in cuadros.items():
        a = np.array(im)[..., 3] > 20
        abajo = np.nonzero(a.any(axis=1))[0].max()
        lienzo = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
        lienzo.alpha_composite(im, ((ancho - im.width) // 2, alto - 2 - abajo - 1))
        lienzo.save(p)
    print(f"{len(cuadros)} cuadros en lienzo {ancho}x{alto}")


if __name__ == "__main__":
    main()
