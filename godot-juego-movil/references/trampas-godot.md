# Trampas de Godot 4 que ya nos costaron tiempo

Ordenadas por tema. Cada una dice **qué pasa, por qué y qué hacer**.

## Editor y archivos
- **Editar `.tscn`/`project.godot` con el editor abierto**: el editor pisa los cambios con su copia en memoria. Cerrar Godot sin guardar esas escenas, editar, reabrir. Un juego en ejecución también bloquea el archivo ("file in use"): cerrarlo.
- **`invalid UID ... using text path instead`** en scripts o recursos creados fuera del editor: inofensivo. Los `.tscn` escritos a mano pueden omitir `uid=`; si se reescribe una escena que otras referencian por uid, **conservar la línea `[gd_scene ... uid="..."]` original**.
- **Autoload nuevo** (Proyecto > Configuración > Globales): si da "ruta vacía"/parse error, borrar la fila, volver a elegir el script y reiniciar Godot. Las carpetas de configuración son del usuario: guiarlo, no editar `project.godot` con el editor abierto.
- **Errores de `scene/gui/tree.cpp`** en la consola son bugs internos del editor, no del juego.
- **Con el juego embebido** en la pestaña Juego, el modo debe ser *Entrada*, no *Selección*; si no, no llegan clics ni teclado.
- **Imágenes nuevas** deben importarse (volver a la ventana de Godot y esperar). Si se cambia una imagen sin cambiar el nombre, Godot la reimporta sola.

## Clases (`class_name`) y la caché del editor
- Un script **recién creado con `class_name`** suele dar "Identifier X not declared" hasta que Godot rescanea (guardar todo, cerrar y reabrir el proyecto). Pasó con `ColaZarita`, `ParpadeoZarita`, `TemaUI`, `BotonIcono`.
- Para ayudantes sin estado (clases estáticas, helpers) **no usar `class_name`**: `const Ayudante = preload("res://scripts/ayudante.gd")` funciona al instante. (Si el script tiene `class_name`, un `const` con el mismo nombre choca.)
- Para scripts de escena que otra escena instancia, usar variable **sin tipo** (`var hud = $Hud`) o `get_node`, y así no depender de la caché (`as Tipo` con una clase aún no registrada falla).
- Los scripts que dependen uno del otro (A usa `B` y `B` usa `A`) no se pueden inferir con `:=`: poner el tipo explícito, y a veces `load()` en vez de `preload()` para evitar dependencias circulares.

## GDScript tipado
- **`var x := evento.position`** falla ("Cannot infer the type") cuando `evento` es un `InputEvent` genérico: el analizador no estrecha el tipo dentro de un `elif`. Escribir `var x: Vector2 = evento.position`.
- `:=` con un valor de un método de otra clase sin tipo de retorno → error igual; tipar a mano.
- Una expresión ternaria con `+` se lee `(a + b) if c else d`; usar paréntesis si hay duda.
- `scroll_horizontal`/`scroll_vertical` son **enteros**: acumular el valor exacto en un `float` aparte.
- Una función que `await`ea un temporizador y cuyo nodo se libera puede dar error al reanudar: preferir un nodo `Timer` hijo.

## Controles (UI)
- **Los `Control` capturan el mouse por defecto** (`mouse_filter = Stop`): un `ColorRect`, `Label` o contenedor transparente bloquea los clics a lo que hay debajo. Poner `mouse_filter = Ignore` (valor 2 en el `.tscn`) a todo lo decorativo.
- El `.tscn` con `visible = false` oculta el panel también **en el editor**. Esconderlo en `_ready()` para poder diseñarlo.
- Un `Control` raíz con anclas "rectángulo completo" se ve del tamaño de la ventana del proyecto en el editor (720x1280), pero en un teléfono más alto se estira: usar anclas, no tamaños fijos, para HUD pegado a los bordes.
- **Variaciones de tema** (`theme_type_variation`): en el `.tres` se declaran con `Nombre/base_type = &"Button"` y sus `styles/...`. Un `StyleBoxTexture` necesita márgenes (`texture_margin_*`) para el 9 trozos y `content_margin_*` para el relleno.
- Los botones deben tener `focus_mode = 0` (None) si no se juega con teclado; si no, aparece el marco de enfoque.
- Un `ButtonGroup` hace que solo uno de los botones `toggle_mode` esté pulsado; crear el grupo por código y asignarlo.
- Un `PanelContainer` estira **todos** sus hijos a su tamaño: sirve para un overlay (resplandor) como último hijo.

