import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage

BASE = 'D:/zarita-la zarigueya/assets/zarita/caminata'

def detectar(a, caja_rel, n, forma='cualquiera'):
    h, w = a.shape[:2]
    x0, y0, x1, y1 = int(caja_rel[0]*w), int(caja_rel[1]*h), int(caja_rel[2]*w), int(caja_rel[3]*h)
    r, g, b, al = a[...,0], a[...,1], a[...,2], a[...,3]
    oscuro = (al > 200) & (r < 100) & (g < 75) & (b < 75)
    zona = np.zeros_like(oscuro); zona[y0:y1, x0:x1] = oscuro[y0:y1, x0:x1]
    etq, tot = ndimage.label(zona)
    cands = []
    for i in range(1, tot+1):
        m = etq == i; ar = int(m.sum())
        if ar < 80: continue
        ys, xs = np.where(m); bw = xs.max()-xs.min()+1; bh = ys.max()-ys.min()+1
        cands.append((ar, i, bw, bh, int(xs.mean()), int(ys.mean())))
    cands.sort(reverse=True)
    return etq, cands[:n]

def overlay(a, etq, comp, color_ojo=(58, 36, 36)):
    h, w = a.shape[:2]
    m = etq == comp
    m = ndimage.binary_fill_holes(m)          # incluye el brillo blanco del ojo
    area = ndimage.binary_dilation(m, iterations=1)
    # color del pelaje alrededor: mediana del anillo exterior que no es oscuro ni transparente
    anillo = ndimage.binary_dilation(area, iterations=4) & ~area & (a[...,3] > 200) & (a[...,0] > 150)
    fur = np.median(a[anillo][:, :3], axis=0) if anillo.sum() > 5 else np.array([235, 215, 190])
    ov = np.zeros((h, w, 4), np.uint8)
    ov[area] = (*[int(v) for v in fur], 255)
    ys, xs = np.where(m); x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    # párpado cerrado: un arco suave "u" de 3 px de grosor, un poco por debajo del centro del ojo
    base = int(y0 + (y1 - y0) * 0.55)
    for x in range(x0 + 1, x1):
        t = (x - x0) / max(1, (x1 - x0))
        yy = int(base + 3 * np.sin(np.pi * t))
        ov[yy:yy+3, x] = (*color_ojo, 255)
    return ov, (x0, y0, x1, y1)

if __name__ == '__main__':
    for nombre, caja, n in [('abajo', (0.22, 0.18, 0.80, 0.42), 2), ('derecha', (0.50, 0.10, 0.85, 0.40), 1)]:
        carp = f'{BASE}/{nombre}'
        for i in range(1, 5):
            ruta = f'{carp}/zarita_{nombre}_{i}.png'
            a = np.array(Image.open(ruta).convert('RGBA'))
            etq, cands = detectar(a.astype(int), caja, n)
            print(nombre, i, [(c[0], c[2], c[3], (c[4], c[5])) for c in cands])
