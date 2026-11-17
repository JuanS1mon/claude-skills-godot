from PIL import Image
import numpy as np
ESC=4  # cada "pixel de arte" mide 4 px
MARRON=(116,68,66); CREMA=(255,241,220); DURAZNO=(250,217,176); SOMBRA=(226,182,138)
ROSA_CLARO=(252,205,210); ROSA=(244,160,172); ROSA_OSC=(220,128,146)

def forma(w,h,r):
    """Rectángulo redondeado en pixeles de arte: True dentro."""
    m=np.zeros((h,w),bool)
    for y in range(h):
        for x in range(w):
            cx=min(max(x+0.5,r),w-r); cy=min(max(y+0.5,r),h-r)
            m[y,x]=(x+0.5-cx)**2+(y+0.5-cy)**2<=r*r+0.01
    return m

def erosion(m,n):
    for _ in range(n):
        p=np.pad(m,1,constant_values=False)
        m=m&p[:-2,1:-1]&p[2:,1:-1]&p[1:-1,:-2]&p[1:-1,2:]
    return m

def marco(w,h,r,sup,inf,luz,borde=2,sombra=None,nombre=None):
    ext=forma(w,h,r)
    inte=erosion(ext,borde)
    img=np.zeros((h,w,4),np.uint8)
    img[ext]=(*MARRON,255)
    ys=np.arange(h)[:,None]*np.ones((1,w))
    # dos tonos: mitad de arriba clara y abajo durazno
    corte=borde+(h-2*borde)*0.45
    for y in range(h):
        for x in range(w):
            if inte[y,x]:
                c=sup if y<corte else inf
                img[y,x]=(*c,255)
    # brillo de 1 px bajo el borde de arriba
    for y in range(h):
        for x in range(w):
            if inte[y,x] and y>0 and not inte[y-1,x] is False:
                pass
    # línea de luz arriba (1px dentro del borde) y sombra abajo
    inte2=erosion(inte,1)
    for y in range(h):
        for x in range(w):
            if inte[y,x] and not inte2[y,x]:
                if y<h/2 and luz is not None: img[y,x]=(*luz,255)
                elif y>=h/2 and sombra is not None: img[y,x]=(*sombra,255)
    return Image.fromarray(img,'RGBA')

def guardar(im,nombre):
    im.resize((im.width*ESC,im.height*ESC),Image.NEAREST).save(f'D:/zarita-la zarigueya/assets/ui/{nombre}.png')

# Botones cuadrados redondeados de 28x28
guardar(marco(28,28,7,CREMA,DURAZNO,(255,251,240),sombra=SOMBRA),'boton_normal')
guardar(marco(28,28,7,(240,200,156),(232,186,140),(228,178,132),sombra=(214,164,120)),'boton_presionado')
guardar(marco(28,28,7,ROSA_CLARO,ROSA,(255,225,228),sombra=ROSA_OSC),'boton_activo')
# Pastilla de monedas 48x16 (borde 2)
guardar(marco(48,16,8,CREMA,DURAZNO,(255,251,240),sombra=SOMBRA),'pastilla')
# Panel 24x24
guardar(marco(24,24,5,CREMA,(253,232,205),(255,251,240),sombra=SOMBRA),'panel')
# Casilla (hundida): más oscura
guardar(marco(20,20,4,(236,198,152),(244,212,168),None,borde=2,sombra=(255,236,208)),'casilla')
# Pestañas
guardar(marco(24,14,4,DURAZNO,(240,200,156),(255,240,220),sombra=SOMBRA),'pestana')
guardar(marco(24,14,4,ROSA_CLARO,ROSA,(255,225,228),sombra=ROSA_OSC),'pestana_activa')
print('ok')
