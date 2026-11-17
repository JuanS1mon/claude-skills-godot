# Animar sprites y fondos con ComfyUI local (PC de Juan)

Sirve para sacar **cuadros de caminata** de un personaje a partir de **un solo sprite**, y para animar elementos de un fondo (remolino, fuego). Se usó primero en Zarita y después en *Héroes Idle Espacial* (Selene, Caldera y Zorg caminan con cuadros generados).

## Instalación (ya hecha)
- ComfyUI portable: `D:\herramientas\ComfyUI_windows_portable`. Arranque: `python_embeded\python.exe -s ComfyUI\main.py --windows-standalone-build` (puerto **8188**, API HTTP). GPU RTX 2060 de 6 GB: ~7 s por cuadro.
- Modelos: SD 1.5, LoRA `PixelArtRedmond15V` (palabras clave `Pixel Art, PIXARFK`), ControlNet **OpenPose**, **IP-Adapter plus** + CLIP-ViT-H. El LoRA `zarita_lora` solo sirve para Zarita.
- Antes de entrenar un LoRA propio hay que **liberar la GPU de ComfyUI** (`POST /free`).

## Receta de caminata (scripts en `scripts/comfy/`)
1. `poses.py <carpeta> 8` dibuja 8 esqueletos OpenPose de caminata **de perfil** con proporciones chibi.
2. `generar.py <poses> <referencia.png> <salida> [semilla] [peso_ip=1.05] [fuerza_cn]` manda cada pose a ComfyUI con el sprite del personaje (x4, sobre verde `#00FF00`, 512x512) como referencia. `PROMPT_FILE=prompt_<id>.txt` da un texto por personaje.
3. `limpiar.py <cuadros> <salida> <sprite_original>` quita el verde (y halos), alinea por pies y cabeza y lleva a ~92 px.
4. `igualar_color.py <cuadros> <sprite> <salida> 0.9` acerca los colores al sprite original.
5. En el juego: carpeta `assets/heroes/<id>_caminar/0..7.png` (128x96, pies al borde de abajo) y en la ficha `caminar` + `caminar_fps`. Sin cuadros el personaje se desliza (el script lo soporta).

## Lo que enseñó
- **Robots y alienígenas chocan con la pose humana**: Caldera necesitó `peso_ip 1.3` y `fuerza_cn 0.7` (con 1.05/1.0 cambió de diseño) y a cambio camina con las piernas casi quietas; Zorg quedó bien con 1.05/1.0. Probar 2-3 valores y **mirar la hoja de contacto** antes de integrar.
- Un cuadro que sale distinto del resto se arregla con la misma semilla y bajando la fuerza.
- Una hoja de cuadros se mira siempre antes de integrarla (hacer una `*_hoja.png` con Pillow).
- Para enemigos nuevos sin arte: usar el sprite de otro **teñido** como provisorio y dejar la ficha lista; el arte final se cambia sin tocar código.

## Animar un elemento de un fondo (`animar_elemento.py`)
Recorta la zona del fondo, le aplica movimiento (girar un ángulo o dejarla igual), la repinta con **img2img de poca fuerza** (con el LoRA de estilo del juego) y la devuelve con **máscara redonda suave**. Misma semilla en todos los cuadros → repintado parejo, sin temblor. Uso: `python animar_elemento.py fondo.jpg salida --zona x,y,ancho,alto --cuadros 12 [--girar] [--fuerza 0.3]`. En la escena, un nodo `Control` con `cuadros_vivos.gd` (carpeta de cuadros + zona + fps) los reproduce encima del fondo.

## LoRA de estilo del juego
`armar_dataset_albatros.py` arma recortes de 512x512 con subtítulo (todos empiezan con la palabra clave del estilo) y se entrena con sd-scripts (dim 32, 8 épocas, ~50 min en la 2060). Se usa en ComfyUI con peso ~0.8 para dar coherencia a salas, retratos y fondos.

## Hábitos
- Juan genera las imágenes grandes él mismo; Claude pasa **textos de prompt listos** (guardados en `docs/prompts_*.md`) y después recorta e integra.
- Dejar un `docs/continuar_arte.md` con el estado del arte y los pasos exactos de integración cuando el trabajo de arte sigue en otro chat.

