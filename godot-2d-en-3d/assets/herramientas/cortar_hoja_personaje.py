"""Corta una hoja de animación generada por IA sobre fondo verde (#00FF00).

Uso: python -I cortar_hoja_personaje.py <hoja.jpg|png> <carpeta_salida> <nombres_fila1> <nombres_fila2> ...
Cada argumento de fila es una lista separada por comas con el nombre de cada cuadro,
p. ej. "quieto_0,quieto_1,quieto_2,quieto_3". Un nombre "-" descarta ese cuadro.

Pasos (método de Zarita, ver skill godot-juego-movil/arte-con-ia.md):
1. Alfa por "verdor" g - max(r, b), desmezclar el borde y quitar el derrame verde.
2. Piezas por componentes conectados (dilatando para que no se separen orejas o cola).
   Las piezas chicas (fogonazos, objetos sueltos) se descartan.
3. Agrupar por filas y ordenar de izquierda a derecha.
4. Todos los cuadros en un lienzo común: pies abajo y torso centrado, para que no "salte" al animar.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


def quitar_verde(rgb: np.ndarray) -> np.ndarray:
    r, g, b = (rgb[..., i].astype(np.float32) for i in range(3))
    verdor = g - np.maximum(r, b)
    fondo = np.percentile(verdor, 90)
    alfa = 1.0 - np.clip((verdor - 0.05 * fondo) / (0.75 * fondo), 0.0, 1.0)

    # Desmezclar contra el color del fondo y quitar el derrame verde del borde.
    color_fondo = np.median(rgb[verdor > 0.8 * fondo], axis=0).astype(np.float32)
    out = rgb.astype(np.float32)
    semi = (alfa > 0.02) & (alfa < 0.98)
    a = alfa[semi][:, None]
    out[semi] = np.clip((out[semi] - (1 - a) * color_fondo) / a, 0, 255)
    borde = alfa < 0.98
    rb = (out[..., 0] + out[..., 2]) / 2 * 0.97
    out[..., 1] = np.where(borde, np.minimum(out[..., 1], rb), out[..., 1])
    # Por la compresión JPG: derrame verde también en píxeles "opacos" muy verdosos.
    verdoso = (out[..., 1] > np.maximum(out[..., 0], out[..., 2]) + 40)
    out[..., 1] = np.where(verdoso, np.minimum(out[..., 1], rb), out[..., 1])

    rgba = np.dstack([out, alfa * 255]).astype(np.uint8)
    rgba[alfa < 0.06] = 0
    return rgba


def piezas(alfa: np.ndarray):
    # Dilatación chica: une orejas y cola sueltas, pero no el fogonazo ni la caja arrojada.
    mascara = ndimage.binary_dilation(alfa > 80, iterations=2)
    etiquetas, n = ndimage.label(mascara)
    cajas = ndimage.find_objects(etiquetas)
    areas = ndimage.sum(alfa > 80, etiquetas, range(1, n + 1))
    grande = 0.35 * areas.max()
    res = {}
    for i, (caja, area) in enumerate(zip(cajas, areas), start=1):
        if area >= grande:
            res[i] = [caja, {i}, area]
    # Piezas chicas (estrellas, paja, fogonazo) se suman al cuadro grande más cercano
    # si están pegadas (< CERCA px); si no, se descartan (p. ej. una caja que vuela lejos).
    CERCA = 30
    for i, (caja, area) in enumerate(zip(cajas, areas), start=1):
        if i in res:
            continue
        mejor, dist_min = None, CERCA
        for j, (cj, _, _) in res.items():
            dy = max(cj[0].start - caja[0].stop, caja[0].start - cj[0].stop, 0)
            dx = max(cj[1].start - caja[1].stop, caja[1].start - cj[1].stop, 0)
            d = max(dx, dy)
            if d < dist_min:
                mejor, dist_min = j, d
        if mejor is not None:
            cj = res[mejor][0]
            res[mejor][0] = (slice(min(cj[0].start, caja[0].start), max(cj[0].stop, caja[0].stop)),
                             slice(min(cj[1].start, caja[1].start), max(cj[1].stop, caja[1].stop)))
            res[mejor][1].add(i)
    return etiquetas, [tuple(v) for v in res.values()]


def franjas(perfil: np.ndarray, hueco_min: int):
    """Tramos ocupados de un perfil, separados por al menos `hueco_min` vacíos."""
    ocupado = perfil > 0
    tramos, ini, vacio = [], None, 0
    for i, o in enumerate(ocupado):
        if o:
            if ini is None:
                ini = i
            vacio = 0
            fin = i
        elif ini is not None:
            vacio += 1
            if vacio >= hueco_min:
                tramos.append((ini, fin + 1))
                ini = None
    if ini is not None:
        tramos.append((ini, fin + 1))
    return tramos


def agrupar_filas(lista, alfa):
    """Filas por franjas horizontales vacías de la hoja (no por el centro de cada pieza:
    los cuadros del salto están a distintas alturas)."""
    perfil = (alfa > 80).sum(axis=1)
    perfil[perfil < 3] = 0
    bandas = franjas(perfil, 8)
    filas = [[] for _ in bandas]
    for p in lista:
        cy = (p[0][0].start + p[0][0].stop) / 2
        for i, (a, b) in enumerate(bandas):
            if a <= cy < b:
                filas[i].append(p)
                break
    return [sorted(f, key=lambda p: p[0][1].start) for f in filas if f]


ANCLA = "torso"


def main():
    global ANCLA
    args = sys.argv[1:]
    if args[0].startswith("--ancla="):
        ANCLA = args.pop(0).split("=", 1)[1]
    hoja, salida, *nombres_filas = args
    salida = Path(salida)
    salida.mkdir(parents=True, exist_ok=True)
    rgba = quitar_verde(np.array(Image.open(hoja).convert("RGB")))
    etiquetas, lista = piezas(rgba[..., 3])
    # Si las franjas no separan bien (cuadros del salto a distintas alturas), usar la
    # cantidad de cuadros pedida por fila: ordenar por altura y cortar en ese orden.
    filas = agrupar_filas(lista, rgba[..., 3])
    cantidades = [len(n.split(",")) for n in nombres_filas]
    if [len(f) for f in filas] != cantidades and len(lista) == sum(cantidades):
        orden = sorted(lista, key=lambda p: (p[0][0].start + p[0][0].stop) / 2)
        filas, i = [], 0
        for c in cantidades:
            filas.append(sorted(orden[i:i + c], key=lambda p: p[0][1].start))
            i += c
    print("cuadros por fila:", [len(f) for f in filas])

    cuadros = []
    for f, fila in enumerate(filas):
        nombres = nombres_filas[f].split(",") if f < len(nombres_filas) else []
        for c, (caja, idx, _) in enumerate(fila):
            nombre = nombres[c] if c < len(nombres) else f"f{f}_{c}"
            if nombre == "-":
                continue
            recorte = rgba[caja].copy()
            recorte[~np.isin(etiquetas[caja], list(idx))] = 0
            a = recorte[..., 3] > 80
            ys, xs = np.nonzero(a)
            alto = ys.max() + 1
            # Ancla horizontal: el centro de los pies (base) si se pide, o del torso.
            if ANCLA == "base":
                y0, y1 = int(alto * 0.92), alto
            else:  # torso: columnas con alfa entre el 25 % y el 60 % del alto
                y0, y1 = int(alto * 0.25), int(alto * 0.6)
            cx = np.nonzero(a[y0:y1])[1].mean()
            cuadros.append((nombre, recorte, alto, cx))

    # Lienzo simétrico respecto del torso: al espejar (flip_h) el personaje no se corre.
    izq = der = max(max(cx, r.shape[1] - cx) for _, r, _, cx in cuadros)
    alto = max(h for _, _, h, _ in cuadros)
    ancho = int(np.ceil(izq + der)) + 4
    alto += 4
    for nombre, r, h, cx in cuadros:
        lienzo = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
        x = int(round(izq - cx)) + 2
        y = alto - 2 - h
        lienzo.alpha_composite(Image.fromarray(r[:h]), (x, y))
        lienzo.save(salida / f"{nombre}.png")
    print(f"{len(cuadros)} cuadros de {ancho}x{alto} en {salida}")

    # Vista previa sobre gris para revisar el recorte.
    cols = 6
    filas_prev = (len(cuadros) + cols - 1) // cols
    prev = Image.new("RGBA", (ancho * cols, alto * filas_prev), (90, 95, 110, 255))
    for i, (nombre, *_r) in enumerate(cuadros):
        im = Image.open(salida / f"{nombre}.png")
        prev.alpha_composite(im, ((i % cols) * ancho, (i // cols) * alto))
    prev.save(salida.parent / f"{salida.name}_vista_previa.png")


if __name__ == "__main__":
    main()
