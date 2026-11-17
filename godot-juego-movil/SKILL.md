---
name: godot-juego-movil
description: Guía y código reutilizable para hacer juegos 2D en Godot 4 (GDScript), sobre todo móviles, aprendida construyendo "Zarita la zarigüeya" con Juan y pensada para crecer con cada juego: cómo trabajamos (aprendizaje paso a paso, escenas en el editor, datos en Resource, pruebas con capturas), organización de escenas, autoloads y guardado; colocar objetos sobre un terreno con grilla (muebles, torres de un tower defense, cultivos), arrastrar, inventario, tienda, economía y anuncios; ciclo día/noche, clima, luces y sombras; interfaz táctil (joystick, HUD, botones con icono, tema de pixel art, listas que se deslizan); minijuegos de una pantalla; errores típicos de Godot; arte con IA sobre fondo verde; y exportar el APK o probar en el celular. Usar siempre que se trabaje en un juego Godot 2D o se quiera llevar uno a Android, aunque no se nombre el skill. No es para juegos 3D, Unity, Unreal, Phaser ni apps que no sean Godot.
---

# Juegos 2D en Godot 4: lo aprendido, para cualquier tipo de juego

Este skill junta lo que Juan y Claude van descubriendo juego a juego; el primero fue *Zarita la zarigüeya* (relajante, vertical 720x1280, Godot 4.7, renderer Mobile). **No es solo para decorar casas**: la forma de trabajar y los sistemas (grilla de colocación, datos en `Resource`, interfaz táctil, pruebas con capturas, minijuegos) valen para un tower defense, una granja, una aventura... Zarita es el ejemplo con código real. Cada vez que algo nuevo funcione (o falle), **se anota acá** en la referencia que corresponda; si no existe, se crea una general, sin nombres del juego de turno.

Todo el código fuente real de Zarita está copiado en `assets/zarita/` (scripts, escenas, tema, fichas de ejemplo). Se copia y adapta; no hace falta reescribirlo desde cero.

## Cómo usar este skill

1. **Lee primero** `references/forma-de-trabajo.md` (cómo se trabaja con Juan: aprendizaje paso a paso, en español, él arma las escenas) y `references/trampas-godot.md` (los errores que ya nos costaron horas). Son cortos y evitan repetirlos.
2. Según la tarea, abre **solo** la referencia que corresponda:

| Si la tarea es... | Lee |
|---|---|
| Estructurar el proyecto, escenas, datos, autoloads, guardado | `references/escenas-y-datos.md` |
| **Colocar objetos sobre un terreno con grilla** (muebles, torres, cultivos): grilla isométrica o cuadrada, validar casillas, sombras, guardado | `references/colocar-objetos-en-grilla.md` |
| Arrastrar y soltar, inventario, tienda, economía, anuncios (versión casa con muebles: esquina isométrica, apoyar sobre mesas) | `references/decorar-y-muebles.md` |
| Varias habitaciones: mapa de la casa, desbloqueo con gemas, guardado por habitación, clima y música compartidos | `references/casa-con-habitaciones.md` |
| Probar el juego desde Claude Code (Godot sin pantalla, capturas, autoload de prueba, probar con la partida real del usuario) | `references/probar-en-godot-desde-claude.md` |
| Día/noche, clima, lluvia, relámpagos, ventanas, luces, sombras | `references/luz-dia-clima.md` |
| HUD, botones, joystick, tema, listas con scroll, ajustes, gestos | `references/interfaz-movil.md` |
| Generar o procesar arte con IA (muebles, iconos, personaje, logo, fondos) | `references/arte-con-ia.md` |
| Animar un personaje (caminata, parpadeo, cola) | `references/arte-con-ia.md` (sección personaje) |
| **Juego idle / olas / auto-batalla / gacha**: enemigos con probabilidades por ola, XP de la partida, economía de cristales, misiones diarias, anuncios con tope, mejoras permanentes, balance con simulador | `references/idle-gacha-economia-y-balance.md` |
| **Animar sprites con ComfyUI local** (caminata desde un solo sprite, fondos animados, LoRA de estilo) | `references/sprites-con-comfyui.md` |
| **Guardado en la nube** (Play Games Saved Games): sincronizar la partida local, celular nuevo, jugar en dos celulares, conflictos, "Nueva partida"; ¿conviene Level Up?; probarlo en la PC con una nube simulada (código en `assets/nube/`) | `references/guardado-en-la-nube.md` |
| Probar en el celular o exportar el APK | `references/android.md` |
| Música de fondo | el skill `musica-ace-step` y la sección de música en `references/escenas-y-datos.md` |
| Saber qué archivo de Zarita contiene qué | `references/mapa-del-proyecto-zarita.md` |

3. **Para reutilizar código**, mira `assets/zarita/scripts/` (los `.gd`), `assets/zarita/escenas/` (los `.tscn`, útiles como ejemplo del formato), `assets/zarita/temas/zarita.tres` y los scripts de Python de `scripts/`. Antes de copiar un script, léelo: están comentados en español y dicen de qué otros nodos dependen.