## Entrada táctil
- En Android, Godot convierte el toque en **clic del mouse** (`emulate_mouse_from_touch`, activo por defecto) y *además* manda eventos táctiles. Escribe la lógica con **eventos de mouse** (funciona en PC y celular) y, en un `ScrollContainer`, **frena el toque nativo** con `accept_event()` en `_gui_input` para que no se sume al propio. Orden de eventos: `_gui_input` del script corre antes que el C++ del control; si el script llama `accept_event()`, el nativo no corre.
- Un botón que recibe el clic **no** lo deja pasar al contenedor: en listas con scroll, las casillas deben decidir el gesto (deslizar vs. agarrar) y reenviar el arrastre.
- Mientras un botón del mouse está apretado, el control que recibió el clic sigue recibiendo `InputEventMouseMotion` aunque el dedo salga de su rectángulo.
- `InputEventMouseMotion.relative` y `global_position` existen; `position` es local al control.

## Input de nodos del mundo (Area2D)
- El *picking* de `Area2D` ocurre en el **frame de física**, después de la GUI y de `_unhandled_input`. Si la GUI aceptó el evento, el `Area2D` no lo recibe (así un botón sobre un mueble no lo arrastra).
- **Todos los `Area2D` solapados bajo el cursor reciben** `input_event`: si hay una radio sobre una mesa, ambas "se agarran". Solución: juntar candidatos en un arreglo estático y elegir uno con `call_deferred` (primero el apoyado, luego el de base más abajo).
- `reparent(nuevo)` conserva la posición en pantalla por defecto; úsalo para apoyar/soltar un objeto de una mesa.
- Un `Control` hijo de un `Node2D`/`Area2D` funciona (botón flotante sobre un mueble); poner `z_index` alto para que quede por encima de los demás.

## Dibujo y orden
- `y_sort_enabled` ordena **solo los hijos directos**. Un objeto que pasa a ser hijo de otro (apoyado en una mesa) se dibuja con su padre, en orden de árbol (último = encima): por eso el apoyado se ve sobre la mesa.
- `z_index` es **relativo al padre** salvo `z_as_relative = false`; los hijos heredan.
- `CanvasModulate` tiñe el mundo pero **no** las capas `CanvasLayer`: la interfaz va en un `CanvasLayer` para no oscurecerse de noche.
- `clip_children` en un `Sprite2D` (máscara del cristal) recorta a sus hijos: así el cielo se ve solo por el vidrio de la ventana.
- Un `_draw()` de un nodo `Area2D` se dibuja **antes** que sus hijos (los tapa el sprite). Para marcas encima del sprite, usar un nodo hijo con la señal `draw`.
- `draw_colored_polygon` con el último punto repetido (igual al primero) falla al triangular: pasar `puntos.slice(0, n)`.
- Una **misma textura compartida entre dos `PointLight2D`** da un error interno; cada luz carga su propia copia.
- Un script `@tool` se ejecuta también en el editor: sirve para dibujar guías, pero cuidado con `add_to_group` por código (no se guarda) → poner el grupo en el `.tscn`; y con `visible`/`queue_free` en `_ready`.
- Un sprite con la imagen en espejo: `Sprite2D.flip_h` (para dar vuelta un mueble) o, si la animación se genera a partir de otra, guardar los cuadros espejados como PNG.

## Escenas heredadas y datos
- Para que un `Mueble` creado por código tenga su tamaño y colisión, **asignar las propiedades antes de `add_child`** (el `_ready` ya las lee).
- Un `setter` de propiedad que llama a `_actualizar_aspecto()` debe protegerse con `if not is_node_ready(): return`.
- Las fichas `Resource` se guardan por **ruta**; el nombre del archivo es su identificador en el guardado JSON. Cambiar el nombre rompe partidas viejas.
- `ResourceLoader.list_directory("res://carpeta/")` devuelve nombres (las carpetas terminan en `/`); en un APK exportado también funciona con los recursos importados.

## Mobile / rendimiento
- Renderer **Mobile** (Vulkan). Funciona en casi todos los celulares de los últimos años; si hay que apuntar más bajo existe *Compatibility*.
- Las sombras con `LightOccluder2D` y muchas `PointLight2D` cuestan: se usaron sombras **dibujadas** (elipses suaves por código, sin oclusores) y se dejó un interruptor (`activa`) para la luz natural.
- `CPUParticles2D` (no `GPUParticles2D`) para lluvia/nieve/hojas: más compatible y suficiente.
- Texturas con `import_etc2_astc` activado antes de exportar a Android.

