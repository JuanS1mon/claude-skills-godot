"""Dibuja con Pillow, en pixel art, el icono del botón Mapa (assets/ui/iconos/casa.png, 128x128)
y la puerta provisional de las habitaciones (assets/puertas/puerta.png, 112x144).
Se dibuja en baja resolución y se amplía x4 sin suavizar, igual que el resto de la interfaz."""
from PIL import Image, ImageDraw

O = (122, 74, 74, 255)      # contorno marrón rojizo (el de los demás iconos)
ROSA = (232, 150, 160, 255)
ROSA_CLARO = (246, 188, 194, 255)
CREMA = (252, 232, 200, 255)
CREMA_SOMBRA = (238, 206, 168, 255)
MADERA = (206, 146, 104, 255)
MADERA_SOMBRA = (176, 118, 84, 255)
CELESTE = (170, 208, 230, 255)
ORO = (244, 206, 96, 255)


def ampliar(img, factor, ruta):
    img.resize((img.width * factor, img.height * factor), Image.NEAREST).save(ruta)


def casa():
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((7, 14, 24, 26), fill=CREMA, outline=O)
    d.rectangle((8, 22, 23, 25), fill=CREMA_SOMBRA)
    d.rectangle((21, 5, 24, 11), fill=ROSA, outline=O)          # chimenea
    d.polygon([(3, 15), (15, 4), (28, 15)], fill=ROSA, outline=O)
    d.line([(8, 14), (15, 7)], fill=ROSA_CLARO)                  # brillo del techo
    d.rectangle((13, 19, 18, 26), fill=MADERA, outline=O)       # puerta
    d.point((17, 23), fill=ORO)
    d.rectangle((9, 17, 11, 19), fill=CELESTE, outline=O)       # ventanas
    d.rectangle((20, 17, 22, 19), fill=CELESTE, outline=O)
    ampliar(im, 4, "assets/ui/iconos/casa.png")


def puerta():
    im = Image.new("RGBA", (28, 36), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((2, 1, 25, 18), fill=MADERA, outline=O)            # arco
    d.rectangle((2, 10, 25, 35), fill=MADERA, outline=O)
    d.rectangle((3, 11, 24, 34), fill=MADERA)
    for x in (9, 14, 19):                                         # tablas
        d.line([(x, 6 if x == 14 else 12), (x, 34)], fill=MADERA_SOMBRA)
    d.rectangle((3, 32, 24, 34), fill=MADERA_SOMBRA)
    d.rectangle((6, 7, 8, 9), fill=CELESTE, outline=O)           # ventanita
    d.point((21, 23), fill=ORO)
    d.point((21, 24), fill=ORO)
    ampliar(im, 4, "assets/puertas/puerta.png")


casa()
puerta()
