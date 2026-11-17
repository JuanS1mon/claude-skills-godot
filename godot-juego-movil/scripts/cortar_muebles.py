"""Corta una hoja de muebles sobre fondo verde en piezas sueltas con fondo transparente.

uso: cortar_muebles.py entrada carpeta_salida nombre1 nombre2 ... (en orden: filas de arriba abajo, de izquierda a derecha)
"""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

entrada, carpeta, nombres = sys.argv[1], sys.argv[2], sys.argv[3:]
n = len(nombres)

img = Image.open(entrada).convert("RGB")
a = np.array(img).astype(np.float32)
h, w = a.shape[:2]

# Color de fondo: mediana de un marco fino alrededor de la imagen.
marco = np.concatenate([a[:6].reshape(-1, 3), a[-6:].reshape(-1, 3), a[:, :6].reshape(-1, 3), a[:, -6:].reshape(-1, 3)])
bg = np.median(marco, axis=0)
print("color de fondo:", bg.astype(int), " variacion en el marco:", marco.std(axis=0).round(1))

dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
# Fondo = (1) verde casi exacto en cualquier sitio (huecos entre travesaños de la silla, etc.)
#       + (2) verde parecido pero SOLO si está conectado con el borde de la imagen. Así no se
#             borran las hojas verdes de la planta, que están rodeadas por su contorno.
import os
UMBRAL = float(os.environ.get("UMBRAL", "45"))   # las hojas verdes quedan a 49-62 del fondo; los restos del fondo, a <40
solido = dist >= UMBRAL
if os.environ.get("QUITAVERDE"):   # solo para piezas sin nada verde (silla)
    solido &= ~(((a[..., 1] - a[..., 0]) > 45) & ((a[..., 1] - a[..., 2]) > 45))
solido = ndimage.binary_opening(solido, structure=np.ones((2, 2)))   # quita motas sueltas
# Rellena huecos diminutos dentro de una pieza (píxeles claros de las hojas), pero no los huecos reales.
huecos, nh = ndimage.label(~solido)
bordes_h = np.unique(np.concatenate([huecos[0], huecos[-1], huecos[:, 0], huecos[:, -1]]))
for i in range(1, nh + 1):
    if i not in bordes_h and (huecos == i).sum() < int(os.environ.get("RELLENO", "40")):
        solido[huecos == i] = True
# Quita la capa de 1 px del borde, contaminada por el verde del fondo.
solido = ndimage.binary_erosion(solido, structure=ndimage.generate_binary_structure(2, 1), iterations=1)

# Quita el verde de los bordes (solo en los 2 px junto al fondo, para no alterar el verde menta interior).
transparente = ~solido
cerca = ndimage.binary_dilation(transparente, iterations=2) & solido
r, g, b = a[..., 0], a[..., 1], a[..., 2]
g_nuevo = np.where(cerca & (g > np.maximum(r, b)), np.maximum(r, b), g)
a[..., 1] = g_nuevo

rgba = np.dstack([a, solido * 255.0]).astype(np.uint8)

etiquetas, total = ndimage.label(solido, structure=np.ones((3, 3)))
areas = ndimage.sum(solido, etiquetas, index=range(1, total + 1))
orden = np.argsort(areas)[::-1]
principales = [int(i) + 1 for i in orden[:n]]
print("componentes:", total, " areas de las", n, "mayores:", sorted(int(areas[p - 1]) for p in principales)[::-1])
print("la menor de las principales y la mayor de las descartadas:", int(min(areas[p - 1] for p in principales)),
      int(max([areas[i] for i in range(total) if (i + 1) not in principales] or [0])))

objetos = ndimage.find_objects(etiquetas)
cx = {p: (objetos[p - 1][1].start + objetos[p - 1][1].stop) / 2 for p in principales}
cy = {p: (objetos[p - 1][0].start + objetos[p - 1][0].stop) / 2 for p in principales}

# Filas: se ordenan por altura y se reparten en grupos iguales.
filas = 3
por_fila = n // filas
por_y = sorted(principales, key=lambda p: cy[p])
ordenadas = []
for f in range(filas):
    grupo = sorted(por_y[f * por_fila:(f + 1) * por_fila], key=lambda p: cx[p])
    ordenadas.extend(grupo)

# Piezas sueltas pequeñas -> a la principal más cercana.
asigna = {p: [p] for p in principales}
for i in range(1, total + 1):
    if i in principales or areas[i - 1] < 4:
        continue
    y, x = ndimage.center_of_mass(etiquetas == i)
    cercano = min(principales, key=lambda p: (cx[p] - x) ** 2 + (cy[p] - y) ** 2)
    asigna[cercano].append(i)

fondo_prueba = Image.new("RGBA", (260 * 4, 260 * 3), (250, 198, 141, 255))
for k, p in enumerate(ordenadas):
    m = np.isin(etiquetas, asigna[p])
    pieza = rgba.copy()
    pieza[~m] = 0
    im = Image.fromarray(pieza, "RGBA")
    caja = im.getchannel("A").getbbox()
    im = im.crop((max(caja[0] - 2, 0), max(caja[1] - 2, 0), min(caja[2] + 2, w), min(caja[3] + 2, h)))
    im.save(f"{carpeta}/{nombres[k]}.png")
    print(f"{nombres[k]:18s} {im.size[0]:4d} x {im.size[1]:4d}")
    tile = im.copy()
    tile.thumbnail((240, 240), Image.NEAREST)
    fondo_prueba.alpha_composite(tile, ((k % 4) * 260 + 10, (k // 4) * 260 + 10))
fondo_prueba.convert("RGB").save(f"{carpeta}/_comprobacion.png")
