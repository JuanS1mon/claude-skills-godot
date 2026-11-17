# Estructura del proyecto: escenas, datos, autoloads, guardado

## Carpetas
```
assets/        arte (por tema: muebles/<categoría>, zarita, ventanas, cielos, fondos, inicio, ui, musica)
scenes/        .tscn (una por cosa: zarita, casa, mueble, hud, tienda, ajustes...)
scripts/       .gd (un script por escena/sistema)
data/muebles/  fichas .tres (una por mueble)
themes/        zarita.tres (el Theme de la interfaz)
shaders/       .gdshader
tools/         scripts de Python del proyecto (arte); excluir del APK
```
Convención: nombres en español, `snake_case` en archivos, `PascalCase` en nodos y clases.

## Cuándo es escena y cuándo es código
- **Escena (`.tscn`)**: todo lo que se ve y se ajusta a ojo: HUD, botones, paneles, joystick, ventanas, el mueble base, el personaje.
- **Escena heredada** (herencia de escenas): cuando hay variantes con el mismo comportamiento (`cama`, `silla`, `planta` heredan de `mueble.tscn`). Después se pasó a **ficha + una sola escena**, porque la mayoría solo cambia datos.
- **Código**: lo que depende de datos en ejecución (la colisión con la huella de la ficha, las sombras, el botón de voltear, las pestañas de la tienda por categoría, partículas de clima con parámetros).
- **Regla práctica**: si Juan querría moverlo con el mouse en el editor, que sea nodo.
- **Nada de `_draw()` para lo que debe verse en el editor** (pasó con `Bichito`: se dibujaba por código y la escena se veía vacía). Los placeholders son **nodos visibles** (`Polygon2D` círculos, `ColorRect`) para ver la escena sin arte; el script solo los tiñe con la ficha y los anima. Se deja un nodo **`Imagen` vacío del tipo final**: si el arte va a ser animado, un **`AnimatedSprite2D`** (no `Sprite2D`). El script muestra el placeholder mientras `imagen.sprite_frames == null` y, al asignarle `SpriteFrames`, esconde las formas y hace `play()`. Ejemplo: `assets/zarita/escenas/bichito.tscn` + `scripts/bichito.gd`.
- **Cada escena corre sola con F6 (regla para todos los juegos).** Checklist: (1) placeholders visibles; (2) animación visible: `sprite_frames` por defecto + `autoplay` en el `AnimatedSprite2D` (o `AnimationPlayer` con autoplay); (3) lo que inyecta el padre es opcional: el `iniciar(ficha, ...)` solo *sobrescribe*, y `_process` con `ficha == null` anima la vitrina (colores por defecto, pulso) y sale sin tocar nada de la ficha; (4) sin `@onready` a nodos que no sean hijos de la propia escena; (5) probar con un script headless que carga la escena suelta y comprueba que no hay errores. Si el **origen es la base** del objeto (el sprite sube desde ahí), al correr suelta queda fuera de pantalla: en `_ready`, `if get_parent() == get_tree().root:` centrarlo en el viewport (ver `Mueble._ready`). **Las animaciones simples van en un `AnimationPlayer` de la escena, no en tweens de código** (así se ven y se editan en el editor y el script queda en 2 líneas): ejemplo `fundido.tscn` (velo negro visible, animaciones "entrar"/"salir" que también cambian `mouse_filter`, autoplay "entrar"; el script solo hace `play` y `await animation_finished`). **Arte armado por código no se ve en el editor** (el script lo crea en `_ready`): en cada escena heredada, sobrescribir el nodo `Sprite` con el `SpriteFrames` de la imagen, `scale`, `offset` y esconder la figura provisional (ver `homero.tscn`), en vez de hacer el script `@tool` (un `@tool` que modifica nodos guarda esos cambios en la escena). Un `Resource` sin ficha asignada no debe romper nada: usa constantes por defecto (`COLOR_POR_DEFECTO`). Decidir de antemano si el arte es estático o animado, para dejar el nodo correcto.

## Fichas de datos (`Resource`)
`MuebleData` (`class_name`, `extends Resource`) con `@export`: `nombre`, `escena` (PackedScene), `textura`, `icono`, `color`, `tamano`, `huella`, `bloquea`, `en_el_suelo`, `solo_en_pared`, `variante`, `emite_luz` + parámetros de luz, `superficie` (Rect2), `apoyable`, `precio`, `moneda`, `categoria` (enum), y `crear_mueble()` que instancia la escena y le copia los datos.
- Un `.tres` por ficha en `data/muebles/`. **Añadir contenido = crear un archivo**; no se toca código.
- La **tienda** lee la carpeta con `ResourceLoader.list_directory`, ordena por moneda y precio, y crea una pestaña por categoría (el enum `Categoria` + una lista de nombres).
- Formato mínimo de un `.tres` (ver `assets/zarita/data/`):
```
[gd_resource type="Resource" script_class="MuebleData" format=3]
[ext_resource type="Script" path="res://scripts/mueble_data.gd" id="1_data"]
[ext_resource type="PackedScene" path="res://scenes/mueble.tscn" id="2_escena"]
[ext_resource type="Texture2D" path="res://assets/muebles/mesas/mesa_redonda.png" id="3_textura"]
[resource]
script = ExtResource("1_data")
nombre = "Mesa redonda"
escena = ExtResource("2_escena")
textura = ExtResource("3_textura")
tamano = Vector2(105, 100)
precio = 90
categoria = 0
superficie = Rect2(-35, -84, 70, 26)
```
Para agregar una propiedad a las 50 fichas basta una pasada de Python que añada la línea al final (`[resource]` es la última sección).

