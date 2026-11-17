# Interfaz táctil: tema, HUD, joystick, listas, ajustes

Pantalla vertical 720x1280, pensada para el **pulgar**. Código: `hud.gd`, `joystick_virtual.gd`, `scroll_deslizable.gd`, `slot_mueble.gd`, `ajustes.gd`, `inventario_ui.gd`; escenas en `assets/zarita/escenas/`; tema en `assets/zarita/temas/zarita.tres`.

## Tamaños y zonas
- Botones principales **150×150 px** (icono de ~100). Pastillas de saldo de ~64 px de alto. Márgenes de 24 px al borde.
- Zona del pulgar = **mitad inferior**: barra de 4 botones abajo; joystick sobre la barra (30..270 px del borde, 240×240); ajustes (tuerca, 100 px) arriba a la derecha; saldos arriba a la izquierda.
- Solo icono en los botones (sin texto) + **aviso temporal** sobre la barra para confirmar lo que se hizo ("Clima: Lluvia").
- Paneles ocultan lo que molesta: el joystick se esconde al decorar (el inventario ocupa su lugar).

## Pipeline del tema (pixel art, 9 trozos)
1. **Marcos con Pillow** (`scripts/marcos_ui.py`): cada "pixel de arte" = 4 px reales. Se dibuja una forma redondeada (rectángulo con esquinas de `r` píxeles), contorno marrón de 2 px, relleno en **dos tonos** (crema arriba, durazno abajo), línea de luz arriba y de sombra abajo. Salidas: `boton_normal`, `boton_presionado` (más oscuro), `boton_activo` (rosa, para toggles), `pastilla` (barra de saldos), `panel`, `casilla` (hundida), `pestana`, `pestana_activa`. Hacerlos por código garantiza esquinas exactas, que la IA no da.
2. **Archivo de tema** `themes/zarita.tres` generado con `scripts/gen_tema.py` (escribe el `.tres` como texto: `StyleBoxTexture` con `texture_margin_*` = 32 para botones, 28 para paneles/pastilla, 20 para pestañas, 24 para casillas; `StyleBoxFlat` para el deslizador; la perilla del deslizador es un PNG). Las rutas del script están escritas para el proyecto de Zarita: **cambiarlas**. También puede editarse a mano o en el editor (Theme).
3. **Variaciones**: `BotonIcono` (pulsado = oscuro), `BotonIconoToggle` (pulsado = rosa), `BotonIconoLuz` (el marco no cambia: cambia el icono), `Pestana`, `Casilla`, `Pastilla`; más estilos base de `Button`, `PanelContainer`, `Label` (color marrón, tamaño 22), `HSlider`.
4. **Asignar el tema en el nodo raíz de cada escena de interfaz** (`theme = ExtResource(...)`), así se ve igual en el editor. (Alternativa: Proyecto > Configuración > GUI > Tema > Personalizado.)
5. Estados: `normal`, `hover`, `pressed`, `hover_pressed`, `disabled` (el mismo marco con `modulate_color` gris translúcido), `focus` vacío.

## Iconos
- Una sola **hoja de IA** de 8-10 iconos sobre fondo verde, con un prompt que fija el estilo (contorno marrón rosado grueso, colores pastel, resaltado blanco de 1 px, mismo grosor y tamaño) — ver `arte-con-ia.md`.
- Recorte: quitar el verde (despill + desmezclar el borde) y cortar por **componentes conectados dilatados** (`scipy.ndimage.label` sobre la máscara dilatada ~9 px, para que las chispitas queden con su icono). Si dos iconos se funden (TV + X), partir por una columna vacía.
- Cada icono se centra en un lienzo 128×128 escalado para ocupar ~104 px. Los que la IA no hace bien o faltan (tuerca de ajustes, voltear) se **dibujan en Pillow** en una grilla de 32×32 y se amplían ×4 con vecino más cercano (silueta + contorno por erosión + relleno de dos tonos).

## HUD como escena
- `Hud` (Control a pantalla completa, `mouse_filter = Ignore`) con: `BarraSuperior` (HBox con pastillas de monedas y gemas), `Joystick`, `BarraInferior` (HBox centrado con 4 `Button`, cada uno con hijo `TextureRect` "Icono" a 24 px de margen), `Aviso` (label con contorno), e instancia de `Ajustes`.
- Cada botón tiene `theme_type_variation`, `custom_minimum_size`, `focus_mode = 0`. El **icono es un nodo** (visible en el editor); solo la luz cambia de textura por script (`@export icono_luz_apagada`).
- `hud.gd` solo emite señales y muestra saldos/avisos; el orquestador (`casa.gd`) las conecta. Los paneles (tienda, ajustes) se muestran/esconden en `_ready` y se abren desde esas señales.

## Joystick virtual (`joystick_virtual.gd`)
- `Control` con `@tool` (se dibuja en el editor), en el grupo `joystick` (puesto en el `.tscn`). Dibuja base (crema, borde marrón) y palanca (rosa con brillo) con `draw_circle`/`draw_arc`.
- Lee **eventos de mouse** (`_gui_input`): clic dentro → `_tocando`; movimiento → palanca = `(pos - centro).limit_length(RADIO)`; `direccion` = palanca/RADIO si supera `ZONA_MUERTA`. En Android el toque llega como clic, así que el mismo código sirve en PC y celular. **Una sola vía de entrada**, sin duplicar con `InputEventScreenTouch`.
- El personaje: si el teclado no empuja (`Input.get_vector == ZERO`), usa `joystick.direccion`; velocidad **analógica** (más lejos, más rápido).
- Lado configurable (ajustes): se cambian **anclas y offsets** del nodo (`_colocar_joystick`). Se esconde al decorar (al hacerse invisible se suelta: `visibility_changed`).
- Límite conocido: **un solo dedo** (el toque emulado como mouse). Si se quiere mover y tocar a la vez, hay que pasar a `InputEventScreenTouch` con índice de dedo.

