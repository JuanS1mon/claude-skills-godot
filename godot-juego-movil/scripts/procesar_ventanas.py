"""Corta las ventanas de una hoja, detecta el cristal (huecos cerrados) y genera marco, máscara de cristal y mancha de luz.

uso: procesar_ventanas.py entrada carpeta_salida nombre1 nombre2 nombre3
"""
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

entrada, carpeta, nombres = sys.argv[1], sys.argv[2], sys.argv[3:]
n = len(nombres)

img = Image.open(entrada).convert("RGB")
a = np.array(img).astype(np.float32)
marco_px = np.concatenate([a[:6].reshape(-1, 3), a[-6:].reshape(-1, 3), a[:, :6].reshape(-1, 3), a[:, -6:].reshape(-1, 3)])
bg = np.median(marco_px, axis=0)
dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
solido = dist >= 60
solido = ndimage.binary_opening(solido, structure=np.ones((2, 2)))
print("fondo:", bg.astype(int))

# Ventanas = tramos de columnas con contenido separados por huecos.
ocup = solido.any(axis=0)
tramos, ini = [], None
for x, o in enumerate(ocup):
    if o and ini is None:
        ini = x
    elif not o and ini is not None:
        tramos.append([ini, x]); ini = None
if ini is not None:
    tramos.append([ini, len(ocup)])
uni = []
for t in tramos:
    if uni and t[0] - uni[-1][1] < 12:
        uni[-1][1] = t[1]
    else:
        uni.append(t)
uni = [t for t in uni if t[1] - t[0] > 60]
print("tramos:", uni)
if len(uni) != n:
    sys.exit(f"ERROR: esperaba {n} ventanas y hay {len(uni)}")

for nombre, (x0, x1) in zip(nombres, uni):
    s = solido[:, x0:x1]
    ys = np.where(s.any(axis=1))[0]
    y0, y1 = ys.min(), ys.max() + 1
    sub = a[y0:y1, x0:x1].copy()
    s = s[y0:y1]
    # quita la capa de 1 px contaminada de verde en el borde exterior
    s = ndimage.binary_erosion(s, structure=ndimage.generate_binary_structure(2, 1), iterations=1)
    # despill: en los bordes, el verde no puede superar al rojo/azul
    cerca = ndimage.binary_dilation(~s, iterations=2) & s
    sub[..., 1] = np.where(cerca & (sub[..., 1] > np.maximum(sub[..., 0], sub[..., 2])), np.maximum(sub[..., 0], sub[..., 2]), sub[..., 1])
    h, w = s.shape

    # Cristal: huecos transparentes que NO están conectados con el exterior.
    T = np.pad(~s, 1, constant_values=True)
    etq, tot = ndimage.label(T)             # conectividad 4: no se cuela por diagonales
    exterior = etq == etq[0, 0]
    cristal = (T & ~exterior)[1:-1, 1:-1]
    # quita motas pequeñas de cristal
    etq2, t2 = ndimage.label(cristal)
    for i in range(1, t2 + 1):
        if (etq2 == i).sum() < 150:
            cristal[etq2 == i] = False
    print(f"{nombre}: {w}x{h}  cristal = {int(cristal.sum())} px ({100 * cristal.sum() / (w * h):.0f}% del cuadro)")

    rgba = np.dstack([sub, s * 255.0]).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(f"{carpeta}/{nombre}_marco.png")
    mask = np.zeros((h, w, 4), np.uint8); mask[cristal] = (255, 255, 255, 255)
    Image.fromarray(mask, "RGBA").save(f"{carpeta}/{nombre}_cristal.png")

    # Mancha de luz en el suelo: el cristal visto desde arriba (la base de la ventana cae junto a la pared),
    # alargada, suavizada y que se apaga con la distancia. Gris sobre negro: lo que se ve es el brillo.
    largo = int(h * 1.35)
    g = Image.fromarray((cristal * 255).astype(np.uint8), "L").transpose(Image.FLIP_TOP_BOTTOM)
    g = g.resize((w, largo), Image.BILINEAR).filter(ImageFilter.GaussianBlur(1.6))
    v = np.array(g).astype(np.float32) / 255.0
    caida = np.linspace(1.0, 0.35, largo)[:, None]
    v = v * caida
    # bordes laterales suaves
    borde = np.minimum(np.linspace(0, 1, w) * 6, 1)[None, :] * np.minimum(np.linspace(1, 0, w) * 6, 1)[None, :]
    v = v * borde
    gris = (np.clip(v, 0, 1) * 255).astype(np.uint8)
    parche = np.dstack([gris, gris, gris, gris])
    Image.fromarray(parche, "RGBA").save(f"{carpeta}/{nombre}_parche.png")
    print("   parche:", (w, largo))

# comprobación visual: fondo gris-azulado con el cristal en celeste
fig = Image.new("RGBA", (sum(t[1] - t[0] for t in uni) + 40 * (n + 1), 340), (120, 150, 200, 255))
x = 40
for nombre in nombres:
    m = Image.open(f"{carpeta}/{nombre}_marco.png")
    fig.alpha_composite(m, (x, 10)); x += m.width + 40
fig.convert("RGB").save(f"{carpeta}/_comprobacion.png")