## Autoloads (estado global con señales)
| Autoload | Qué lleva | Señal |
|---|---|---|
| `Inventario` | lista de fichas que el jugador posee y no están colocadas; `agregar`, `quitar`, `rutas()`/`cargar_rutas()` | `cambio` |
| `Economia` | `monedas`, `gemas`; `pagar`, `ganar`, `puede_pagar`; `MODO_PRUEBAS` | `cambio` |
| `CicloDia` | hora acelerada, tablas de color/luz, `CanvasModulate`, y `clima` dentro | — |
| `Musica` | pistas, estado (0 apagado, 1..n), fundidos; descubre canciones de `assets/musica/` | `cambio` |
| `Anuncios` | única puerta a la publicidad (hoy simulada); `await Anuncios.mostrar_recompensa()` | `recompensa_terminada` |

Patrón: **los consumidores se conectan a `cambio` y se redibujan** (HUD, inventario, botón Comprar). El estado nunca se pregunta por polling.
- `Economia.MODO_PRUEBAS = true` fuerza un saldo alto para probar muebles; **ponerlo en `false` antes de publicar**.
- `Anuncios` encapsula el plugin: cuando se integre AdMob solo cambia `_mostrar_anuncio_real()`. Usar los IDs de prueba de Google; nunca tocar un anuncio real propio.

## Grupos y señales: cuándo cada uno
- **Grupos** para difundir órdenes a muchos nodos: `get_tree().call_group("muebles", "set_editable", activo)`, `"lamparas"`, `"ventanas"`, `"reproductores"`, `"hud"`, `"joystick"`. Los nombres distinguen mayúsculas. Poner el grupo en el `.tscn` (no por código) si el nodo es `@tool`.
- **Señales** para avisar hacia arriba: `soltado`, `luz_alternada`, `cambio_aspecto`, `arrastrando`, `cerrada`. El hijo no conoce al padre.
- **Orquestador** (`casa.gd`): conecta las señales del HUD y de los muebles, guarda y carga, crea la tienda. Es el único script que "sabe de todos".

## HUD como escena
`hud.tscn` contiene botones, pastillas de saldo, joystick, aviso y la instancia de ajustes. `hud.gd` solo **reemite** los toques como señales (`decorar_alternado`, `tienda_alternada`, `luz_alternada`) y expone `avisar(texto)` y `desmarcar_tienda()`. La tienda es un panel con `mostrar(activa)` y señal `cerrada`. Detalles en `interfaz-movil.md`.

## Guardado
- `user://partida.json` con `JSON.stringify`. Contiene: rutas del inventario, lista de muebles colocados (`ficha` = ruta, `x`, `y`, `encendida`, `volteado`, `sobre` = índice del soporte), `economia`, `musica`.
- Se guarda al soltar un mueble, al salir del modo decorar, al cambiar la música y en `NOTIFICATION_WM_CLOSE_REQUEST` / `NOTIFICATION_APPLICATION_PAUSED` (cuando el celular pone la app en segundo plano).
- **Referencias entre objetos** (un objeto sobre una mesa): se guardan como **índice en la lista**; al cargar se crean todos primero y después se asignan los padres.
- Los ajustes del jugador (volumen, lado del joystick) van en `user://ajustes.cfg` (`ConfigFile`), **separado de la partida**.
- Al cargar, tolerar fichas que ya no existen (`ResourceLoader.exists`) y claves nuevas ausentes (`dict.get("clave", valor_por_defecto)`).

## Música
- Autoload `Musica`: un `AudioStreamPlayer` con fundido de entrada/salida por `Tween`, repite al terminar (`finished`). Añadir una canción = copiar el MP3 a `assets/musica/`.
- El volumen del jugador se aplica en el bus **Master** (`AudioServer.set_bus_volume_db`, `set_bus_mute`), sin tocar los fundidos.
- Los muebles reproductores (radio, caja musical) piden `Musica.siguiente_estado()`; la casa avisa con `fijar_permitido` si hay alguno puesto.
- Para **generar pistas** con IA local ver el skill `musica-ace-step`.

**Cualquier contenido repetible (muebles, ropa...) = ficha `Resource` + escena base con placeholders visibles**: la ficha trae `escena`, color, posición, escala y `textura`/`frames` opcionales, y un `crear_x()` que instancia la escena y le pone la ficha ANTES de añadirla; la escena aplica la ficha en `_ready` (colorea nodos por grupo, esconde las formas si hay imagen, `play()` si hay animación) y corre sola con valores por defecto. Ejemplo: `prenda_data.gd` + `prenda.gd` + `prenda.tscn` (+ variantes heredadas con otras formas). Añadir contenido nuevo = un `.tres`.
