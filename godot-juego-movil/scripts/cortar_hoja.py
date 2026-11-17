import sys
import numpy as np
from PIL import Image

entrada, columnas, carpeta, prefijo = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]

img = Image.open(entrada).convert("RGBA")
a = np.array(img).astype(np.int32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
dominio = g - np.maximum(r, b)
alfa = np.where(dominio >= 90, 0.0, np.where(dominio <= 40, 1.0, (90 - dominio) / 50.0))
a[..., 1] = np.where(dominio > 0, np.minimum(g, np.maximum(r, b) + 8), g)
a[..., 3] = (alfa * 255).astype(np.int32)
res = Image.fromarray(a.astype(np.uint8), "RGBA")

ancho = res.width // columnas
cuadros = [res.crop((i * ancho, 0, (i + 1) * ancho, res.height)) for i in range(columnas)]

# Caja común: la unión del contenido de todos los cuadros, para conservar la alineación.
cajas = [c.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox() for c in cuadros]
x0 = min(c[0] for c in cajas); y0 = min(c[1] for c in cajas)
x1 = max(c[2] for c in cajas); y1 = max(c[3] for c in cajas)
m = 6
caja = (max(x0 - m, 0), max(y0 - m, 0), min(x1 + m, ancho), min(y1 + m, res.height))
print("cajas por cuadro:", cajas)
print("caja comun:", caja, "tamaño:", (caja[2] - caja[0], caja[3] - caja[1]))

hoja = Image.new("RGBA", ((caja[2] - caja[0]) * columnas, caja[3] - caja[1]))
for i, c in enumerate(cuadros):
    rec = c.crop(caja)
    rec.save(f"{carpeta}/{prefijo}_{i + 1}.png")
    hoja.paste(rec, (i * rec.width, 0))
hoja.save(f"{carpeta}/{prefijo}_hoja.png")
print("hoja:", hoja.size)

# Comprobación visual sobre el color del suelo.
fondo = Image.new("RGBA", hoja.size, (185, 154, 114, 255))
fondo.alpha_composite(hoja)
fondo.convert("RGB").save(f"{carpeta}/{prefijo}_comprobacion.png")
