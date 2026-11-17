"""Acerca los colores de los cuadros generados a los del sprite original (media y desviación por canal, en Lab).
Uso: python igualar_color.py <carpeta_cuadros> <sprite_original> <carpeta_salida> [fuerza=1.0]"""
import os, sys, glob
import numpy as np
from PIL import Image


class color:
    """sRGB <-> Lab (D65) sin dependencias extra."""
    M = np.array([[0.4124564, 0.3575761, 0.1804375], [0.2126729, 0.7151522, 0.0721750], [0.0193339, 0.1191920, 0.9503041]])
    B = np.array([0.95047, 1.0, 1.08883])

    @staticmethod
    def rgb2lab(rgb):
        lin = np.where(rgb > 0.04045, ((rgb + 0.055) / 1.055) ** 2.4, rgb / 12.92)
        xyz = lin @ color.M.T / color.B
        f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
        return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)

    @staticmethod
    def lab2rgb(lab):
        fy = (lab[..., 0] + 16) / 116
        fx, fz = fy + lab[..., 1] / 500, fy - lab[..., 2] / 200
        f = np.stack([fx, fy, fz], -1)
        xyz = np.where(f ** 3 > 0.008856, f ** 3, (f - 16 / 116) / 7.787) * color.B
        lin = np.clip(xyz @ np.linalg.inv(color.M).T, 0, 1)
        return np.where(lin > 0.0031308, 1.055 * lin ** (1 / 2.4) - 0.055, 12.92 * lin)

entrada, original, salida = sys.argv[1], sys.argv[2], sys.argv[3]
fuerza = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
os.makedirs(salida, exist_ok=True)


def lab_opacos(im):
    a = np.asarray(im.convert("RGBA")).astype(np.float32) / 255.0
    m = a[..., 3] > 0.5
    return color.rgb2lab(a[..., :3]), m, a


ref_lab, ref_m, _ = lab_opacos(Image.open(original))
mu_r, sd_r = ref_lab[ref_m].mean(0), ref_lab[ref_m].std(0)
rutas = sorted(glob.glob(os.path.join(entrada, "caminar_*.png")), key=lambda p: int(p.rsplit("_", 1)[1][:-4]))
datos = [lab_opacos(Image.open(r)) for r in rutas]
todos = np.concatenate([d[0][d[1]] for d in datos])
mu_g, sd_g = todos.mean(0), todos.std(0)
for ruta, (lab, m, a) in zip(rutas, datos):
    nuevo = (lab - mu_g) / np.maximum(sd_g, 1e-3) * sd_r + mu_r
    nuevo = lab + (nuevo - lab) * fuerza
    rgb = np.clip(color.lab2rgb(nuevo), 0, 1)
    out = np.dstack([rgb, a[..., 3]])
    out[~m] = 0
    Image.fromarray((out * 255).round().astype(np.uint8), "RGBA").save(os.path.join(salida, os.path.basename(ruta)))
print("ok", len(rutas), "media ref", mu_r.round(1), "media gen", mu_g.round(1))
