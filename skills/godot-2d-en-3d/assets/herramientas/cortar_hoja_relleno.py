"""Corta una hoja con VARIOS personajes sobre fondo verde cuando alguno es verdoso (un slime).

El método de "verdor" (cortar_hoja_personaje.py) deja semitransparente lo que es verde lima.
Acá el fondo se saca por RELLENO: solo es fondo lo que se parece al color del fondo Y está
conectado con el borde de la imagen. El contorno oscuro de cada dibujo frena el relleno, así
que el interior verde del personaje queda entero.

Uso: python cortar_hoja_relleno.py hoja.jpg <carpeta_base> "carpeta|ancla|n1,n2,..." ...
  Un argumento por fila de la hoja (de arriba hacia abajo).
  ancla = base (apoyados en el piso: pies abajo) o centro (voladores: centrados).
  Un nombre "-" descarta ese cuadro.
Genera <carpeta_base>/<carpeta>/<nombre>.png y <carpeta_base>/<carpeta>_vista_previa.png.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


def quitar_fondo(rgb: np.ndarray) -> np.ndarray:
    f = rgb.astype(np.float32)
    esquinas = np.concatenate([f[:20, :20].reshape(-1, 3), f[:20, -20:].reshape(-1, 3),
                               f[-20:, :20].reshape(-1, 3), f[-20:, -20:].reshape(-1, 3)])
    fondo = np.median(esquinas, axis=0)
    dist = np.linalg.norm(f - fondo, axis=2)
    parecido = dist < 110
    etiquetas, _ = ndimage.label(parecido)
    borde = np.unique(np.concatenate([etiquetas[0], etiquetas[-1], etiquetas[:, 0], etiquetas[:, -1]]))
    es_fondo = np.isin(etiquetas, borde[borde != 0])
    # Huecos encerrados (entre un ala y una oreja): solo si son casi idénticos al fondo.
    es_fondo |= dist < 60
    # Borde suave: dentro del fondo, cuanto más lejos del color del fondo, más opaco.
    alfa = np.where(es_fondo, np.clip((dist - 45) / 65, 0, 1), 1.0)
    # El anillo de 1 px pegado al fondo suele traer derrame verde del JPG: se desmezcla.
    anillo = ndimage.binary_dilation(es_fondo, iterations=2) & ~es_fondo
    out = f.copy()
    semi = (alfa > 0.02) & (alfa < 0.98)
    a = alfa[semi][:, None]
    out[semi] = np.clip((out[semi] - (1 - a) * fondo) / a, 0, 255)
    zona = anillo | semi
    rb = (out[..., 0] + out[..., 2]) / 2
    verdoso = zona & (out[..., 1] > rb + 25) & (dist < 190)
    out[..., 1] = np.where(verdoso, rb, out[..., 1])
    return np.dstack([out, alfa * 255]).astype(np.uint8)


def main() -> None:
    hoja, base = Path(sys.argv[1]), Path(sys.argv[2])
    filas_pedidas = [a.split("|") for a in sys.argv[3:]]
    rgba = quitar_fondo(np.array(Image.open(hoja).convert("RGB")))
    solido = rgba[..., 3] > 40

    # Filas: franjas horizontales con contenido separadas por franjas vacías.
    con_algo = solido.sum(axis=1) > 0
    franjas, inicio = [], None
    for y, v in enumerate(con_algo):
        if v and inicio is None:
            inicio = y
        elif not v and inicio is not None:
            if y - inicio > 25:
                franjas.append((inicio, y))
            inicio = None
    if inicio is not None:
        franjas.append((inicio, len(con_algo)))
    assert len(franjas) == len(filas_pedidas), f"filas encontradas {len(franjas)} != pedidas {len(filas_pedidas)}"

    for (y0, y1), (carpeta, ancla, nombres) in zip(franjas, filas_pedidas):
        nombres = nombres.split(",")
        fila = solido[y0:y1]
        etiquetas, n = ndimage.label(ndimage.binary_dilation(fila, iterations=1))
        cajas = ndimage.find_objects(etiquetas)
        areas = [int((etiquetas[c] == i + 1).sum()) for i, c in enumerate(cajas)]
        mayor = max(areas)
        grandes = sorted([i for i in range(n) if areas[i] >= 0.2 * mayor], key=lambda i: cajas[i][1].start)
        assert len(grandes) == len(nombres), f"{carpeta}: {len(grandes)} cuadros, se pidieron {len(nombres)}"
        # Las piezas chicas (gotas, espirales) se suman al cuadro grande más cercano.
        dueno = {i: i for i in grandes}
        for i in range(n):
            if i not in dueno and areas[i] > 12:
                cx = (cajas[i][1].start + cajas[i][1].stop) / 2
                dueno[i] = min(grandes, key=lambda g: min(abs(cx - cajas[g][1].start), abs(cx - cajas[g][1].stop)))
        recortes = []
        for g in grandes:
            mias = [i for i, d in dueno.items() if d == g]
            mascara = np.isin(etiquetas, [i + 1 for i in mias])
            ys, xs = np.where(mascara)
            trozo = rgba[y0:y1][ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy()
            trozo[..., 3] = np.where(mascara[ys.min():ys.max() + 1, xs.min():xs.max() + 1], trozo[..., 3], 0)
            recortes.append(trozo)
        ancho = max(r.shape[1] for r in recortes) + 8
        alto = max(r.shape[0] for r in recortes) + 8
        salida = base / carpeta
        salida.mkdir(parents=True, exist_ok=True)
        previa = Image.new("RGBA", (ancho * len(recortes), alto), (85, 92, 110, 255))
        for k, (nombre, r) in enumerate(zip(nombres, recortes)):
            lienzo = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
            x = (ancho - r.shape[1]) // 2
            y = alto - 4 - r.shape[0] if ancla == "base" else (alto - r.shape[0]) // 2
            lienzo.alpha_composite(Image.fromarray(r), (x, y))
            previa.alpha_composite(lienzo, (ancho * k, 0))
            if nombre != "-":
                lienzo.save(salida / f"{nombre}.png")
        previa.save(base / f"{carpeta}_vista_previa.png")
        print(carpeta, len(recortes), "cuadros de", ancho, "x", alto)


if __name__ == "__main__":
    main()