## Rendimiento en celulares con animaciones por cuadros (aprendido en Albatros, 2026-11-02)
Muchos cuadros PNG = mucha memoria de video. En el primer intento (sets de 12 a 24 cuadros de 512x512 por sala, todos cargados al arrancar) el juego usaba **244-278 MB de memoria de video**. Lo que lo bajó a ~115-140 MB y mantuvo el costo de CPU en décimas de milisegundo:
- **Importar los cuadros como VRAM comprimida** (`compress/mode=2` en el `.import`, con `rendering/textures/vram_compression/import_etc2_astc=true`): 4 veces menos memoria. Dejar sin comprimir solo lo muy chico (brillos de 128 px).
- **Cargar los cuadros solo cuando la pantalla se ve** y soltarlos al esconderse (`visibility_changed` + `is_visible_in_tree()`); nada de cargar todo en `_ready`.
- **Redibujar solo cuando cambia de cuadro** (`queue_redraw()` al cambiar el índice, no cada `_process`), y que el nodo no procese mientras está oculto.
- Tamaño mínimo que se ve bien: un efecto de 60 px no necesita 512 px; mosaicos de partículas de 256x512 repetidos; `max_fps=60`.
- **Medirlo**: autoload de prueba con `DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)` y `await RenderingServer.frame_post_draw` x400, comparando con y sin los nodos animados (`Performance.RENDER_VIDEO_MEM_USED`, draw calls). `TIME_PROCESS` y el reloj con vsync no sirven (quedan clavados en 16,7 ms). Lo que no se mide en la PC: la GPU del celular (rellenado de capas a pantalla completa) -> probar en un celular de gama baja.

## Caminata de un sprite sin que cambie de cuadro en cuadro (aprendido en Albatros, 2026-11-03)
Si cada cuadro se genera DESDE CERO (txt2img + OpenPose + IP-Adapter), el personaje cambia de cuadro en cuadro (ropa, proporciones, accesorios) y pierde detalles del sprite quieto: el IP-Adapter no alcanza. Lo que funcionó:
1. **Posar el propio sprite** con código (Pillow/numpy): separar las piernas por el hueco que hay entre ellas, moverlas (adelante/atrás y levantar la que pasa), rebotar el cuerpo 1-2 px y mecer capa/brazo. Cuerpo, cabeza y ropa quedan idénticos pixel a pixel.
2. **ComfyUI como acabado, no como creador**: img2img con `denoise` ~0,2 sobre cada cuadro posado, misma semilla, IP-Adapter mirando el sprite quieto. Une las costuras y da el estilo.
3. **Llevar a la grilla de pixeles** (celdas de 4x4 del lienzo de 512) mezclando el pixel exacto del sprite con el promedio de la celda repintada (~40% repintado), y **sacar la transparencia del sprite posado**, no de cortar el verde (el casco de cristal es verdoso y se perdía; el recorte dejaba halos y rayas).
4. Alinear los cuadros a la grilla de 4 px (offset múltiplo de 4) o el promedio de celdas mezcla pixeles vecinos.
Scripts en `tools/comfy/` del proyecto Albatros: `posar_sprite.py`, `generar_v2.py`, `limpiar_v2.py`.

## Límite del LoRA de personaje: no cambia de pose (aprendido en Zarita, 2026-11-04)
Se probó sentar, acostar y hacer leer a Zarita con SD 1.5 + `zarita_lora` (entrenado solo con 16 cuadros de caminata, de pie) + IP-Adapter + ControlNet OpenPose (esqueletos propios en `tools/comfy/poses_acciones.py`). Resultado: **sale siempre de pie**, el texto de la pose se ignora, y con ControlNet fuerte salen cuerpos deformados. SD 1.5 con un LoRA así de ceñido no sirve para poses nuevas; para eso hace falta un modelo de edición mejor o un LoRA entrenado con varias poses.
Lo que sí funcionó (`tools/crear_poses_zarita.py`): **componer con Pillow a partir del propio dibujo** (cabeza rotada unos grados, piernas en escorzo y mitades que se mecen, ojos cerrados con la capa de parpadeo, props dibujados en "celdas" del mismo tamaño que el grano del personaje, y la silueta recortada por contorno). A 0,25x en pantalla los defectos finos no se ven y el personaje queda idéntico. El mismo recorrido (ancla + `offset` del `AnimatedSprite2D`, `flip_h` con el offset invertido) sirve para cualquier pose.