## Los principios que más rindieron

- **REGLA DE ORO: toda escena funciona sola (F6) y se ve.** Cada `.tscn` debe poder ejecutarse individualmente sin errores y mostrar su aspecto: con **placeholders visibles hechos de nodos** (`Polygon2D`, `ColorRect`, `Label`; nunca solo `_draw()` o nodos vacíos), y si la escena tiene animación, **se tiene que ver moviéndose** (`SpriteFrames` por defecto asignado en la escena + `autoplay`, o una animación/tween/pulso que arranque sola). Los datos que normalmente inyecta quien la instancia (ficha, límites, jugador) son **opcionales**: sin ellos el script usa valores por defecto y no falla (`if ficha == null:` → comportamiento de vitrina, sin vagar ni borrarse). Las fichas que traen su propio arte/animación lo **sobrescriben**; si no lo traen, queda el de la escena. Receta completa y ejemplo (`bichito`) en `references/escenas-y-datos.md`. Comprobarlo siempre: cargar la escena suelta en Godot `--headless` con un script de prueba y confirmar que no hay errores y que la animación está en `is_playing()`.
- **Escenas en el editor, lógica en scripts.** Lo que el diseñador debería ver y ajustar (botones, paneles, iconos, joystick, manchas de luz) va como nodos en un `.tscn`; el script solo pone la lógica. Lo que depende de datos (tamaño de colisión según la ficha) se crea por código. Así Juan ve el juego en el editor y aprende la herramienta.
- **Datos en `Resource`, no en código.** Cada mueble es un archivo `.tres` (ficha). Añadir contenido = crear una ficha. La tienda lee la carpeta sola.
- **El HUD solo emite señales; una escena "orquestadora" conecta.** Así los botones se rediseñan sin tocar el juego.
- **Origen de cada objeto = su base** (los pies). Con `y_sort_enabled` el orden de dibujo sale gratis.
- **Un tema (`Theme`) para toda la interfaz**, con marcos de pixel art de 9 trozos, en vez de estilos sueltos por botón.
- **Una sola regla de colocación (grilla) en vez de muchos parches de alineación**, y medir la pendiente del arte (2:1) antes de programar encima de la de la pared. Detalle en `references/colocar-objetos-en-grilla.md`.
- **Probar con capturas y con la partida real del usuario**: los fallos visuales (muebles flotando, huecos, sombras) no los ve un test numérico.
- **Probar el arte antes de integrarlo**: componer una vista previa con Pillow sobre el fondo real y mirarla (`Read` sobre la imagen). Ahorra muchas idas y vueltas con el usuario.
- **Que sea INTUITIVO para el usuario** (filosofía de los proyectos de Juan): nada de tutoriales guiados ni pantallas de explicación; la interfaz se entiende sola. Gestos naturales (deslizar arriba acerca el mapa, abajo lo aleja), iconos y botones con su nombre, **una pista corta y en contexto** donde hace falta (una pastilla "Desliza hacia arriba para acercar") y un primer nivel/mundo más fácil que sirva de entrenamiento sin decirle nada. Si algo necesita un párrafo para entenderse, se rediseña. Detalle en `references/interfaz-movil.md`.
- **Decidir con valores por defecto razonables y mostrar el resultado**, en vez de preguntar todo antes. Preguntar solo lo que cambia el rumbo (estilo del arte, disposición de botones).
- **Todo lo que se aprende se anota en `CLAUDE.md` del proyecto** (arquitectura, decisiones, trampas). Es la memoria del proyecto.

## Probar desde aquí (sí se puede, con límites)

Claude Code **sí puede ejecutar Godot** en la PC de Juan: sobre una copia del proyecto, sin ventana (`--headless`) o con ventana para sacar capturas, y con un autoload de prueba que recorre el flujo. Receta completa y trampas en `references/probar-en-godot-desde-claude.md`. Lo que no se puede comprobar así es el toque real en el celular, el rendimiento y el audio: pídele a Juan que lo pruebe y pegue **el primer error del Depurador** si algo falla. Dilo claro en cada entrega: qué se probó y cómo, y una lista corta de qué probar a mano. Nunca tocar `.tscn` abiertos en el editor de Juan: crear archivos nuevos o hacerlo en la copia.

## Atajos de arranque para un juego nuevo

1. Proyecto Godot 4.x con renderer **Mobile**, ventana 720x1280, orientación vertical, stretch `canvas_items` + `expand`, y `rendering/textures/vram_compression/import_etc2_astc = true` (necesario para Android).
2. Autoloads según el juego: `Economia` (monedas/gemas), `Inventario`, `CicloDia` (con el clima dentro), `Musica`, `Anuncios`.
3. Escenas por capas: `inicio.tscn` (pantalla de título), `casa.tscn` (mundo) con un `CanvasLayer` que instancia `hud.tscn`.
4. Copiar de `assets/zarita/scripts/` lo que haga falta y crear el `CLAUDE.md` del proyecto con las reglas de `references/forma-de-trabajo.md`.
