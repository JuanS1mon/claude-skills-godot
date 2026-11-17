"""Corta la hoja de miniaturas de habitaciones (fondo magenta, 4 en fila) en assets/mapa/habitaciones/<id>.png.
Uso: python tools/cortar_habitaciones.py hoja.png carpeta_salida. Orden izquierda->derecha: sala, dormitorio, cocina, bano."""
import sys, os, numpy as np
from PIL import Image
from scipy import ndimage as ndi
IDS = ["sala", "dormitorio", "cocina", "bano"]
im = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(float)
r, g, b = im[..., 0], im[..., 1], im[..., 2]
mag = np.minimum(r, b) - g
M = np.percentile(mag, 95)
a = 1 - np.clip((mag - 0.05 * M) / (0.75 * M), 0, 1)
bg = np.array([np.median(im[:6, :6, c]) for c in range(3)])
fg = np.clip((im - (1 - a)[..., None] * bg) / np.maximum(a, 1e-3)[..., None], 0, 255)
semi = (a > 0) & (a < 1)
for c in (0, 2):
    fg[..., c] = np.where(semi, np.minimum(fg[..., c], fg[..., 1] + 30), fg[..., c])
rgba = np.dstack([fg, a * 255]).astype(np.uint8)
mascara = ndi.binary_fill_holes(ndi.binary_closing(a > 0.3, iterations=3))
lab, n = ndi.label(mascara)
cajas = sorted(ndi.find_objects(lab), key=lambda s: s[1].start)
grandes = [s for s in cajas if (s[0].stop - s[0].start) > 60 and (s[1].stop - s[1].start) > 60]
assert len(grandes) == 4, f"se esperaban 4 habitaciones y hay {len(grandes)}"
os.makedirs(sys.argv[2], exist_ok=True)
for id_, s in zip(IDS, grandes):
    pieza = Image.fromarray(rgba[s])
    pieza.save(os.path.join(sys.argv[2], id_ + ".png"))
    print(id_, pieza.size)
