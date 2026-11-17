"""Cuadros de ComfyUI -> sprites de 92 px de alto sin fondo, alineados por los pies.
Uso: python limpiar.py <carpeta_cuadros> <carpeta_salida> <sprite_original> [alto=92]"""
import os, sys, glob
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

entrada, salida, original = sys.argv[1], sys.argv[2], sys.argv[3]
ALTO = int(sys.argv[4]) if len(sys.argv) > 4 else 92
os.makedirs(salida, exist_ok=True)


def quitar_verde(img):
    a = np.asarray(img.convert("RGB")).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    verde = (g - np.maximum(r, b)) > 28
    fondo = ndi.binary_dilation(verde, iterations=1)
    # solo lo que toca el borde de la imagen cuenta como fondo (el verde interior del personaje se conserva)
    mascara = fondo | ((g - np.maximum(r, b)) > 14)  # también el verde encerrado entre las piernas
    blanco = (a.min(axis=2) > 205) & ndi.binary_dilation(mascara, iterations=3)  # halo claro pegado al fondo
    mascara = mascara | blanco
    # el halo claro del casco: cerca del fondo, verdoso y claro
    alfa = (~mascara).astype(np.uint8) * 255
    salida = np.dstack([a.astype(np.uint8), alfa])
    im = Image.fromarray(salida, "RGBA")
    # quedarse con el componente más grande
    m = np.asarray(im)[..., 3] > 0
    lab, n = ndi.label(m)
    if n > 1:
        tam = ndi.sum(m, lab, range(1, n + 1))
        m = lab == (1 + int(np.argmax(tam)))
        arr = np.asarray(im).copy()
        arr[..., 3] = np.where(m, 255, 0)
        im = Image.fromarray(arr, "RGBA")
    return im


frames = []
for ruta in sorted(glob.glob(os.path.join(entrada, "cuadro_*.png")), key=lambda p: int(p.rsplit("_", 1)[1][:-4])):
    im = quitar_verde(Image.open(ruta))
    frames.append(im.crop(im.getbbox()))

# escala común: la altura mediana de los cuadros pasa a ALTO
alturas = sorted(f.height for f in frames)
escala = ALTO / alturas[len(alturas) // 2]
lienzo_w, lienzo_h = 128, ALTO + 8
resultado = []
for i, f in enumerate(frames):
    nw, nh = max(1, round(f.width * escala)), max(1, round(f.height * escala))
    p = f.resize((nw, nh), Image.BOX)
    arr = np.asarray(p).copy()
    arr[..., 3] = np.where(arr[..., 3] > 127, 255, 0)  # borde duro, como pixel art
    p = Image.fromarray(arr, "RGBA")
    # centro horizontal = el de la cabeza (40 % de arriba), para que no "salte" al caminar
    cab = np.asarray(p)[: max(1, int(nh * 0.4)), :, 3] > 0
    cols = np.where(cab.any(axis=0))[0]
    cx = (cols.min() + cols.max()) / 2.0 if len(cols) else nw / 2.0
    lienzo = Image.new("RGBA", (lienzo_w, lienzo_h), (0, 0, 0, 0))
    lienzo.alpha_composite(p, (round(lienzo_w / 2 - cx), lienzo_h - 4 - nh))
    lienzo.save(os.path.join(salida, f"caminar_{i}.png"))
    resultado.append(lienzo)

# hoja de comparación: original + cuadros, ×3 con vecino más cercano sobre un gris
ori = Image.open(original).convert("RGBA")
hoja = Image.new("RGBA", (lienzo_w * 3 * 5, lienzo_h * 3 * 2 + 0), (70, 74, 84, 255))
hoja_cols = 5
o = Image.new("RGBA", (lienzo_w, lienzo_h), (0, 0, 0, 0))
o.alpha_composite(ori, ((lienzo_w - ori.width) // 2, lienzo_h - 4 - ori.height))
todos = [o] + resultado
for k, im in enumerate(todos):
    big = im.resize((lienzo_w * 3, lienzo_h * 3), Image.NEAREST)
    hoja.alpha_composite(big, ((k % hoja_cols) * lienzo_w * 3, (k // hoja_cols) * lienzo_h * 3))
hoja.convert("RGB").save(os.path.join(salida, "hoja.png"))
print("cuadros:", len(resultado), "escala:", round(escala, 3), "alturas:", alturas)
