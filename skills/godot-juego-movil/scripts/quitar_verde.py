import sys
import numpy as np
from PIL import Image

entrada, salida = sys.argv[1], sys.argv[2]
img = Image.open(entrada).convert("RGBA")
a = np.array(img).astype(np.int32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]

# Cuánto domina el verde sobre el resto: el fondo ronda (30, 230, 20).
dominio = g - np.maximum(r, b)
# Fondo seguro: verde muy dominante. Borde: transición suave.
alfa = np.clip((90 - dominio) / (90 - 40), 0, 1)
alfa = np.where(dominio >= 90, 0.0, np.where(dominio <= 40, 1.0, alfa))

# Quita el halo verde en los bordes: el verde no puede superar al rojo/azul.
tope = np.maximum(r, b)
g_nuevo = np.where(dominio > 0, np.minimum(g, tope + 8), g)

a[..., 1] = g_nuevo
a[..., 3] = (alfa * 255).astype(np.int32)
res = Image.fromarray(a.astype(np.uint8), "RGBA")

# Recorta al contenido con un margen pequeño.
caja = res.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
margen = 8
caja = (max(caja[0] - margen, 0), max(caja[1] - margen, 0),
        min(caja[2] + margen, res.width), min(caja[3] + margen, res.height))
res = res.crop(caja)
res.save(salida)
print("entrada", img.size, "-> salida", res.size, "caja", caja)
