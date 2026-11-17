"""Corta una hoja de caminata por los huecos vacíos entre cuadros, quita el fondo verde,
normaliza el tamaño (alto del cuadro neutral) y alinea todos los cuadros en un lienzo común
con el centro de la cabeza en el medio.

uso: armar_direccion.py entrada n_cuadros carpeta_salida prefijo alto_objetivo
"""
import sys
import numpy as np
from PIL import Image

entrada, n, carpeta, prefijo, alto_obj = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4], int(sys.argv[5])

UNIR = int(sys.argv[6]) if len(sys.argv) > 6 else 12   # huecos menores que esto no separan cuadros
img = Image.open(entrada).convert("RGBA")
a = np.array(img).astype(np.int32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
dominio = g - np.maximum(r, b)
alfa = np.where(dominio >= 90, 0.0, np.where(dominio <= 40, 1.0, (90 - dominio) / 50.0))
a[..., 1] = np.where(dominio > 0, np.minimum(g, np.maximum(r, b) + 8), g)
a[..., 3] = (alfa * 255).astype(np.int32)
res = Image.fromarray(a.astype(np.uint8), "RGBA")

# Segmentos: tramos de columnas con contenido, separados por huecos vacíos.
ocupada = (np.array(res.getchannel("A")) > 8).any(axis=0)
tramos, inicio = [], None
for x, o in enumerate(ocupada):
    if o and inicio is None:
        inicio = x
    elif not o and inicio is not None:
        tramos.append([inicio, x]); inicio = None
if inicio is not None:
    tramos.append([inicio, len(ocupada)])
# Une tramos muy cercanos (huecos < 12 px) y descarta motas minúsculas.
unidos = []
for t in tramos:
    if unidos and t[0] - unidos[-1][1] < UNIR:
        unidos[-1][1] = t[1]
    else:
        unidos.append(t)
unidos = [t for t in unidos if t[1] - t[0] > 40]
print("tramos encontrados:", unidos)
if len(unidos) != n:
    sys.exit(f"ERROR: se esperaban {n} cuadros y hay {len(unidos)}")

cuadros = []
for x0, x1 in unidos:
    c = res.crop((x0, 0, x1, res.height))
    caja = c.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    cuadros.append(c.crop(caja))          # recorte exacto al contenido
# Posición vertical original (para conservar el balanceo entre cuadros).
tops = []
for (x0, x1) in unidos:
    c = res.crop((x0, 0, x1, res.height))
    tops.append(c.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()[1])

# Escala: el cuadro neutral (el 2) pasa a medir alto_obj.
s = alto_obj / cuadros[1].height
print("escala:", round(s, 3))
esc, tops_e = [], []
for c, t in zip(cuadros, tops):
    nuevo = c.resize((max(1, round(c.width * s)), max(1, round(c.height * s))), Image.LANCZOS)
    esc.append(nuevo); tops_e.append(round(t * s))
tmin = min(tops_e)

def centro_cabeza(im):
    al = np.array(im.getchannel("A")) > 8
    h = al.shape[0]
    xs = np.where(al[: int(h * 0.35)].any(axis=0))[0]
    return (xs.min() + xs.max()) / 2

cab = [centro_cabeza(c) for c in esc]
izq = max(cab); der = max(c.width - cb for c, cb in zip(esc, cab))
pad = 10
W = int(round(izq + der)) + 2 * pad
H = max(t - tmin + c.height for c, t in zip(esc, tops_e)) + 2 * pad
ancla = pad + izq                          # x donde queda el centro de la cabeza
lienzos = []
for i, (c, t, cb) in enumerate(zip(esc, tops_e, cab)):
    lz = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lz.alpha_composite(c, (int(round(ancla - cb)), pad + t - tmin))
    lz.save(f"{carpeta}/{prefijo}_{i + 1}.png")
    lienzos.append(lz)
hoja = Image.new("RGBA", (W * n, H))
for i, lz in enumerate(lienzos):
    hoja.paste(lz, (i * W, 0))
hoja.save(f"{carpeta}/{prefijo}_hoja.png")
fondo = Image.new("RGBA", hoja.size, (185, 154, 114, 255))
fondo.alpha_composite(hoja)
fondo.convert("RGB").save(f"{carpeta}/{prefijo}_comprobacion.png")
print("lienzo por cuadro:", (W, H))
