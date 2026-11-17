"""Como armar_direccion.py, pero separa los cuadros por piezas conectadas (útil cuando la cola de un
cuadro toca en columnas a la nariz del siguiente).

uso: armar_conectadas.py entrada n_cuadros carpeta_salida prefijo alto_objetivo
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

entrada, n, carpeta, prefijo, alto_obj = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4], int(sys.argv[5])

img = Image.open(entrada).convert("RGBA")
a = np.array(img).astype(np.int32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
dominio = g - np.maximum(r, b)
alfa = np.where(dominio >= 90, 0.0, np.where(dominio <= 40, 1.0, (90 - dominio) / 50.0))
a[..., 1] = np.where(dominio > 0, np.minimum(g, np.maximum(r, b) + 8), g)
a[..., 3] = (alfa * 255).astype(np.int32)
res = np.array(Image.fromarray(a.astype(np.uint8), "RGBA"))

mascara = res[..., 3] > 8
etiquetas, total = ndimage.label(mascara, structure=np.ones((3, 3)))
areas = ndimage.sum(mascara, etiquetas, index=range(1, total + 1))
orden = np.argsort(areas)[::-1]
principales = [int(i) + 1 for i in orden[:n]]
print("componentes:", total, " areas principales:", [int(areas[p - 1]) for p in principales])

objetos = ndimage.find_objects(etiquetas)
cajas = {p: objetos[p - 1] for p in principales}
centros = {p: (cajas[p][1].start + cajas[p][1].stop) / 2 for p in principales}
principales.sort(key=lambda p: centros[p])

# Piezas pequeñas sueltas (p. ej. un trozo de moño): van al cuadro principal más cercano.
asigna = {p: [p] for p in principales}
for i in range(1, total + 1):
    if i in principales or areas[i - 1] < 6:
        continue
    cy, cx = ndimage.center_of_mass(etiquetas == i)
    cercano = min(principales, key=lambda p: abs(centros[p] - cx))
    asigna[cercano].append(i)

cuadros, tops = [], []
for p in principales:
    m = np.isin(etiquetas, asigna[p])
    pieza = res.copy()
    pieza[~m] = 0
    im = Image.fromarray(pieza, "RGBA")
    caja = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    cuadros.append(im.crop(caja)); tops.append(caja[1])
    print("cuadro", len(cuadros), "caja", caja)

s = alto_obj / cuadros[1].height
print("escala:", round(s, 3))
esc = [c.resize((max(1, round(c.width * s)), max(1, round(c.height * s))), Image.LANCZOS) for c in cuadros]
tops_e = [round(t * s) for t in tops]
tmin = min(tops_e)


def centro_cabeza(im):
    al = np.array(im.getchannel("A")) > 8
    h = al.shape[0]
    xs = np.where(al[: int(h * 0.35)].any(axis=0))[0]
    return (xs.min() + xs.max()) / 2


cab = [centro_cabeza(c) for c in esc]
izq = max(cab); der = max(c.width - cb for c, cb in zip(esc, cab))
mitad = int(np.ceil(max(izq, der)))
pad = 10
W = 2 * mitad + 2 * pad
H = max(t - tmin + c.height for c, t in zip(esc, tops_e)) + 2 * pad
for i, (c, t, cb) in enumerate(zip(esc, tops_e, cab), start=1):
    lz = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lz.alpha_composite(c, (int(round(pad + mitad - cb)), pad + t - tmin))
    lz.save(f"{carpeta}/{prefijo}_{i}.png")
hoja = Image.new("RGBA", (W * n, H))
for i in range(n):
    hoja.paste(Image.open(f"{carpeta}/{prefijo}_{i + 1}.png"), (i * W, 0))
fondo = Image.new("RGBA", hoja.size, (185, 154, 114, 255))
fondo.alpha_composite(hoja)
fondo.convert("RGB").save(f"{carpeta}/{prefijo}_comprobacion.png")
print("lienzo por cuadro:", (W, H), " centro de cabeza en x =", W / 2)
