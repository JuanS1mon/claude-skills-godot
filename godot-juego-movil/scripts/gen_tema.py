from PIL import Image
import math
# --- perilla del deslizador
N=44; im=Image.new('RGBA',(N,N),(0,0,0,0)); c=(N-1)/2
for y in range(N):
    for x in range(N):
        d=math.hypot(x-c,y-c)
        if d<=N/2-1: im.putpixel((x,y),(116,68,66,255) if d>N/2-5 else (244,160,172,255))
for y in range(11,18):
    for x in range(12,19): im.putpixel((x,y),(255,255,255,153))
im.save('D:/zarita-la zarigueya/assets/ui/perilla.png')

MARRON="Color(0.455, 0.267, 0.259, 1)"; MARRON_SUAVE="Color(0.455, 0.267, 0.259, 0.5)"
APAGADO="Color(0.85, 0.85, 0.85, 0.75)"
texturas={}   # nombre -> id
def tex(nombre):
    if nombre not in texturas: texturas[nombre]=f"tex_{nombre}"
    return texturas[nombre]
subs=[]; cache={}
def caja(marco,margen,cx=0,cy=0,tinte=None):
    k=(marco,margen,cx,cy,tinte)
    if k in cache: return cache[k]
    i=f"sb_{len(subs)}"
    lin=[f'[sub_resource type="StyleBoxTexture" id="{i}"]',f'texture = ExtResource("{tex(marco)}")']
    for l in ("left","top","right","bottom"): lin.append(f'texture_margin_{l} = {float(margen)}')
    if cx or cy:
        lin += [f'content_margin_left = {float(cx)}',f'content_margin_top = {float(cy)}',f'content_margin_right = {float(cx)}',f'content_margin_bottom = {float(cy)}']
    if tinte: lin.append(f'modulate_color = {tinte}')
    subs.append("\n".join(lin)); cache[k]=i; return i
def plano(relleno,borde_ancho=3):
    i=f"sb_{len(subs)}"
    lin=[f'[sub_resource type="StyleBoxFlat" id="{i}"]','content_margin_top = 8.0','content_margin_bottom = 8.0',f'bg_color = {relleno}']
    for l in ("left","top","right","bottom"): lin.append(f'border_width_{l} = {borde_ancho}')
    lin.append(f'border_color = {MARRON}')
    for l in ("top_left","top_right","bottom_right","bottom_left"): lin.append(f'corner_radius_{l} = 8')
    subs.append("\n".join(lin)); return i
vacio=f"sb_{len(subs)}"; subs.append(f'[sub_resource type="StyleBoxEmpty" id="{vacio}"]')

prop=[]
def p(l): prop.append(l)
def estados(tipo,normal,pres,desact,base=None):
    if base: p(f'{tipo}/base_type = &"{base}"')
    p(f'{tipo}/styles/disabled = SubResource("{desact}")')
    p(f'{tipo}/styles/focus = SubResource("{vacio}")')
    p(f'{tipo}/styles/hover = SubResource("{normal}")')
    p(f'{tipo}/styles/hover_pressed = SubResource("{pres}")')
    p(f'{tipo}/styles/normal = SubResource("{normal}")')
    p(f'{tipo}/styles/pressed = SubResource("{pres}")')

# Texto
p(f'Label/colors/font_color = {MARRON}'); p('Label/font_sizes/font_size = 22')
for e in ["font_color","font_focus_color","font_hover_color","font_hover_pressed_color","font_pressed_color"]:
    p(f'Button/colors/{e} = {MARRON}')
p(f'Button/colors/font_disabled_color = {MARRON_SUAVE}'); p('Button/font_sizes/font_size = 24')
estados("Button",caja("boton_normal",32,20,10),caja("boton_presionado",32,20,10),caja("boton_presionado",32,20,10,APAGADO))
estados("BotonIcono",caja("boton_normal",32),caja("boton_presionado",32),caja("boton_presionado",32,0,0,APAGADO),"Button")
estados("BotonIconoToggle",caja("boton_normal",32),caja("boton_activo",32),caja("boton_presionado",32,0,0,APAGADO),"Button")
estados("BotonIconoLuz",caja("boton_normal",32),caja("boton_normal",32),caja("boton_presionado",32,0,0,APAGADO),"Button")
estados("Pestana",caja("pestana",20,6,6),caja("pestana_activa",20,6,6),caja("pestana",20,6,6,APAGADO),"Button")
p('Pestana/font_sizes/font_size = 18')
estados("Casilla",caja("casilla",24,8,8),caja("boton_presionado",32,8,8),caja("casilla",24,8,8,APAGADO),"Button")
p(f'PanelContainer/styles/panel = SubResource("{caja("panel",28,24,20)}")')
p('Pastilla/base_type = &"PanelContainer"'); p(f'Pastilla/styles/panel = SubResource("{caja("pastilla",28,22,6)}")')
rosa="Color(0.957, 0.627, 0.675, 1)"
p(f'HSlider/styles/slider = SubResource("{plano("Color(0.98, 0.85, 0.69, 1)")}")')
llena=plano(rosa)
p(f'HSlider/styles/grabber_area = SubResource("{llena}")'); p(f'HSlider/styles/grabber_area_highlight = SubResource("{llena}")')
for n in ("grabber","grabber_highlight","grabber_disabled"): p(f'HSlider/icons/{n} = ExtResource("tex_perilla")')
texturas["perilla"]="tex_perilla"

ext=[f'[ext_resource type="Texture2D" path="res://assets/ui/{n}.png" id="{i}"]' for n,i in texturas.items()]
txt="[gd_resource type=\"Theme\" format=3]\n\n"+"\n".join(ext)+"\n\n"+"\n\n".join(subs)+"\n\n[resource]\n"+"\n".join(sorted(prop))+"\n"
open('D:/zarita-la zarigueya/themes/zarita.tres','w',encoding='utf8',newline='\n').write(txt)
print(len(subs),'subrecursos',len(prop),'propiedades')
