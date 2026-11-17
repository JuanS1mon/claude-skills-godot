# Sprites con Gemini desde Chrome (flujo que funcionó)

Juan prefiere Gemini (como en Albatros) a SpriteCook: SpriteCook gratis da 40 créditos (personaje base 12, primera animación 20, cada extra 14, poses de caminar/correr +12), no alcanza. Las reglas generales de arte con IA (fondo verde, quitar el verde, vista previa) están en `godot-juego-movil/references/arte-con-ia.md`.

## 1. Generar (Claude in Chrome)
1. `tabs_context_mcp` → `navigate` a `https://gemini.google.com/app` (la sesión de Juan ya está iniciada).
2. `find "prompt textbox"` → clic en el `textbox "Ingresa una instrucción para Gemini"` → `type` el prompt → `Enter`.
3. Esperar ~40 s. **La imagen no se ve en la conversación** (el recuadro queda gris y `document.querySelectorAll('img')` no la encuentra): buscar con `find` el botón `", generada por IA"` y hacerle clic → se abre el visor a pantalla completa con la imagen.
4. En el visor, el botón **Descargar** está arriba a la derecha (≈ x 1422, y 20 en una pantalla de 1568 de ancho). Baja a `~/Downloads/Gemini_Generated_Image_*.jpg` (JPG, ~1408x768). Tomar el más reciente.
5. Cerrar la pestaña al terminar.

## 2. Prompt de hoja de animación (plantilla)
Pedir **toda la hoja en una sola imagen**: el personaje sale mucho más consistente que en imágenes separadas.
```
Generate an image: a 2D game character sprite sheet for a side-scrolling platformer.
Character: <descripción con colores y accesorios>.
Every frame shows the character in strict SIDE PROFILE facing RIGHT, full body, same size and same proportions in every frame.
Layout: a clean grid of N rows, every frame separated by generous empty space (frames must NOT touch).
Row 1: IDLE, 4 frames of subtle breathing. Row 2: RUN cycle, 6 frames. Row 3: JUMP, 4 frames: crouch, rising, apex, falling.
Row 4: 4 frames: shooting forward with muzzle flash, lifting a box above the head, holding it overhead, throwing it forward.
Style: clean hand-drawn cartoon, flat cel shading with only two tones per color, thick dark outline around the whole character, bright readable colors.
No text, no labels, no grid lines, no shadows on the floor. Flat solid pure green background (#00FF00), no gradients.
```
Qué pasó de verdad:
- **Zorro**: salió excelente, 4/6/4/4 como se pidió. Pero 3 de los 4 cuadros del salto vinieron **sin la pistola** (inconsistencia de la IA).
- **Muñeco de práctica**: se pidió 4/3/3 y vino **6/3/4**, y "mirando a la izquierda" salió casi de frente. Hay que mirar la hoja y adaptar los nombres de los cuadros a lo que vino; no regenerar si se puede usar.

## 2b. Cuadros nuevos del MISMO personaje: adjuntar referencia
Para sumar animaciones (correr cargando, salto con pistola) se adjunta una imagen del personaje ya recortado (2 poses sobre verde, ampliadas x3: `arte_fuente/zorro_referencia.png`) y el prompt empieza con "using EXACTLY this fox character from the attached reference". Salió idéntico al primer intento.
- Adjuntar sin abrir el selector de archivos: clic en el botón `"Cargas y herramientas"` (aparecen `input[type=file]` ocultos), `find` → `file-input`, y `file_upload` con la ruta. Después `Escape` para cerrar el menú.
- La hoja nueva sale a otra escala: `herramientas/unir_cuadros.py <carpeta_personaje> <carpeta_nuevos> cargando cargando_corriendo_0` escala los nuevos comparando dos poses equivalentes y lleva todos los cuadros a un lienzo común (pies abajo).
- Al editar un `.tres` generado desde PowerShell con `AppendLine` ojo: tiene finales CRLF y un `Replace("`n`n[resource]")` no encuentra nada (el error en Godot fue "Can't load cached ext-resource id"). Usar la herramienta Edit.

## 3. Recortar (`assets/herramientas/cortar_hoja_personaje.py`)
```
python cortar_hoja_personaje.py [--ancla=base] hoja.jpg <carpeta_salida> "quieto_0,quieto_1,..." "corriendo_0,..." ...
```
Un argumento por fila con los nombres de cada cuadro (`-` descarta uno). Genera los PNG y una `<carpeta>_vista_previa.png` sobre gris: **mirarla siempre** con `Read`.
- Quita el verde con el método de Zarita (verdor, desmezclar, despill) más un despill extra para el ruido del **JPG**.
- **Filas**: primero por franjas horizontales vacías; si no coincide con la cantidad pedida (los cuadros del salto están a distintas alturas y se mezclan con la fila de arriba), ordena por altura y corta según la cantidad de nombres de cada fila.
- **Piezas sueltas**: lo grande (≥ 35 % de la pieza mayor) es un cuadro; lo chico pegado (< 30 px: estrellas, paja, fogonazo, orejas) se suma a ese cuadro; lo chico lejano (la caja que vuela al arrojar) se descarta. Una dilatación grande (6 px) unía cuadros vecinos: se usa 2.
- **Alineación**: pies abajo; horizontal por el **torso** (personajes) o por la **base** (`--ancla=base`, objetos fijos como el muñeco, que si no "patina" al inclinarse). Lienzo simétrico para `flip_h`.
- Correr con `python` (no `python -I`: con `-I` no encuentra numpy instalado para el usuario).
- Guardar la hoja original en `arte_fuente/` (fuera del proyecto Godot, para que no la importe).

## 3b. Personajes verdosos o varios personajes en una hoja (`cortar_hoja_relleno.py`)
- Un slime verde lima sobre fondo verde queda semitransparente con el método de "verdor". `cortar_hoja_relleno.py` saca el fondo por **relleno desde el borde** (el contorno oscuro frena el relleno) y solo quita huecos encerrados si son casi idénticos al fondo.
- `python cortar_hoja_relleno.py hoja.jpg <carpeta_sprites> "volador|centro|volar_0,..." "slime|base|quieto_0,..."`: un argumento por fila, cada fila puede ser un personaje distinto (ancla `base` = apoyado en el piso, `centro` = volador).
- Funcionó pedir **3 enemigos en una sola hoja** (murciélago, slime, caparazón del escarabajo): 6/6/2 cuadros como se pidió, al primer intento. En el visor ya no hace falta abrir la imagen: el botón `"Descargar imagen en tamaño completo"` aparece con `find` al lado de la imagen.
- Un cuadro nuevo para un personaje existente con lienzo más chico (caparazón) hay que pegarlo en un lienzo del MISMO tamaño que los demás cuadros, apoyado a la misma altura; si no, flota.

## 4. Godot
- Un `SpriteFrames` `.tres` con una animación por estado (ver `assets/escenas/` y el `zorro_frames.tres` del prototipo): quieto 6 fps en bucle (ida y vuelta 0-1-2-3-2-1), corriendo 12 fps, poses sueltas de 1 cuadro sin bucle.
- Importar con `--headless --import` antes de probar.
