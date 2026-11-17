"""Genera los cuadros de un ciclo de caminata con ComfyUI (API): poses OpenPose + IP-Adapter con el sprite + LoRA pixel art.
Con la variable PROMPT_FILE se usa otro texto de prompt (uno por tripulante).
Uso: python generar.py <carpeta_poses> <referencia.png> <carpeta_salida> [semilla] [peso_ip] [fuerza_cn]"""
import json, os, sys, time, glob, uuid, urllib.request, urllib.parse

HOST = "http://127.0.0.1:8188"
poses, ref, salida = sys.argv[1], sys.argv[2], sys.argv[3]
semilla = int(sys.argv[4]) if len(sys.argv) > 4 else 7
peso_ip = float(sys.argv[5]) if len(sys.argv) > 5 else 0.85
fuerza_cn = float(sys.argv[6]) if len(sys.argv) > 6 else 1.0
os.makedirs(salida, exist_ok=True)

PROMPT = ("Pixel Art, PIXARFK, side view, full body, one young woman sea captain walking to the right, "
          "magenta red hair, dark teal tricorn captain hat inside a round clear glass bubble helmet, golden brass scarf, navy blue coat with gold buttons and brass epaulettes, "
          "long red cape, brass spyglass in hand, steampunk space pirate, chibi proportions, big head, "
          "plain flat bright green background, clean sprite, flat colors, dark outline")
if os.environ.get("PROMPT_FILE"):
    PROMPT = open(os.environ["PROMPT_FILE"], encoding="utf-8").read().strip()
NEGATIVO = ("realistic, photo, 3d render, blurry, text, watermark, multiple characters, cropped, cut off, "
            "background scenery, floor, shadow, gradient, lowres, deformed, extra limbs")


def subir(ruta):
    nombre = os.path.basename(ruta)
    limite = uuid.uuid4().hex
    with open(ruta, "rb") as f:
        datos = f.read()
    cuerpo = (f"--{limite}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{nombre}\"\r\n"
              f"Content-Type: image/png\r\n\r\n").encode() + datos + (
        f"\r\n--{limite}\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--{limite}--\r\n").encode()
    req = urllib.request.Request(HOST + "/upload/image", data=cuerpo,
                                 headers={"Content-Type": f"multipart/form-data; boundary={limite}"})
    return json.load(urllib.request.urlopen(req))["name"]


def flujo(nombre_ref, nombre_pose, sem):
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "v1-5-pruned-emaonly-fp16.safetensors"}},
        "2": {"class_type": "LoraLoader", "inputs": {"model": ["1", 0], "clip": ["1", 1],
              "lora_name": "PixelArtRedmond15V-PixelArt-PIXARFK.safetensors", "strength_model": 1.0, "strength_clip": 1.0}},
        "3": {"class_type": "IPAdapterModelLoader", "inputs": {"ipadapter_file": "ip-adapter-plus_sd15.safetensors"}},
        "4": {"class_type": "CLIPVisionLoader", "inputs": {"clip_name": "CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"}},
        "5": {"class_type": "LoadImage", "inputs": {"image": nombre_ref}},
        "6": {"class_type": "IPAdapterAdvanced", "inputs": {"model": ["2", 0], "ipadapter": ["3", 0], "image": ["5", 0],
              "weight": peso_ip, "weight_type": "linear", "combine_embeds": "concat", "start_at": 0.0, "end_at": 1.0,
              "embeds_scaling": "V only", "clip_vision": ["4", 0]}},
        "7": {"class_type": "CLIPTextEncode", "inputs": {"text": PROMPT, "clip": ["2", 1]}},
        "8": {"class_type": "CLIPTextEncode", "inputs": {"text": NEGATIVO, "clip": ["2", 1]}},
        "9": {"class_type": "ControlNetLoader", "inputs": {"control_net_name": "control_v11p_sd15_openpose_fp16.safetensors"}},
        "10": {"class_type": "LoadImage", "inputs": {"image": nombre_pose}},
        "11": {"class_type": "ControlNetApplyAdvanced", "inputs": {"positive": ["7", 0], "negative": ["8", 0],
               "control_net": ["9", 0], "image": ["10", 0], "strength": fuerza_cn, "start_percent": 0.0, "end_percent": 0.9}},
        "12": {"class_type": "EmptyLatentImage", "inputs": {"width": 512, "height": 512, "batch_size": 1}},
        "13": {"class_type": "KSampler", "inputs": {"model": ["6", 0], "seed": sem, "steps": 25, "cfg": 7.0,
               "sampler_name": "euler", "scheduler": "normal", "positive": ["11", 0], "negative": ["11", 1],
               "latent_image": ["12", 0], "denoise": 1.0}},
        "14": {"class_type": "VAEDecode", "inputs": {"samples": ["13", 0], "vae": ["1", 2]}},
        "15": {"class_type": "SaveImage", "inputs": {"images": ["14", 0], "filename_prefix": "heroes_prueba"}},
    }


def pedir(f):
    req = urllib.request.Request(HOST + "/prompt", data=json.dumps({"prompt": f}).encode(),
                                 headers={"Content-Type": "application/json"})
    try:
        return json.load(urllib.request.urlopen(req))["prompt_id"]
    except urllib.error.HTTPError as e:
        print("ERROR", e.read().decode()[:1500]); raise


nombre_ref = subir(ref)
for ruta in sorted(glob.glob(os.path.join(poses, "pose_*.png")), key=lambda p: int(p.rsplit("_", 1)[1][:-4])):
    nombre_pose = subir(ruta)
    pid = pedir(flujo(nombre_ref, nombre_pose, semilla))
    t0 = time.time()
    while True:
        h = json.load(urllib.request.urlopen(f"{HOST}/history/{pid}"))
        if pid in h:
            break
        time.sleep(1)
        if time.time() - t0 > 300:
            raise SystemExit("tardó demasiado")
    estado = h[pid]["status"]["status_str"]
    if estado != "success":
        print("FALLÓ", json.dumps(h[pid]["status"])[:1200]); raise SystemExit(1)
    img = list(h[pid]["outputs"].values())[0]["images"][0]
    q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img["subfolder"], "type": img["type"]})
    destino = os.path.join(salida, os.path.basename(ruta).replace("pose_", "cuadro_"))
    with open(destino, "wb") as f:
        f.write(urllib.request.urlopen(f"{HOST}/view?{q}").read())
    print(f"OK {os.path.basename(destino)} {time.time() - t0:.1f}s", flush=True)
