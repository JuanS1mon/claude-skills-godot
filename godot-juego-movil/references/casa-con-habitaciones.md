# Casa con varias habitaciones (mapa, desbloqueo con gemas)

Cómo Zarita pasó de una habitación a una casa. Sirve para cualquier juego de decorar con "cuartos" o "niveles" que comparten
dinero, inventario, música y clima. Código real en `assets/zarita/scripts/` y `assets/zarita/escenas/`.

## Idea central: UNA escena de habitación + una ficha por habitación
- `casa.tscn` no se copia por cuarto. Es **la** habitación: se reconfigura con una ficha `HabitacionData` (`Resource`):
  `nombre`, `suelo`, `tinte_suelo`, `color_mapa`, `orden`, `precio_gemas` (0 = viene abierta) e `inicio_zarita`.
- Las fichas viven en `data/habitaciones/*.tres`; el **nombre del archivo es el id** (`sala`, `cocina`...). Añadir una
  habitación = crear su `.tres`: el mapa y el guardado la leen solos.

## Cambiar de habitación = guardar, fundido, `reload_current_scene()`
```
_ir_a_habitacion(id):
    Habitaciones.actual = id
    _guardar()                       # el archivo es la única fuente de verdad
    await _fundido.salir()           # scenes/fundido.tscn (CanvasLayer 20, ColorRect negro)
    get_tree().reload_current_scene()
```
Al arrancar, `_ready` lee `Habitaciones.actual`, aplica el suelo, crea los muebles de ESA habitación y hace `_fundido.entrar()`.
Recargar la escena es lo más simple y barato en el celular (solo hay una habitación viva) y no deja nodos colgados.
`LuzNatural` se registra en `_ready` y se des-registra en `_exit_tree`; con `reload_current_scene` el viejo se libera ANTES de que
el nuevo haga `_ready`, así que no se pisan.

## Estado que sobrevive a la recarga SIN autoload: clase con `static var`
`Habitaciones` (`extends RefCounted`, `class_name`) guarda `actual`, `llegada_desde`, `desbloqueadas`, `con_reproductor` y el catálogo
como `static var`. No hace falta tocar `project.godot` ni reiniciar el editor. Lo que debe durar entre partidas se escribe con `Partida`.
Desde una función estática se puede llamar a un autoload (`Economia.pagar(...)`) porque se resuelve en ejecución.

## Guardado por habitación (`Partida`)
```
{ "version": 2, "inventario": [...], "economia": {...}, "musica": {...},
  "habitacion_actual": "sala", "desbloqueadas": ["sala","cocina"],
  "habitaciones": { "sala": {"muebles": [...], "luz": true, "reproductor": false}, ... } }
```
- `_guardar()` lee el archivo, **reemplaza solo la entrada de la habitación actual** y escribe de nuevo: lo de las otras queda intacto.
- `Partida.leer()` migra el formato viejo (lista `"muebles"` suelta → todo a la sala). Probado con un archivo antiguo.
- Se guarda antes de salir de la habitación y al desbloquear una (para no perder el pago de gemas).

## Qué es de toda la casa y qué de cada habitación
| De toda la casa (no hace falta hacer nada) | De cada habitación |
|---|---|
| Hora y clima: viven en el autoload `CicloDia`; llueve en todas las habitaciones porque son la misma escena recargada. Comprobado: `lluvia` sigue en 1.0 al cambiar. | Muebles, sus posiciones, ventanas |
| Inventario, monedas y gemas (autoloads) | Interruptor de luz (`"luz"` en su entrada) |
| Música: `Musica` es autoload; suena si hay un reproductor en CUALQUIER habitación (`con_reproductor` por id; se guarda como `"reproductor"`) | Suelo (la ficha) |

Las ventanas son muebles, así que el clima "se ve" donde pongas una ventana (el cristal ya lee `CicloDia.clima`).

## Viajar entre habitaciones: solo con el mapa
Se probaron puertas en la pared (un `Area2D` que cruzaba Zarita) y se quitaron: con el botón del mapa ya se llega a cualquier habitación, y las puertas competían con la interfaz de arriba (botones y pastillas tapaban la pared) y añadían escenas, datos (`puertas` en cada ficha) y un estado extra (`llegada_desde`). Lección: antes de añadir una segunda forma de hacer lo mismo, ver si la primera ya lo cubre. Si algún día se quiere caminar entre cuartos, es un `Area2D` por destino con `body_entered`, una espera al llegar para no volver a cruzar y apagarlas al decorar.