## Texto y fuentes
- La fuente por defecto de Godot no es pixel-art; para un look consistente conviene una fuente pixelada (pendiente en Zarita). Tamaños usados: etiquetas 22, botones 24, títulos 34, números de monedas 30.

## Un contenedor a pantalla completa se come los toques de los botones hermanos
Un `VBoxContainer`/`MarginContainer` que cubre toda la pantalla tiene `mouse_filter = PASS` por defecto y recibe el toque **antes** que un botón hermano que quedó debajo en el árbol: el botón se ve pero no responde. Arreglo: `mouse_filter = 2` (ignore) en el contenedor (sus hijos siguen funcionando) y/o colocar el botón al final del árbol. Las pruebas que emiten `button.pressed` no lo detectan: probar con un clic real, `Input.parse_input_event(InputEventMouseButton)` con la posición en coordenadas de ventana (centro del control × escala de la ventana de prueba; usar `get_global_transform() * (size / 2)` si hay escala).

## Más trampas (juego idle de olas, 2026-11)
- **Nombres de variable que pisan propiedades del nodo**: `var material` en un script de `Control` choca con `CanvasItem.material` (error o comportamiento raro). Evitar `material`, `position`, `name`, `owner`, `visible`, `modulate`, `size`... como nombres propios; usar `etiqueta_material`, `posicion_destino`, etc.
- **Llamar a un método de un nodo recién instanciado antes de su `_ready`**: los `@onready` aún son `null`. Proteger con `if not is_node_ready(): return` y volver a aplicar el valor guardado dentro de `_ready`/`_aplicar_ficha`.
- **`%e` no existe en el formato de GDScript** (`"%e" % x` da error). Para números enormes en un juego idle escribir una función propia (`Ayudas.numero`) con sufijos K, M, B... y notación científica a mano.
- **`:=` con `Dictionary.get()` o `Array[i]`** devuelve `Variant` y no se puede inferir: `var recursos: Dictionary = r.get("recursos", {})`; en una condición `var hay: bool = int(r.get("oro", 0)) > 0 or not recursos.is_empty()`.
- **Una mejora de "velocidad de oleadas" no se hace acortando el intervalo de aparición**: cambia la dificultad (el equipo cayó de la ola 45 a la 33). Acelerar con `Engine.time_scale` **relativo** y deshacerlo al salir de la misión (`_quitar_velocidad`), así la profundidad queda igual.
- **`await` de un anuncio o diálogo desde un botón**: mientras espera, un segundo toque lanza otra llamada y el botón de "cerrar" puede borrar el cartel. Usar un indicador `_ocupado` y que el cierre lo respete.
- **Cartel con muchas líneas que se desborda** (muchos premios): agrupar líneas iguales ("Cápsula x12") y dar al texto un alto máximo; probar con el peor caso.
- **Dos avisos a la vez se tapan** ("ola superada" y "hito alcanzado"): guardar el segundo (`_texto_hito`) y mostrarlo cuando termina el primero.
- **Cambiar `config/name` cambia la carpeta de guardado en la PC** (`%APPDATA%\Godot\app_userdata\<nombre>`): al renombrar el juego hay que copiar `partida.json` a la carpeta nueva. En Android no afecta. La copia de pruebas usa otro nombre a propósito.
- **Edición de scripts con tildes desde la shell**: un heredoc de Git Bash/PowerShell **corrompe** los caracteres no ASCII (`ó` → basura) y ediciones parciales dejaron funciones duplicadas. Escribir un script Python con la herramienta de escritura de archivos y que cada reemplazo haga `assert viejo in texto` (falla si no aparece).
- **Un contenedor con `mouse_filter = PASS` que contiene un ScrollContainer** (pantalla entera dentro de un scroll) también bloquea: ver la trampa de arriba, probar siempre con clic real.

## Un `z_index` negativo puede dejar algo DEBAJO del suelo (Albatros, 2026-11-10)
En la batalla, las minas se agregaban al nodo de los personajes con `z_index = -3` "para que queden en el piso". El `z_index` ordena contra TODO el lienzo, no solo contra los hermanos: quedaron debajo del `TextureRect` del suelo (z 0) y no se vieron nunca, aunque explotaban bien. Nadie lo notó hasta sacar una captura con la mejora puesta. Para algo que va en el piso, colgarlo de un nodo que esté en el árbol entre el suelo y los personajes (acá, `Decorado`) y dejar el `z_index` en 0; reservar el `z_index` positivo para lo que tiene que ir arriba de todo (la piedra que cae, un velo). Regla: cada cosa nueva que se dibuja se mira en una captura, no alcanza con que "funcione".
