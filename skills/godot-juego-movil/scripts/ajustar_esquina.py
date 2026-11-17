"""Prepara el fondo de una habitación en esquina isométrica a partir de la imagen de la IA (9:16, esquina arriba al centro).
Uso: python tools/ajustar_esquina.py entrada.webp salida.png
Escala a 720 de ancho, corta una banda de pared lisa de 270 px (la esquina sube a y~375, como GeometriaCuarto.esquina) y
estira el piso por abajo repitiendo filas con la traslación vertical que mejor alinea las tablas o losetas."""
import sys, numpy as np
from PIL import Image
BANDA, DESDE = 270, 40
im = Image.open(sys.argv[1]).convert("RGB")
W = 720; H = round(im.height * W / im.width)
a = np.asarray(im.resize((W, H), Image.LANCZOS))
b = np.concatenate([a[:DESDE], a[DESDE + BANDA:]], axis=0)
falta = 1280 - b.shape[0]
af = a.astype(float)
mejor = min(((np.abs(af[H-300:H] - af[H-300-T:H-T]).mean(), T) for T in range(150, 420)))
T = mejor[1]
filas = [b[b.shape[0] - T + (i % T)] for i in range(falta)]   # si falta > T se repite cíclicamente
c = np.concatenate([b, np.array(filas)], axis=0)[:1280]
Image.fromarray(c).save(sys.argv[2])
print(sys.argv[2], c.shape, "traslación", T, "error", round(mejor[0], 2))
