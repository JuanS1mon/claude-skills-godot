"""Limpia las piezas de la bufanda y el poncho: quita el cuello de maniquí, el interior del cuello y los halos de color del fondo."""
from PIL import Image
import numpy as np
from scipy import ndimage as ndi

PIEZAS = ["frente", "espalda", "costado"]


def limpiar(nombre):
    for p in PIEZAS:
        im = Image.open(f"{nombre}_{p}.png").convert("RGBA")
        a = np.array(im).astype(int)
        h, w = a.shape[:2]
        r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
        quitar = np.zeros((h, w), bool)
        zona_alta = np.zeros((h, w), bool)
        zona_alta[: int(h * 0.30)] = True
        if nombre == "poncho":
            # cuello de maniquí y pecho que asoma: carne rosada, solo arriba (los flecos crema quedan abajo)
            quitar |= zona_alta & (al > 0) & (r > 185) & (g > 130) & (g < 215) & (b > 130) & (r - g >= 18)
            # el pedacito de cuello de maniquí con su contorno: todas las filas de arriba mientras el ancho es chico
            ancho_fila = (al > 128).sum(axis=1)
            fila_hombros = int(np.argmax(ancho_fila > 0.28 * ancho_fila.max()))
            quitar[:fila_hombros] |= al[:fila_hombros] > 0
        else:
            # interior oscuro del cuello de la bufanda (color casi uniforme), solo arriba
            cand = zona_alta & (al > 0) & (r >= 146) & (r <= 176) & (g <= 78) & (b <= 92)
            lab, n = ndi.label(cand)
            for i in range(1, n + 1):
                comp = lab == i
                ys_c = np.where(comp)[0]
                if comp.sum() >= 120 and ys_c.mean() < 0.17 * h:
                    quitar |= ndi.binary_dilation(comp, iterations=1)
        # quitar manchas chicas sueltas que queden de lo anterior y rellenar huecos de 1 px
        al = np.where(quitar, 0, al)
        # halos del color del fondo en el borde: se pintan del color del contorno
        transp = al < 128
        banda = ndi.binary_dilation(transp, iterations=3) & (al > 0)
        if nombre == "poncho":
            halo = (al > 0) & (r - g > 28) & (b - g > 28) & (r < 200)       # contorno teñido de magenta (en toda la prenda)
            contorno = (110, 60, 62)
        else:
            halo = banda & (g - np.maximum(r, b) > -10) & (g > 90)   # verde
            contorno = (110, 48, 62)
        for c, v in enumerate(contorno):
            a[..., c] = np.where(halo, v, a[..., c])
        a[..., 3] = al
        # los píxeles semitransparentes del borde pasan a opacos o transparentes (pixel art limpio)
        a[..., 3] = np.where(al > 110, 255, 0)
        out = Image.fromarray(a.astype(np.uint8), "RGBA")
        bb = out.getchannel("A").getbbox()
        out = out.crop(bb)
        out.save(f"limpia_{nombre}_{p}.png")
        print(nombre, p, out.size)


for n in ["poncho", "bufanda"]:
    limpiar(n)
for n in ["poncho", "bufanda"]:
    W = Image.new("RGBA", (700, 320), (235, 225, 205, 255)); x = 10
    for p in PIEZAS:
        t = Image.open(f"limpia_{n}_{p}.png"); W.alpha_composite(t, (x, 10)); x += t.width + 20
    W.resize((1400, 640), Image.NEAREST).save(f"prueba_limpia_{n}.png")
