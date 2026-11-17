# Arte con IA para un juego de pixel art relajante

Juan genera las imágenes con una IA de imágenes y las manda; Claude las **recorta, limpia y prepara**. Los scripts están en `scripts/` (Python con Pillow, numpy, scipy). Aprendimos a **no esperar perfección de la IA** y a corregir con Pillow lo que falla (esquinas, ortografía, una animación).

## Regla de oro del flujo
1. Pasar un **prompt listo para copiar** (en inglés para el estilo; el texto del juego, entre comillas, en español).
2. Juan manda la imagen. **Mirarla** (`Read` de la imagen) antes de procesar.
3. Procesar → **vista previa compuesta** sobre el fondo real del juego → mirar → integrar.
4. Guardar en `assets/<tema>/` y crear la ficha/escena.
Siempre pedir **fondo verde plano** (#00FF00) para poder quitarlo; y que las piezas estén **separadas** (sin tocarse) para cortar por componentes.

## Plantilla de prompt (hoja de objetos)
```
A sprite sheet of N <cosas> for a cozy pixel-art life-sim game, arranged in a clean grid of C columns x R rows,
each object centered in its own cell with generous empty green space between objects (they must NOT touch or overlap).
No text, no labels, no frames, no background scenery.
Style: cute chunky pixel art, soft pastel palette (cream #FFF1DC, peach #FAD9B0, soft pink #F4A0AC, mint, sky blue),
thick dark rosy-brown outline (#7A4545) around every shape, one white highlight pixel, simple readable silhouettes,
all objects the same scale and level of detail, viewed from a slightly raised 3/4 front angle.
Objects, left to right then top to bottom: 1. ... 2. ... (describir cada uno con su función)
Flat solid pure green background (#00FF00), no gradients, no shadows on the background.
```
Variantes usadas: muebles por categoría (sillas, camas, mesas, almacenaje, plantas, decoración, baño, cocina); ventanas (3 diseños: marco con cristal, ver abajo); cielos (4 imágenes de cielo: noche, amanecer, día, atardecer, más `sol.png` y `luna.png`); iconos de interfaz; logo.
- **Vista consistente**: pedir siempre el mismo ángulo (3/4 desde arriba) para que los muebles convivan en la misma casa.
- Si la hoja trae objetos de más (pasó con la hoja de iconos: 10 en vez de 8), **aprovecharlos** (el foco rosado = "luz apagada").

## Quitar el fondo verde (`scripts/quitar_verde.py`, `cortar_hoja.py`, `cortar_muebles.py`)
Método que funcionó, mejor que "color cercano al verde":
- **Verdor** = `g - max(r, b)`. El fondo ronda 200 (varía con viñeteo).
- `alfa = 1 - clip((verdor - 0.05·G) / (0.75·G), 0, 1)` con `G` = verdor del fondo (percentil de la imagen).
- **Desmezclar el borde**: para píxeles semitransparentes, `fg = (color - (1-alfa)·fondo) / alfa`; después **despill**: `g = min(g, (r+b)/2 · 0.97)` solo en esos píxeles. Sin esto queda un halo verde/oliva.
- **Cortar piezas**: máscara de alfa > 0,3 → dilatar ~9 px → `scipy.ndimage.label` → una pieza por componente (así la chispa o la hoja suelta se queda con su objeto) → recortar al bbox real → ordenar por filas (arriba→abajo, izquierda→derecha) para ponerles nombre. Si dos piezas se funden, separar por una columna vacía.
- **Umbrales por objeto**: un umbral ancho se come las hojas de una planta o deja halo en una lámpara; por eso `cortar_muebles.py` admite umbral por pieza (45 por defecto, 90-95 para lámpara/silla; `RELLENO = 0` si hay huecos cerrados que no deben rellenarse).
- **Ventanas** (`procesar_ventanas.py`): además de cortar, detecta el **cristal** (huecos cerrados de la imagen) y genera `<d>_marco.png`, `<d>_cristal.png` (máscara para `clip_children`) y `<d>_parche.png` (forma de la mancha de luz, desenfocada).
- Guardar PNG RGBA. `tamano` de la ficha ≈ tamaño del PNG × 0,75.

## Fondos de pantalla (pantalla de inicio, suelo de la casa)
- La IA/edición del usuario suele dejar **franjas grises** en los bordes: medirlas (`gris = |r-g|<8 & |g-b|<8 & 60<r<140`, fracción por columna/fila) y **recortar** antes de escalar a 720×1280 (`LANCZOS`). Mantener la proporción; si sobra ancho, recortar centrado (`TextureRect` con `stretch_mode = 6` "cubrir" también lo resuelve).
- **Suelos**: 720×1280 con marco y franja de pared arriba, idénticos entre variantes (vertical/horizontal) para que encajen en la colisión y en la altura donde se pegan las ventanas. Guardar ambos y elegir por `Texture` del nodo `Suelo`.
- Comprobar siempre una **composición de prueba** (fondo + personaje + botón en sus posiciones reales).

## Logo / texto en imagen
- Pedir letras "chunky pixel art" con contorno marrón y el texto exacto entre comillas, **y que se verifique la ortografía**: la IA falla con diéresis/tildes ("zarigüeya" salió con un solo corazón en vez de dos puntitos). Corrección en Pillow: borrar el adorno, **dibujar dos corazoncitos** (copia reducida al 50 %) donde van los puntos.
- Se usa en un `TextureRect` con `stretch_mode = 5` (mantener proporción) dentro de un recuadro fijo.

## Personaje
Lo hecho con Zarita (bípeda, gris y crema, suéter rosa, overol azul con corazón y moño):
- **Referencia oficial** (`zarita_oficial_frente.png`) como imagen de entrada para todas las generaciones; ante deriva de estilo, **volver a generar desde esa referencia** (la primera versión salió realista y se descartó).
- **Hojas de caminata** de 4 cuadros por dirección (abajo, arriba, derecha; **izquierda = derecha espejada** como PNG, porque la generada hacia la izquierda movía poco el brazo).
- `armar_direccion.py`: corta la hoja por huecos verticales vacíos, quita el verde, **normaliza el alto** (alto del cuadro neutral) y **alinea el centro de la cabeza** en un lienzo común (así no "salta" al animar). `armar_conectadas.py`: lo mismo por componentes conectados cuando la cola de un cuadro toca la nariz del siguiente.
- **Consistencia de ropa** entre vistas: con Pillow se igualó el color del suéter y del overol al de los demás costados y se dibujó el corazón del peto en el frente.
- El **cuadro 2** de cada animación es el de reposo; al caminar, los cuadros "en reposo" (impares) suben unos px (`rebote`) para disimular el paso repetido. En el cuadro de reposo del personaje se usa `_sprite.pause()` + `frame = 1`.
- Origen del sprite en los **pies** (para el `y_sort`) y escala fija (0.25 en el mundo, 0.62 en la pantalla de inicio).

### Parpadeo (`parpadeo.py`, `parpadeo_zarita.gd`)
- Capas **PNG transparentes del tamaño del cuadro** con los párpados cerrados (4 por dirección, de espaldas no hay). Generación: detectar los ojos como manchas oscuras (`r<100,g<75,b<75`, componentes conectados en una caja relativa), **rellenar el ojo con una difusión suave del pelaje vecino** (el relleno por vecino más cercano dio "estrellas": no usar) y dibujar un arco de 3 px.
- En el juego: un `AnimatedSprite2D` hijo del sprite del personaje que copia `animation` y `frame` del cuerpo y se muestra 0,13 s cada 2,5-6 s (20 % de las veces parpadea dos veces).

### Cola que se mueve (`shaders/cola.gdshader`, `cola_zarita.gd`)
- Un **shader `canvas_item`** deforma solo la zona de la cola: uniforms `zona` (vec4 izquierda, arriba, derecha, abajo en UV), `punta_a_la_izquierda`, `eje`, `amplitud`, `velocidad`. Peso a lo largo de la cola 0 (base) → 1 (punta) con `smoothstep`, y `UV + eje * sin(TIME*velocidad + UV.y*6 + UV.x*6) * amplitud * peso`.
- La zona cambia por animación (diccionario `ZONAS` en `cola_zarita.gd`) y se reaplica al cambiar de animación. Se **verificó simulando la fórmula sobre los cuadros** en Python (solo debía moverse la cola) antes de integrarlo.
- Pega bien porque es barato; si se ve "temblorosa", bajar `amplitud` o suavizar.

### Animaciones por composición (`dibujar_props_mate.py`, `componer_mate.py`)
La IA no sabe dibujar un mate/termo: se **dibujaron a mano como mapa de píxeles** (paleta + matriz de caracteres) y se compuso la animación (levantar el mate al hocico moviendo la mano). Útil cuando la IA falla con un objeto concreto.

### LoRA propio (experimento)
`armar_dataset_lora.py` prepara cuadros transparentes sobre varios fondos lisos de 512×512 con subtítulos (palabra clave + vista) para entrenar un LoRA del personaje. `pixelizar.py` convierte una imagen de IA en **pixel art real** (quitar fondo, recortar, reducir a la grilla, limitar paleta, ampliar con vecino más cercano). Son herramientas de segunda línea: la IA de imágenes online con la referencia dio mejores resultados más rápido.

## Prompts de ejemplo ya usados (adaptar)
**Iconos de interfaz** (8-10 iconos en cuadrícula 4×2 con fondo verde): sillón con chispas (decorar), puesto de tienda con toldo rosa y crema, bombilla con brillo, sol tras una nube, moneda dorada con corazón, gema rosa facetada, TV retro con triángulo de reproducir y una gema (ver anuncio), "X" redondeada (cerrar). Estilo: contorno marrón rosado #7A4545 grueso, crema #FFF1DC, durazno #FAD9B0, rosa #F4A0AC, amarillo #FFD66B.
**Logo**: dos líneas, "Zarita" grande y "la zarigüeya" más chica, letras redondeadas crema/durazno con contorno marrón, moño rosa sobre la Z, fondo verde.
**Fondo de inicio** (sin personaje): interior de una cabaña de madera cálida, luz dorada por la ventana, plantas, sillón con manta, mate y pava; **sin personaje** (se anima aparte), vertical.

## Sprite animado pequeño (bichitos, efectos): hoja de variantes x cuadros
Prompt que pide una cuadrícula **filas = variantes de color, columnas = cuadros de un bucle**: "N columns x M rows, each ROW one color variant, each COLUMN one frame of the same loop, the body stays in the SAME position and size in all frames, only wings/glow change"; describir **cada cuadro** (alas arriba / abiertas / abajo; brillo medio / máximo / mínimo), colores por fila con hex, contorno #7A4545, halo en 2-3 anillos planos, fondo #00FF00. Procesar: cortar por componentes, quitar verde, **alinear al centro del cuerpo** y guardar `assets/<tema>/<variante>/<n>.png`; armar un `SpriteFrames` por ficha y un campo `frames` en su `Resource` (sin `frames` la escena sigue mostrando el placeholder). Ver `escenas-y-datos.md` (placeholders visibles + `AnimatedSprite2D`).

## Verificación visual obligatoria
Antes de integrar: `Image.alpha_composite` del recurso sobre el fondo real a su tamaño real; `Read` de la imagen resultante; si se ve mal, ajustar umbral/escala/posición. Para detalles pequeños, `resize(..., Image.NEAREST)` ×4 y mirar.

## Licencias
- Arte de terceros solo para aprender (p. ej. un pack gratuito de uso personal) va en `assets/practica/`, **nunca se usa en el juego publicado** y se **excluye al exportar** (`exclude_filter="assets/practica/*"`).
- Antes de publicar revisar las políticas de la tienda sobre contenido generado con IA.

## Cuando la IA dibuja un "tablero de transparencia" falso
Algunas IA entregan los iconos sobre un **tablero blanco y gris pintado** (la imagen NO tiene alfa real) dentro de un rectángulo sobre el fondo verde. Receta que funcionó:
1. Localizar cada rectángulo (píxeles no verdes, `binary_closing` + `label`) y **recortar 4 px hacia adentro** para perder el borde verdoso.
2. Candidatos = píxeles **neutros** (`max-min <= 14`) y blancos (`>= 234`) o grises (`180-214`).
3. Quitar los componentes conectados que **tocan el borde del rectángulo**, y los huecos interiores grandes (>150 px) que contienen **los dos colores** del tablero (así se vacía el asa de una pava sin tocar sus reflejos).
4. Dos pasadas de **halo**: píxeles claros y poco saturados pegados a lo quitado.
5. Borrar **motas sueltas** (componentes < 700 px, claros y neutros) que no sean el objeto principal; un vapor celeste no se borra porque no es neutro.
Los colores del propio objeto (crema, plateado cálido) no son neutros, por eso sobreviven.

## Animar un personaje a partir de UNA sola imagen (sin hojas de animación)
Cuando la IA entrega solo el diseño de frente, se anima **por código** (`assets/zarita/scripts/npc_amigo.gd`, modo `imagen`):
- **Respiración**: escalar el sprite en Y con `sin(t)` (±2 %) y en X al revés, con los **pies como origen** (así no flota).
- **Balanceo**: rotación de ±0,7° con otra frecuencia.
- **Parpadeo**: un nodo hijo que dibuja, 0,13 s cada 2,5-6 s, un rectángulo del **color de la piel** (promedio de un anillo de píxeles alrededor del ojo, sin lo muy oscuro) y una línea oscura sobre cada ojo. Los ojos se localizan con `tools/detectar_ojos.py` (manchas casi negras, pequeñas y redondeadas en la parte alta).
- **Cola**: el shader `cola.gdshader` con la zona de la cola (fracciones de la imagen).
- **Hablar**: rebote rítmico (|sin| a 3 Hz, +7 %) mientras dura el diálogo.
Para movimiento real (caminar, mover la boca) sí hacen falta cuadros dibujados.

### Bichitos: hoja de 4 cuadros x 3 colores (`scripts/armar_bichitos.py`)
La IA devolvió cada color **repetido en 2 filas** (6 filas): se usa la primera de cada par. Los anillos del brillo salen verdosos y se confunden con el fondo: en vez de quitarlos con la clave verde, el script **se queda solo con la silueta cerrada por el contorno marrón** (cerrar huecos con `binary_closing`, `fill_holes`, sumar el contorno original para no perder las antenas finas, quitar los píxeles muy verdes del cierre) y el **brillo lo dibuja la escena** con el color de la ficha. Alinea cada cuadro por la base y el centro del cuerpo (parte baja de la silueta, sin alas) en un lienzo común. En Godot: `data/bichitos_frames/<color>.tres` (SpriteFrames, ciclo 1,2,3,4,3,2 a 12 fps) y `frames` en la ficha.

## Fondo MAGENTA para arte verde (`scripts/quitar_magenta.py`, `cortar_habitaciones.py`)
Para árboles, pasto o cualquier cosa verde se pide **fondo magenta plano #FF00FF** (el verde se confundiría con el follaje). Magentez = `min(r,b) - g`; mismas fórmulas que el verde (alfa, desmezclar, despill). Prompts sin porcentajes ni "franjas": la IA los dibuja como cortes duros y hasta escribe los números; describir una escena continua. **Medir el hueco antes de integrar**: un árbol-casa con la apertura angosta (240x480) no sirvió para una grilla de 4 tarjetas; pedir "la apertura es casi tan ancha como el tronco" y, si hace falta, reducir las tarjetas al tamaño del hueco en vez de deformar el arte. Verificar con una captura real (ver probar-en-godot-desde-claude.md).

## Ropa para un personaje animado (prendas por capas)
Receta que funcionó con la bufanda y el poncho de Zarita (`scripts/limpiar_prendas.py`, `scripts/colocar_prendas.py`):
1. **Pedir a la IA la prenda "como puesta en un cuerpo invisible"** (ghost mannequin), en tres vistas (frente, espalda, costado derecho) y con el personaje de referencia adjunto solo para la escala. Fondo **del color que no se parezca a la prenda** (magenta si la prenda es verde).
2. **Limpiar**: quitar el fondo, el pedazo de cuello del maniquí (por filas: se borra todo lo de arriba mientras el ancho es chico, y la carne rosada por color), el interior oscuro de un cuello de bufanda (componente de color casi uniforme arriba) y los **contornos teñidos del color del fondo** (se recolorean al marrón del contorno, en toda la prenda).
3. **Colocar**: reescalar cada vista (no uniforme: las prendas de un personaje chibi son más anchas que altas) y pegarla sobre el cuadro de reposo con `(cx, arriba, ancho, alto)`, iterando con una vista previa sobre los 4 cuadros de cada dirección. Guardar **un PNG del tamaño exacto del cuadro** por dirección.
4. **En el juego**: un `Sprite2D` hijo del `AnimatedSprite2D` del personaje con la capa de la dirección actual: hereda posición, escala y rebote. Verificado en Godot con una captura de las cuatro direcciones.
