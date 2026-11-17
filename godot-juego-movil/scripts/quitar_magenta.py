"""Quita el fondo magenta plano (#FF00FF) de una imagen de IA y recorta al contenido.
Uso: python tools/quitar_magenta.py entrada.webp salida.png [ancho_final]
Magentez = min(r, b) - g (el fondo ronda 200+). alfa = 1 - clip((magentez - 0,05·M) / (0,75·M)); los píxeles
semitransparentes se desmezclan del fondo y se les quita el tinte (despill). Si se da `ancho_final`, reescala (LANCZOS)."""
import sys, numpy as np
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
ancho = int(sys.argv[3]) if len(sys.argv) > 3 else None
im = np.asarray(Image.open(src).convert("RGB")).astype(float)
r, g, b = im[..., 0], im[..., 1], im[..., 2]
mag = np.minimum(r, b) - g
M = np.percentile(mag, 95)
a = 1 - np.clip((mag - 0.05 * M) / (0.75 * M), 0, 1)
bg = np.array([np.median(im[:8, :8, c]) for c in range(3)])
al = np.maximum(a, 1e-3)[..., None]
fg = np.clip((im - (1 - a)[..., None] * bg) / al, 0, 255)
semi = (a > 0) & (a < 1)
tope = np.where(semi, g * 1.0 + 0.0, 255)   # despill: r y b no pueden pasar mucho a g en el borde
fg[..., 0] = np.where(semi, np.minimum(fg[..., 0], np.maximum(fg[..., 1], 0) + 30), fg[..., 0])
fg[..., 2] = np.where(semi, np.minimum(fg[..., 2], np.maximum(fg[..., 1], 0) + 30), fg[..., 2])
img = Image.fromarray(np.dstack([fg, a * 255]).astype(np.uint8))
img = img.crop(img.getchannel("A").point(lambda v: 255 if v > 77 else 0).getbbox())
if ancho:
    img = img.resize((ancho, round(img.height * ancho / img.width)), Image.LANCZOS)
img.save(out)
print(out, img.size)
