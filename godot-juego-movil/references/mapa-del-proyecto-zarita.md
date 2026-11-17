# Mapa del proyecto Zarita (dónde está cada cosa)

Proyecto original: `D:\zarita-la zarigueya` (Godot 4.7, Mobile, 720×1280 vertical). Su `CLAUDE.md` completo está copiado en `references/claude-md-del-proyecto-zarita.md` (arquitectura y decisiones, actualizado con la grilla del piso y el minijuego del mate). Aquí, un índice rápido de los archivos copiados en `assets/zarita/`.

## Scripts (`assets/zarita/scripts/`)
| Archivo | Qué es | ¿Genérico? |
|---|---|---|
| `zarita.gd` | Personaje: movimiento 8 direcciones, animaciones, rebote, sombra, cola y parpadeo, lee el joystick | adaptar |
| `cola_zarita.gd` + `cola.gdshader` | Ondulación de la cola con shader, zonas por animación | patrón |
| `parpadeo_zarita.gd` | Capa de párpados que copia la animación | patrón |
| `casa.gd` | Orquestador: conecta HUD, tienda, luz, joystick; modo decorar; guardar/cargar | adaptar |
| `mueble.gd`, `mueble_data.gd` | Mueble arrastrable, huella, superficies, voltear; ficha `Resource` | **copiar** |
| `inventario.gd`, `inventario_ui.gd`, `slot_mueble.gd` | Inventario, panel con resplandor, casilla con gestos | **copiar** |
| `tienda.gd`, `item_tienda.gd` | Tienda por categorías, compra, anuncio | **copiar** |
| `economia.gd` | Dos monedas, `MODO_PRUEBAS`, guardado | **copiar** |
| `anuncios.gd` | Puerta única a la publicidad (simulada) | **copiar** |
| `musica.gd`, `reproductor_musica.gd` | Música con fundidos; mueble que la controla | **copiar** |
| `ciclo_dia.gd`, `clima.gd` | Día/noche y clima por tablas y valores 0-1 | **copiar** |
| `ventana.gd`, `luz_natural.gd`, `luz_habitacion.gd` | Cielo y clima en el cristal, luz del sol/luna, luz interior | adaptar |
| `sombra.gd` | Sombras dibujadas que reaccionan a las luces | **copiar** |
| `hud.gd`, `selector_clima.gd`, `ajustes.gd` | HUD por señales, botón de clima, panel de ajustes | adaptar |
| `joystick_virtual.gd` | Joystick táctil (`@tool`) | **copiar** |
| `scroll_deslizable.gd` | Scroll por arrastre con inercia | **copiar** |
| `inicio.gd` | Pantalla de título con fundido y botón que respira | adaptar |
| `habitacion_data.gd`, `habitaciones.gd`, `partida.gd` | Ficha de habitación, estado estático de la casa (actual, desbloqueadas) y guardado por habitación | **copiar** (ver `casa-con-habitaciones.md`) |
| `fundido.gd` | Fundido a negro al cambiar de escena | **copiar** |
| `mapa_casa.gd`, `tarjeta_habitacion.gd`, `vista_exterior.gd` | Mapa de la casa con desbloqueo con gemas y el exterior con clima | adaptar |
| `geometria_cuarto.gd`, `guia_cuarto.gd` | Esquina isométrica, grilla del piso (`a_grilla`) y guía `@tool` que se dibuja en el editor y muestra la grilla al decorar | **copiar** (ver `decorar-y-muebles.md`) |
| `mate.gd`, `pava_mate.gd` | Estado del mate (energía, yerba, agua) y la pava mueble que abre el minijuego | adaptar |
| `mate_juego.gd`, `cocina_mate.gd`, `pava_juego.gd`, `mate_taza.gd`, `bolsa_yerba.gd`, `barra_medidor.gd` | Minijuego del mate en una sola pantalla armada con escenas: pava arrastrable con perspectiva, bolsa que vierte, barras | patrón |
| `personaje_data.gd` | Ficha de personaje (Zarita, Don Jacinto, Teo) | adaptar |

## Escenas (`assets/zarita/escenas/`) y tema
`casa`, `zarita`, `mueble`, `mate_juego` (+ `cocina_mate`, `pava_juego`, `mate_taza`, `bolsa_yerba`, `barra_medidor`), `ventana`, `hud`, `ajustes`, `tienda`, `item_tienda`, `inventario_ui`, `slot`, `luz_habitacion`, `luz_natural`, `musica`, `reproductor_musica`, `inicio` (+ escenas heredadas antiguas `cama/silla/planta`). Sirven como **ejemplo del formato `.tscn`** (anclas, `theme_type_variation`, instancias, `script`, `groups`) para escribir escenas a mano. Tema en `assets/zarita/temas/zarita.tres`; fichas de ejemplo (incluidas `isla_cocina` y `refrigerador`, con `contra_pared`) en `assets/zarita/data/` (mesa con superficie, radio apoyable, lámpara con luz, ventana).

## Scripts de Python (`scripts/`)
| Script | Para qué | Uso |
|---|---|---|
| `quitar_verde.py` | Quita el fondo verde de una imagen | `entrada salida` |
| `cortar_hoja.py` | Corta una hoja en N columnas con fondo transparente | `entrada columnas carpeta prefijo` |
| `cortar_muebles.py` | Hoja de muebles → piezas con nombre (componentes conectados, umbral por pieza) | `entrada carpeta nombre1 nombre2 ...` |
| `procesar_ventanas.py` | Ventanas → marco, máscara de cristal y parche de luz | `entrada carpeta n1 n2 n3` |
| `armar_direccion.py`, `armar_conectadas.py` | Hoja de caminata → cuadros alineados | `entrada n_cuadros carpeta prefijo alto` |
| `izquierda_desde_derecha.py` | Crea la caminata izquierda espejando la derecha y centra la cabeza | `carpeta_der carpeta_izq` |
| `parpadeo.py` | Genera las capas de párpados cerrados (rutas fijas al proyecto: editar `BASE`) | — |
| `marcos_ui.py` | Dibuja los marcos de pixel art de la interfaz | editar rutas de salida |
| `gen_tema.py` | Genera `themes/zarita.tres` y la perilla | editar rutas |
| `pixelizar.py` | Imagen de IA → pixel art real | `entrada salida --tamano 64 --colores 16` |
| `dibujar_props_mate.py`, `componer_mate.py` | Props dibujados a mano y animación compuesta | ver encabezado |
| `armar_dataset_lora.py` | Dataset para entrenar un LoRA | ver encabezado |

Varios scripts tienen **rutas de Zarita escritas** (`D:/zarita-la zarigueya/...`): al reutilizarlos, leerlos y cambiarlas. Requieren `pip` de Pillow, numpy y scipy (ya instalados en la PC de Juan).

## Decisiones de diseño de Zarita (por si se quiere coherencia)
- Paleta cálida: marrón rosado `#7A4545` (contornos), crema `#FFF1DC`, durazno `#FAD9B0`, rosa `#F4A0AC`, azul grisáceo `#B0D0E2` para tuerca/voltear, amarillo `#FFD66B`.
- Vista cenital 3/4, cabaña de madera, personaje con pies como origen.
- Dos monedas (común y gemas por anuncio). Categorías de tienda: Sala, Dormitorio, Decoración, Baño, Cocina.
- Juego **relajante**: ciclo de día acelerado, clima automático, sin fallos ni tiempo límite.

## Pendientes conocidos de Zarita (ideas para el próximo juego también)
Audio de lluvia/trueno, fuente pixelada, joystick multitáctil, anuncios reales, prueba de rendimiento en el celular, exportar AAB.