## Listas que se deslizan (`scroll_deslizable.gd`)
- `ScrollContainer` con `@export horizontal`. Arrastrar con dedo/mouse **sin barra** (modo de scroll "Nunca mostrar" en la escena), con **inercia**: velocidad = `lerp(v, -desplazamiento/segundos, 0.4)`; al soltar, si va rápido, `_process` sigue con `exp(-FRICCION*delta)` hasta bajar de `VELOCIDAD_MINIMA`.
- Umbral de 10 px para distinguir arrastre de toque. Frena el scroll táctil nativo (`accept_event` en eventos de pantalla).
- Los botones dentro de la lista (casillas) deciden el gesto y reenvían con `empujar(relativo)` / `soltar()` (ver `slot_mueble.gd`).

## Retroalimentación que se sintió bien
- **Resplandor** del panel destino mientras se arrastra algo encima (borde dorado con `StyleBoxFlat`: `draw_center = false`, borde de 6 px y `shadow_size`; late con un `Tween` en bucle) y el objeto arrastrado se vuelve semitransparente.
- **Saltito** (squash & stretch con `Tween`) al apoyar o voltear.
- **Imán y deslizamiento suave** hacia el destino válido; marcas visibles de dónde se puede soltar.
- **Aviso breve** en vez de un cambio mudo.
- Botón flotante contextual (voltear) que **se apaga solo** a los 3 s.

## Ajustes (`ajustes.tscn`)
- Tuerca arriba a la derecha → panel con **sonido** (botón Activado/Silenciado + `HSlider` de volumen sobre el bus Master) y **lado del joystick** (dos botones `Pestana` en un `ButtonGroup`). Guarda en `user://ajustes.cfg` y emite `joystick_lado_cambiado` para que la casa recoloque el joystick.
- Se aplica al cargar. Pendiente natural: idioma, vibración, gráficos bajos (apagar `LuzNatural`).

## Que se entienda sin explicación (intuitivo)
Decisión de Juan (Albatros, 2026-11-02): **no hacemos tutorial guiado**; el juego tiene que ser intuitivo. Cómo se baja a la práctica:
- **El primer mundo/nivel es más fácil y ya**: sirve de entrenamiento (enemigos al 60%, sin rasgos peligrosos) sin cartel ni pasos. Para que no parezca un tutorial, no se le avisa al jugador.
- **El gesto que se usa es el que la mano espera**: deslizar el dedo hacia arriba para acercar y hacia abajo para alejar un mapa; tocar una cosa la elige; tocar y deslizar encima de una cosa NO la elige (el botón mira si hubo arrastre).
- **Una pista mínima y pegada a lo que explica**, no un texto aparte: una pastilla sobre el mapa que cambia según el estado ("Desliza hacia arriba para acercar" / "Desliza hacia abajo para alejar"), el motivo por el que un botón está deshabilitado escrito en el detalle ("Cerrado: se abre completando el sistema 2", "Falta combustible").
- **Estados a la vista**: lo cerrado se ve apagado y con la palabra "cerrado", lo completado dice "completado", donde está la nave dice "la nave está acá"; un número que va de un máximo ("55 / 100") se muestra como una barra o un tubo que se llena, no solo como texto.
- **Reglas simples y parejas**: dentro de un grupo todo está abierto; lo que se desbloquea tiene una sola condición clara y visible.
- Si para usar una pantalla hace falta leer más de dos líneas, se rediseña la pantalla.

## Que la interfaz responda ("juice") sin tocar las escenas (Albatros, 2026-11-10)
Un juego completo pero "seco" se siente lento aunque no lo sea. Cinco cosas baratas que cambiaron cómo se siente, todas en un ayudante de funciones `static` (`assets/idle/toque.gd`, se usa con `const Toque = preload(...)`):
- **Todo botón se hunde y rebota**: un autoload que ya escucha `get_tree().node_added` (el del sonido del clic) llama a `Toque.enganchar(boton)`; la escala de reposo se mide en cada toque (otro código puede haberla cambiado) salvo que todavía esté rebotando.
- **Los carteles entran con un "pop"** (`aparecer(panel)`) y **las pantallas con un fundido que sube** (`entrar(pantalla)`; antes `asentar` a las demás para que ninguna quede a medio aparecer si se cambia rápido).
- **Las listas de premios caen de a una** (`escalonar(nodos, paso)`): en un x10 de gacha, 0,07 s por carta y un destello del color de la rareza en las buenas.
- **La acción principal de la pantalla late** y la cruza un destello (un `ColorRect` hijo con un shader aditivo de barrido); los demás botones no.
- **En la batalla**: barra de vida del jefe con "rastro" que baja más lento, borde rojo que late cuando queda poca vida, sacudida de cámara (`Camera2D.offset`, nunca mover el mundo) y el cartel del centro sobre una cinta oscura para que no se mezcle con los números de daño.
Reglas: todo con `set_ignore_time_scale(true)` y tiempos en segundos reales (`delta / Engine.time_scale`) si el juego acelera el reloj; todo respeta el interruptor de efectos; el suelo tiene que sobresalir de la pantalla lo que tiemble la cámara; `get_meta(clave, null)` da error si la clave no existe (usar `has_meta`). Probarlo con un clic real y comprobar que el botón vuelve a escala 1 y que tras cambiar rápido de pantalla solo se ve la última.
