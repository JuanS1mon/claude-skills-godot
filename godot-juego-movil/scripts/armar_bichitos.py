"""Corta la hoja de bichitos (4 cuadros x 3 colores; la IA repite cada color en 2 filas: se usa la primera).
Solo se queda con el CUERPO y las alas (la silueta cerrada por el contorno marrón); los anillos del brillo se
descartan porque la escena ya los dibuja con el color de la ficha. Alinea cada cuadro por la base y el centro del
cuerpo y guarda assets/bichitos/<color>/<n>.png, todos del mismo tamaño (no salta al animar)."""
import os, sys, numpy as np
from PIL import Image
from scipy import ndimage as ndi
src, out = sys.argv[1], sys.argv[2]
COLORES = ["comun", "azulado", "verdoso"]
im = np.asarray(Image.open(src).convert("RGB")).astype(int)
r, g, b = im[..., 0], im[..., 1], im[..., 2]
# contorno marrón rosado oscuro (#7A4545 aprox.)
contorno = (r > g + 12) & (r > b + 8) & (r < 175) & (g < 120)
H, W = r.shape
filas, cols = 6, 4
cuerpos = {}
for c in range(3):
    for k in range(4):
        y0, y1 = int(H * 2 * c / filas), int(H * (2 * c + 1) / filas)
        x0, x1 = int(W * k / cols), int(W * (k + 1) / cols)
        m = contorno[y0:y1, x0:x1]
        # el contorno a veces tiene huecos: se cierra fuerte para rellenar el cuerpo y se suma el contorno original
        # (así las antenas finas no se pierden)
        for it in (6, 9, 12, 16):   # si el contorno tiene un hueco grande, el cuerpo queda vacío: cerrar más
            lleno = ndi.binary_fill_holes(ndi.binary_closing(m, iterations=it)) | ndi.binary_dilation(m, iterations=1)
            yy, xx = np.where(lleno)
            if lleno.sum() / ((np.ptp(yy) + 1) * (np.ptp(xx) + 1)) > 0.5:
                break
        lab, n = ndi.label(lleno, structure=np.ones((3, 3)))
        if n == 0:
            raise SystemExit(f"cuadro vacío {c},{k}")
        tam = ndi.sum(lleno, lab, range(1, n + 1))
        sil = np.isin(lab, [i + 1 for i, t in enumerate(tam) if t >= 12])
        sil = ndi.binary_dilation(sil, iterations=1)
        # el borde ganado al dilatar puede traer píxeles del fondo verde: se descartan los muy verdes
        borde = sil & ~ndi.binary_erosion(sil, iterations=2)
        verde = (g[y0:y1, x0:x1] - np.maximum(r[y0:y1, x0:x1], b[y0:y1, x0:x1])) > 70
        sil = sil & ~(borde & verde)
        # el cierre fuerte también rellena fondo verde entre antenas y alas: fuera todo lo muy verde
        puro = (g[y0:y1, x0:x1] - np.maximum(r[y0:y1, x0:x1], b[y0:y1, x0:x1])) > 110
        sil = sil & ~puro
        # huecos chicos (punta de ala) que no son fondo: se rellenan
        hueco = ndi.binary_fill_holes(sil) & ~sil & ~puro
        lh, nh = ndi.label(hueco)
        for i in range(1, nh + 1):
            if (lh == i).sum() < 60:
                sil |= lh == i
        rgb = im[y0:y1, x0:x1].astype(np.uint8)
        rgba = np.dstack([rgb, (sil * 255).astype(np.uint8)])
        ys, xs = np.where(sil)
        base = ys.max()
        inf = ys >= ys.min() + 0.6 * (ys.max() - ys.min())   # parte baja: el cuerpo sin alas
        cx = int(round(xs[inf].mean()))
        cuerpos[(c, k)] = (rgba, cx, base)
# lienzo común: la unión de lo que cada cuadro se extiende desde (cx, base)
izq = 0; der = 0; arr = 0
for rgba, cx, base in cuerpos.values():
    ys, xs = np.where(rgba[..., 3] > 0)
    izq = max(izq, cx - xs.min()); der = max(der, xs.max() - cx); arr = max(arr, base - ys.min())
Wc, Hc = izq + der + 1, arr + 1
for (c, k), (rgba, cx, base) in cuerpos.items():
    lienzo = Image.new("RGBA", (Wc, Hc), (0, 0, 0, 0))
    lienzo.alpha_composite(Image.fromarray(rgba), (izq - cx, arr - base))
    d = os.path.join(out, COLORES[c]); os.makedirs(d, exist_ok=True)
    lienzo.save(os.path.join(d, f"{k + 1}.png"))
print("lienzo", Wc, "x", Hc, "| origen (centro, base) =", izq, arr)