## Mapa de la casa (`mapa_casa.tscn`, `CanvasLayer` capa 10)
- Una tarjeta (`tarjeta_habitacion.tscn`, un `Button` con el tema) por ficha, en un `GridContainer` de 2 columnas, creadas por código
  desde `Habitaciones.catalogo()`. Tocar: la actual → cierra; abierta → `viajar(id)`; bloqueada → panel de confirmación
  → `Habitaciones.desbloquear(id)` (cobra gemas con `Economia.pagar`) → `desbloqueada(id)` para que la casa guarde.
- **El exterior con clima**: `VistaExterior` (un `Control`, no `@tool`) dibuja las 5 capas del cielo con `CicloDia.alfa_capa(i)`, sol y luna
  en arco, nubes, manto gris y partículas de lluvia/nieve/hojas/viento leyendo `CicloDia.clima`. Una segunda copia con
  `solo_clima = true` va delante del árbol para que la lluvia pase por encima. El decorado se tiñe con
  `CicloDia.color_en(tabla_ambiente) * clima.mult_ambiente()` (el `CanvasModulate` no afecta a un `CanvasLayer` distinto).
- Al cerrarlo: `visible = false`, `set_process(false)` y `process_mode = DISABLED` en la raíz, así la lluvia no gasta nada.
- Botón del mapa: escena propia (`boton_mapa.tscn`, anclado arriba a la izquierda) instanciada por código en el `CanvasLayer` del HUD:
  no hizo falta editar `hud.tscn` (que podía estar abierto en el editor).

## Trampas encontradas
- `reload_current_scene` solo funciona si la casa es la escena actual (F5 desde el inicio o F6 sobre la casa).
- Un `Label` o `Panel` sobre otro `Control` bloquea los clics: `mouse_filter = 2` en lo decorativo (las tarjetas lo llevan).
- Con `Habitaciones.actual == ""` (primer arranque) hay que leer la partida ANTES de elegir habitación (`cargar_datos`).
- Una habitación nueva sin arte: usar el suelo existente con `tinte_suelo` para distinguirla mientras tanto.

## Sistemas del "mundo" encima de la casa (lore -> datos)
- **Confort**: `MuebleData.confort` + `Habitaciones.confort_de(id, partida)` suma lo guardado en la habitación; el mapa lo muestra en cada tarjeta y el total en el título (la casa guarda ANTES de abrir el mapa).
- **Mate** (`mate.gd`): clase `RefCounted` con `static var` (energía, yerba, agua, mezcla) que se guarda en la partida. Funciones puras (`beber`, `actualizar`, `factor_velocidad`) fáciles de probar.
- **Fichas de contenido** (`BlendData`, `BichitoData`, `PersonajeData`): igual que `MuebleData`, un `.tres` por cosa en `data/<tipo>/`. `BichitoData.elegir(lista)` hace sorteo por peso.
- **Minijuego en otra escena** (`caza_bichitos.tscn`): se entra con `change_scene_to_file` tras guardar y fundido, y se vuelve igual (la casa lee `Habitaciones.actual`). Su raíz es un `CanvasLayer`: un `Control` suelto en el mundo se oscurece con el `CanvasModulate` de `CicloDia` (captura casi negra de noche). Se guarda con `Partida.guardar_progreso()` (monedas y mate) sin tocar las habitaciones. Tocar bichitos: `_input` con `InputEventMouseButton` (el toque llega como mouse) y elegir el más cercano dentro del radio.
- **Interfaz del mate** (`mate_hud.tscn`): una franja que lee el estado estático de `Mate` cada cuadro y solo emite señales; la casa decide (comprar yerba, calentar agua solo en la cocina). Ubicarla bajo la pared evita tapar la pared de arriba.
- **Amigos y misiones**: `Conversaciones.de(id)` devuelve datos (texto + opciones con `Callable`) y un diálogo genérico los muestra: agregar un personaje es agregar un `match` y una ficha. `Misiones` es estado estático con `registrar(tipo)` llamado desde donde ocurre el evento; EXPLORAR usa `habitacion_destino`.
- **Ropa y pava**: `Ropero` (estático) + `RopaZarita` (hija del personaje que dibuja con `_draw`); una pestaña extra de la tienda construida por código (filas con `set_meta`). La pava es un `Mueble` con `al_tocar()` como el reproductor de música.
- **Exterior (monte)**: otra escena con su propio joystick (Control con `joystick_virtual.gd` y `groups=["joystick"]`, que Zarita busca por grupo), la tinta del día viene gratis del `CanvasModulate` global y la lluvia se superpone con `VistaExterior(solo_clima)` en un `CanvasLayer`. Se vuelve a la casa con un botón. Los NPC son `Area2D` con `input_pickable` que emiten una señal; el diálogo es el mismo de siempre. Ojo con las rutas de nodos en `_ready`: un `$Ruta` mal escrito aborta el resto del `_ready` (pasó con el botón de volver).
