"""Genera poses OpenPose (esqueleto COCO-18) de un ciclo de caminata de perfil, mirando a la derecha."""
import math, os, sys
from PIL import Image, ImageDraw

SALIDA = sys.argv[1]
N = int(sys.argv[2]) if len(sys.argv) > 2 else 8
os.makedirs(SALIDA, exist_ok=True)

TAM = 512
SUELO = 478
CX = 250
MUSLO = 62
CANILLA = 62
BRAZO = 44
ANTEBRAZO = 40
CADERA_Y = SUELO - MUSLO - CANILLA + 4

COLORES = [[255, 0, 0], [255, 85, 0], [255, 170, 0], [255, 255, 0], [170, 255, 0], [85, 255, 0], [0, 255, 0],
           [0, 255, 85], [0, 255, 170], [0, 255, 255], [0, 170, 255], [0, 85, 255], [0, 0, 255], [85, 0, 255],
           [170, 0, 255], [255, 0, 255], [255, 0, 170], [255, 0, 85]]
LIMBS = [[2, 3], [2, 6], [3, 4], [3, 5], [4, 7], [5, 6], [6, 8], [2, 9], [9, 10], [10, 11], [2, 12], [12, 13],
         [13, 14], [2, 1], [1, 15], [15, 17], [1, 16], [16, 18]]  # 1-indexed como en OpenPose


def segmento(p, largo, grados):
    """Punto a `largo` px de p; 0 grados = hacia abajo, positivo = hacia adelante (derecha)."""
    a = math.radians(grados)
    return (p[0] + largo * math.sin(a), p[1] + largo * math.cos(a))


def pierna(cadera, fase):
    muslo = 40 * math.sin(fase)
    flexion = 4 + 52 * max(0.0, math.cos(fase))
    rodilla = segmento(cadera, MUSLO, muslo)
    tobillo = segmento(rodilla, CANILLA, muslo - flexion)
    return rodilla, tobillo


def brazo(hombro, fase):
    ang = -26 * math.sin(fase)
    codo = segmento(hombro, BRAZO, ang)
    mano = segmento(codo, ANTEBRAZO, ang + 16 + 10 * max(0.0, math.sin(fase)))
    return codo, mano


def pose(t):
    fase = 2 * math.pi * t
    rebote = -5 * abs(math.sin(fase))  # sube un poco entre pasos
    cadera = (CX, CADERA_Y + rebote)
    cuello = (CX + 4, cadera[1] - 92)
    hombro_d = (CX + 4, cuello[1] + 6)
    hombro_i = (CX + 2, cuello[1] + 6)
    nariz = (CX + 48, cuello[1] - 66)
    ojo_d = (CX + 14, cuello[1] - 84)
    ojo_i = (CX + 38, cuello[1] - 84)
    oreja_d = (CX - 22, cuello[1] - 74)
    oreja_i = (CX - 4, cuello[1] - 78)
    rod_d, tob_d = pierna(cadera, fase)
    rod_i, tob_i = pierna(cadera, fase + math.pi)
    cod_d, man_d = brazo(hombro_d, fase + math.pi)
    cod_i, man_i = brazo(hombro_i, fase)
    # índices COCO-18 (0-based)
    return {0: nariz, 1: cuello, 2: hombro_d, 3: cod_d, 4: man_d, 5: hombro_i, 6: cod_i, 7: man_i,
            8: (cadera[0] + 1, cadera[1]), 9: rod_d, 10: tob_d, 11: (cadera[0] - 1, cadera[1]), 12: rod_i,
            13: tob_i, 14: ojo_d, 15: ojo_i, 16: oreja_d, 17: oreja_i}


def dibujar(kp):
    img = Image.new("RGB", (TAM, TAM), (0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, (a, b) in enumerate(LIMBS):
        pa, pb = kp[a - 1], kp[b - 1]
        c = tuple(int(v * 0.6) for v in COLORES[i])
        d.line([pa, pb], fill=c, width=8)
    for i, p in kp.items():
        c = tuple(COLORES[i])
        d.ellipse([p[0] - 4, p[1] - 4, p[0] + 4, p[1] + 4], fill=c)
    return img


for i in range(N):
    dibujar(pose(i / N)).save(os.path.join(SALIDA, f"pose_{i}.png"))
print("poses:", N, "->", SALIDA)
