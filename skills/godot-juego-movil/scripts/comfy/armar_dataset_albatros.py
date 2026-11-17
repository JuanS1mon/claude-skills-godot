"""Arma el conjunto de imagenes para entrenar el LoRA de ESTILO del juego (Albatros Piratas Estelares).

A diferencia del LoRA de Zarita (un personaje), este aprende el *estilo*: pintura a pincel de salas steampunk
(latón, cobre, cian y naranja), los retratos de la tripulación y la nave. Sirve para que ComfyUI, al animar
elementos de las salas cuadro por cuadro (img2img con poco cambio), no se salga del estilo ni pierda detalles.

Cada imagen es un recorte de 512x512 con su subtitulo (.txt). El subtitulo empieza con la palabra clave
`albatros style` (el LoRA se llama con esa frase) y describe lo que hay.

Uso:  python armar_dataset_albatros.py <carpeta_del_proyecto> D:/herramientas/lora_albatros/dataset
"""
import random
import sys
from pathlib import Path

from PIL import Image

LADO = 512
BASE = "albatros style, hand painted steampunk space opera illustration, brass and copper, teal and orange glow"
SALAS = {
    "puente": "bridge of a steampunk spaceship, round glowing teal gauges, tangled copper pipes, octagonal window to a nebula",
    "camarotes": "crew quarters corridor of a steampunk spaceship, bunk beds, round portholes, hanging orange lanterns, copper pipes",
    "capsula": "summoning chamber of a steampunk spaceship, glowing teal swirling portal, flying cogs, bubbling cyan tubes, brass floor medallion",
    "taller": "workshop of a steampunk spaceship, workbench with tools, blueprints, glowing cyan crystals, iron stove with fire, cogs",
    "mapa": "navigation room of a steampunk spaceship, big round brass map table, compass, sextant, old maps, wall lamps",
}
HEROES = {
    "selene": "portrait of a space pirate captain with long red hair, glass bubble helmet, black tricorn hat, blue coat and red cape",
    "piston": "portrait of a steampunk space crew member",
    "xylo": "portrait of an alien space crew member",
    "mora": "portrait of a steampunk space doctor",
    "caldera": "portrait of a steampunk robot crew member",
    "zorg": "portrait of a blue alien space crew member with one eye",
}


def recortes(img: Image.Image, cantidad: int, azar: random.Random):
    """Recortes cuadrados de varios tamanos y posiciones, llevados a 512x512."""
    w, h = img.size
    for i in range(cantidad):
        lado = int(min(w, h) * (0.55 + 0.45 * ((i * 7) % 10) / 9))
        x = azar.randint(0, w - lado)
        y = azar.randint(0, h - lado)
        yield img.crop((x, y, x + lado, y + lado)).resize((LADO, LADO), Image.LANCZOS)


def guardar(img, nombre, texto, salida):
    img.convert("RGB").save(salida / f"{nombre}.png")
    (salida / f"{nombre}.txt").write_text(texto, encoding="utf-8")


def sobre_nebulosa(figura: Image.Image, azar: random.Random) -> Image.Image:
    """Pone una figura con transparencia en el centro de un lienzo oscuro con estrellas."""
    lienzo = Image.new("RGB", (LADO, LADO), (8, 14, 28))
    px = lienzo.load()
    for _ in range(90):
        px[azar.randrange(LADO), azar.randrange(LADO)] = (200, 230, 255)
    figura = figura.copy()
    k = LADO * 0.85 / max(figura.size)
    figura = figura.resize((round(figura.width * k), round(figura.height * k)), Image.LANCZOS)
    lienzo.paste(figura, ((LADO - figura.width) // 2, (LADO - figura.height) // 2), figura)
    return lienzo


def main():
    raiz = Path(sys.argv[1])
    salida = Path(sys.argv[2]) / "5_albatros"   # "5_" = repeticiones por epoca
    salida.mkdir(parents=True, exist_ok=True)
    azar = random.Random(11)
    n = 0

    for sala, descripcion in SALAS.items():
        img = Image.open(raiz / "assets" / "fondos" / f"{sala}.jpg").convert("RGB")
        for i, r in enumerate(recortes(img, 11, azar)):
            guardar(r, f"sala_{sala}_{i:02d}", f"{BASE}, {descripcion}", salida)
            n += 1

    for heroe, descripcion in HEROES.items():
        ruta = raiz / "assets" / "heroes" / f"{heroe}_arte.jpg"
        if not ruta.exists():
            continue
        img = Image.open(ruta).convert("RGB")
        w, h = img.size
        # cabeza y torso, cuerpo entero (con bordes oscuros para ser cuadrado) y un recorte intermedio
        cuadro = img.crop((0, 0, w, w)).resize((LADO, LADO), Image.LANCZOS)
        guardar(cuadro, f"heroe_{heroe}_arriba", f"{BASE}, {descripcion}, upper body", salida)
        centro = img.crop((0, h // 4, w, h // 4 + w)).resize((LADO, LADO), Image.LANCZOS)
        guardar(centro, f"heroe_{heroe}_medio", f"{BASE}, {descripcion}, waist up", salida)
        entero = Image.new("RGB", (h, h), (10, 14, 26))
        entero.paste(img, ((h - w) // 2, 0))
        guardar(entero.resize((LADO, LADO), Image.LANCZOS), f"heroe_{heroe}_entero", f"{BASE}, {descripcion}, full body", salida)
        n += 3

    nave_arriba = raiz / "assets" / "nave" / "albatros_arriba.png"
    if nave_arriba.exists():
        figura = Image.open(nave_arriba).convert("RGBA")
        for i in range(3):
            guardar(sobre_nebulosa(figura, azar), f"nave_arriba_{i}", f"{BASE}, top view of a flying steampunk airship with cream sail wings with dark blue tips, albatross head prow, teal glass dome", salida)
            n += 1

    print(f"{n} imagenes con subtitulo en {salida}")


main()
