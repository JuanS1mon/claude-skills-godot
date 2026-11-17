"""Anima un elemento de un fondo (el remolino de la capsula, el fuego del taller...) cuadro por cuadro con ComfyUI.

Para cada cuadro: recorta la zona del fondo, le aplica el movimiento (girar un angulo o dejarla igual), la repinta con
img2img de poca fuerza usando el LoRA de estilo del juego (albatros_estilo) y la devuelve con una mascara redonda
suave, lista para ponerse encima del fondo. Con la misma semilla en todos los cuadros el repintado es parejo, asi
el movimiento no tiembla.

Uso:
  python animar_elemento.py <fondo.jpg> <salida> --zona x,y,ancho,alto --cuadros 12 [--girar] [--fuerza 0.3]
        [--lora 0.8] [--prompt "texto"] [--semilla 7] [--sin-comfy]
`--sin-comfy` omite el repintado (solo movimiento) para comparar. Las zonas estan en pixeles del fondo (720x1280).
"""
import argparse
import io
import json
import os
import time
import urllib.parse
import urllib.request
import uuid

from PIL import Image, ImageDraw, ImageFilter

HOST = "http://127.0.0.1:8188"
LADO = 512
NEGATIVO = "text, watermark, logo, blurry, lowres, deformed, photo, 3d render, people, face"


def subir(img: Image.Image, nombre: str) -> str:
    buf = io.BytesIO()
    img.save(buf, "PNG")
    limite = uuid.uuid4().hex
    cuerpo = (f"--{limite}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{nombre}\"\r\n"
              f"Content-Type: image/png\r\n\r\n").encode() + buf.getvalue() + (
        f"\r\n--{limite}\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--{limite}--\r\n").encode()
    req = urllib.request.Request(HOST + "/upload/image", data=cuerpo,
                                 headers={"Content-Type": f"multipart/form-data; boundary={limite}"})
    return json.load(urllib.request.urlopen(req))["name"]


def flujo(nombre_img, prompt, semilla, fuerza, lora):
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "v1-5-pruned-emaonly-fp16.safetensors"}},
        "2": {"class_type": "LoraLoader", "inputs": {"model": ["1", 0], "clip": ["1", 1],
              "lora_name": "albatros_estilo.safetensors", "strength_model": lora, "strength_clip": lora}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["2", 1]}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": NEGATIVO, "clip": ["2", 1]}},
        "5": {"class_type": "LoadImage", "inputs": {"image": nombre_img}},
        "6": {"class_type": "VAEEncode", "inputs": {"pixels": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "KSampler", "inputs": {"model": ["2", 0], "seed": semilla, "steps": 24, "cfg": 6.5,
              "sampler_name": "euler", "scheduler": "normal", "positive": ["3", 0], "negative": ["4", 0],
              "latent_image": ["6", 0], "denoise": fuerza}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["1", 2]}},
        "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "animar_elemento"}},
    }


def repintar(img: Image.Image, prompt, semilla, fuerza, lora) -> Image.Image:
    nombre = subir(img, "animar_entrada.png")
    req = urllib.request.Request(HOST + "/prompt", data=json.dumps({"prompt": flujo(nombre, prompt, semilla, fuerza, lora)}).encode(),
                                 headers={"Content-Type": "application/json"})
    pid = json.load(urllib.request.urlopen(req))["prompt_id"]
    t0 = time.time()
    while True:
        h = json.load(urllib.request.urlopen(f"{HOST}/history/{pid}"))
        if pid in h:
            break
        time.sleep(0.5)
        if time.time() - t0 > 300:
            raise SystemExit("tardo demasiado")
    if h[pid]["status"]["status_str"] != "success":
        raise SystemExit("FALLO " + json.dumps(h[pid]["status"])[:1200])
    datos = list(h[pid]["outputs"].values())[0]["images"][0]
    q = urllib.parse.urlencode({"filename": datos["filename"], "subfolder": datos["subfolder"], "type": datos["type"]})
    return Image.open(io.BytesIO(urllib.request.urlopen(f"{HOST}/view?{q}").read())).convert("RGB")


def mascara_redonda(w, h, margen=0.1, difuminado=0.12):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).ellipse((w * margen, h * margen, w * (1 - margen), h * (1 - margen)), fill=255)
    return m.filter(ImageFilter.GaussianBlur(min(w, h) * difuminado))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("fondo")
    ap.add_argument("salida")
    ap.add_argument("--zona", required=True, help="x,y,ancho,alto en pixeles del fondo")
    ap.add_argument("--cuadros", type=int, default=12)
    ap.add_argument("--girar", action="store_true", help="gira la zona 360 grados a lo largo del bucle")
    ap.add_argument("--fuerza", type=float, default=0.3, help="denoise del repintado (0.2 a 0.45)")
    ap.add_argument("--lora", type=float, default=0.8)
    ap.add_argument("--prompt", default="albatros style, hand painted steampunk illustration, glowing teal swirling portal, cogs, teal and orange glow")
    ap.add_argument("--semilla", type=int, default=7)
    ap.add_argument("--sin-comfy", action="store_true")
    ap.add_argument("--variar-semilla", action="store_true", help="semilla distinta en cada cuadro (fuego, vapor: que cada cuadro cambie)")
    ap.add_argument("--margen", type=float, default=0.06, help="borde de la mascara redonda (0 a 0.3)")
    a = ap.parse_args()

    x, y, w, h = (int(v) for v in a.zona.split(","))
    fondo = Image.open(a.fondo).convert("RGB")
    zona = fondo.crop((x, y, x + w, y + h))
    os.makedirs(a.salida, exist_ok=True)
    mascara = mascara_redonda(w, h, a.margen)

    for k in range(a.cuadros):
        trabajo = zona.resize((LADO, round(LADO * h / w)), Image.LANCZOS)
        if a.girar:
            trabajo = trabajo.rotate(-360.0 * k / a.cuadros, resample=Image.BICUBIC)
        if not a.sin_comfy:
            alto8 = trabajo.height // 8 * 8
            trabajo = repintar(trabajo.crop((0, 0, LADO, alto8)).resize((LADO, alto8)), a.prompt, a.semilla + (k if a.variar_semilla else 0), a.fuerza, a.lora)
        cuadro = trabajo.resize((w, h), Image.LANCZOS).convert("RGBA")
        cuadro.putalpha(mascara)
        cuadro.save(os.path.join(a.salida, f"{k}.png"))
        print(f"cuadro {k + 1}/{a.cuadros}", flush=True)


main()
