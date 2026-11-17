"""Arma el dataset para entrenar el LoRA de Zarita a partir de los cuadros de caminata.

Cada cuadro (PNG con transparencia) se pone centrado en un lienzo cuadrado de 512x512
sobre varios fondos lisos, para que el LoRA no aprenda un fondo concreto, y lleva un
subtítulo (.txt) con la palabra clave `zarita` y la vista.

Uso:
    python tools/armar_dataset_lora.py D:/herramientas/lora_zarita/dataset
"""
import sys
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent / "assets" / "zarita" / "caminata"
LADO = 512
FONDOS = {"blanco": (255, 255, 255), "gris": (200, 200, 205), "verde": (120, 200, 120)}
VISTAS = {
    "abajo": "front view, facing the viewer",
    "arriba": "back view, seen from behind",
    "derecha": "side view, facing right",
    "izquierda": "side view, facing left",
}
BASE = ("zarita, pixel art, cute opossum character standing upright, gray and cream fur, "
        "pink sweater, blue overalls with a heart, pink bow on head, long pink tail, full body")

salida = Path(sys.argv[1]) / "10_zarita"  # el prefijo "10_" son las repeticiones por época
salida.mkdir(parents=True, exist_ok=True)

n = 0
for vista, descripcion in VISTAS.items():
    for ruta in sorted((RAIZ / vista).glob("zarita_*.png")):
        img = Image.open(ruta).convert("RGBA")
        caja = img.getchannel("A").getbbox()
        img = img.crop(caja)
        escala = (LADO * 0.9) / max(img.size)
        img = img.resize((round(img.width * escala), round(img.height * escala)), Image.NEAREST)
        pos = ((LADO - img.width) // 2, (LADO - img.height) // 2)
        for nombre_fondo, color in FONDOS.items():
            lienzo = Image.new("RGBA", (LADO, LADO), color + (255,))
            lienzo.alpha_composite(img, pos)
            base = f"{ruta.stem}_{nombre_fondo}"
            lienzo.convert("RGB").save(salida / f"{base}.png")
            (salida / f"{base}.txt").write_text(f"{BASE}, {descripcion}, simple {nombre_fondo} background", encoding="utf-8")
            n += 1
print(f"{n} imágenes con subtítulo en {salida}")
