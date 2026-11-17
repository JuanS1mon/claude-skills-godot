"""Convierte una imagen generada por IA en pixel art real.

Pasos: quitar el fondo (opcional), recortar al contenido, reducir a la grilla
de píxeles, limitar la paleta y guardar (también ampliada con vecino más cercano).

Uso:
    python tools/pixelizar.py entrada.png salida.png --tamano 64 --colores 16
"""
import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def quitar_fondo(img, tolerancia):
    """Hace transparente el fondo: rellena desde los bordes los píxeles
    parecidos al color de las esquinas."""
    img = img.convert("RGBA")
    ancho, alto = img.size
    px = img.load()
    esquinas = [px[0, 0], px[ancho - 1, 0], px[0, alto - 1], px[ancho - 1, alto - 1]]
    fondo = tuple(sorted(c[i] for c in esquinas)[1] for i in range(3))  # mediana

    def parecido(c):
        return sum(abs(c[i] - fondo[i]) for i in range(3)) <= tolerancia * 3

    visitado = [[False] * alto for _ in range(ancho)]
    cola = deque()
    for x in range(ancho):
        cola.append((x, 0))
        cola.append((x, alto - 1))
    for y in range(alto):
        cola.append((0, y))
        cola.append((ancho - 1, y))
    while cola:
        x, y = cola.popleft()
        if x < 0 or y < 0 or x >= ancho or y >= alto or visitado[x][y]:
            continue
        visitado[x][y] = True
        if not parecido(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        cola.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return img


def pixelizar(img, tamano, colores, umbral_alfa=128):
    """Reduce al lado mayor `tamano` y cuantiza la paleta a `colores`."""
    img = img.convert("RGBA")
    caja = img.getchannel("A").point(lambda a: 255 if a > 0 else 0).getbbox()
    if caja:
        img = img.crop(caja)

    ancho, alto = img.size
    escala = tamano / max(ancho, alto)
    nuevo = (max(1, round(ancho * escala)), max(1, round(alto * escala)))
    # BOX promedia el bloque de píxeles que cae en cada celda de la grilla.
    img = img.resize(nuevo, Image.BOX)

    # Alfa binario (sin bordes semitransparentes) y paleta limitada.
    alfa = img.getchannel("A").point(lambda a: 255 if a >= umbral_alfa else 0)
    rgb = img.convert("RGB").quantize(colors=colores, method=Image.MEDIANCUT, dither=Image.NONE)
    salida = rgb.convert("RGBA")
    salida.putalpha(alfa)
    return salida


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("entrada", type=Path)
    p.add_argument("salida", type=Path)
    p.add_argument("--tamano", type=int, default=64, help="lado mayor en píxeles reales (por defecto 64)")
    p.add_argument("--colores", type=int, default=16, help="tamaño de la paleta (por defecto 16)")
    p.add_argument("--sin-fondo", action="store_true", help="no quitar el fondo")
    p.add_argument("--tolerancia", type=int, default=40, help="tolerancia al quitar el fondo (0-255)")
    p.add_argument("--ampliar", type=int, default=8, help="además guarda una copia x N con vecino más cercano (0 = no)")
    a = p.parse_args()

    img = Image.open(a.entrada)
    if not a.sin_fondo:
        img = quitar_fondo(img, a.tolerancia)
    resultado = pixelizar(img, a.tamano, a.colores)
    a.salida.parent.mkdir(parents=True, exist_ok=True)
    resultado.save(a.salida)
    print(f"{a.salida} ({resultado.width}x{resultado.height})")

    if a.ampliar > 1:
        grande = resultado.resize((resultado.width * a.ampliar, resultado.height * a.ampliar), Image.NEAREST)
        ruta = a.salida.with_name(f"{a.salida.stem}_x{a.ampliar}{a.salida.suffix}")
        grande.save(ruta)
        print(f"{ruta} ({grande.width}x{grande.height})")


if __name__ == "__main__":
    main()
