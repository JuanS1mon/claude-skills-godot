# Sistema de decorar: muebles, inventario, tienda

Código completo: `assets/zarita/scripts/mueble.gd` (≈530 líneas, comentado), `mueble_data.gd`, `casa.gd`, `inventario.gd`, `inventario_ui.gd`, `slot_mueble.gd`, `tienda.gd`, `item_tienda.gd`.

## El mueble base (`Mueble`, `Area2D`, `@tool`)
- Propiedades: `textura`, `color` (tinte), `tamano` (el sprite se escala a este tamaño sin importar la resolución del PNG), `huella`, `bloquea`, `solo_en_pared`, `superficie`, `apoyable`, luz (`emite_luz`...).
- **Origen = centro de la base** (como los pies). El `Sprite2D` y la colisión suben `tamano.y / 2`. Con `y_sort_enabled` en el padre, lo que está más abajo se dibuja delante: Zarita pasa "por detrás" de una silla sin código extra. Los objetos planos (alfombras, `en_el_suelo`) usan `z_index = -5` y el suelo `-10`.
- **Colisión por huella**: un `StaticBody2D` con un rectángulo del tamaño de la *base* (no del dibujo), creado por código (`huella` de la ficha, o 80 % del ancho y 25 % del alto con tope 20-60). Las alfombras no bloquean. **Mientras se decora, los muebles no bloquean** (`set_editable(true)`), y `casa.gd` mueve al personaje al hueco libre más cercano (`_destrabar_zarita`, probando `test_move` en círculos) al volver a jugar.
- **Arrastrar**: `Area2D._input_event` detecta el clic; `_input` mueve con `get_global_mouse_position() + _desfase` y al soltar ajusta a grilla (`snapped`) y emite `soltado`. Un mueble recién sacado del inventario nace "agarrado" (`empezar_arrastre`).
- **Varios solapados**: todos los `Area2D` bajo el dedo reciben el clic; se juntan en `static var _candidatos` y `_elegir_agarre` (con `call_deferred`) agarra uno solo: primero el apoyado, luego el de base más abajo.

## Que toquen el suelo
`_ajustar_al_suelo` limita la base entre la pared de arriba (`Y_SUELO_MIN` = borde inferior de la colisión de la pared) y la de abajo, y entre los costados. Para arriba cuenta la *huella*, no el dibujo (un mueble alto puede subir por la pared, como en la vida real). Una alfombra va entera sobre el piso (su alto completo). Las ventanas (`solo_en_pared`) usan `_ajustar_a_pared`: Y fija, solo se deslizan de lado y se separan entre sí.

## Apoyar objetos sobre muebles (mesas, cómodas...)
- Ficha del soporte: `superficie = Rect2(x, y, ancho, alto)` = zona donde puede quedar la **base** del objeto, en px desde el origen del mueble (Y negativo = arriba). Ficha del objeto: `apoyable = true`. Para ubicar el rectángulo se hizo una hoja de contacto con Pillow (mueble a escala con regla en Y) y se probó con una radio y una planta encima.
- Al soltar sobre una superficie: `_apoyar_en` hace `reparent(soporte)` → el objeto viaja con la mesa, se dibuja encima, no bloquea (`_actualizar_bloqueo`) y oculta sus sombras de suelo. Al agarrarlo vuelve a ser hijo de la casa.
- **Ayudas al gesto** (lo que quitó lo "tosco"): imán (`RADIO_IMAN` px hasta la superficie más cercana), el objeto **se desliza** hacia el punto con `exp` en `_process` (`VELOCIDAD_DESLIZ`), se pega al **centro** (`IMAN_CENTRO`), las superficies se marcan con una elipse que se resalta en la elegida (`fijar_guia`), `z_index` alto mientras se arrastra y un **saltito** (squash con `Tween` TRANS_BACK) al quedar.
- Guardado: `"sobre": índice` + posición local. Si se devuelve la mesa al inventario, lo de encima vuelve también. Los muebles apoyados no cuentan para la luz de la ventana (`apoyado_en != null`).

## Voltear
Al tocar o soltar un mueble en modo decorar aparece 3 s un botón con dos flechas encima (si no cabe arriba, debajo). Alterna `volteado` → `Sprite2D.flip_h`; emite `cambio_aspecto` (la casa guarda). Se crea por código la primera vez, con el `Theme` cargado con `load`. No para ventanas.

## Devolver al inventario
Soltar sobre el panel del inventario (rect global vs. posición del mouse en el viewport) → `queue_free` + `Inventario.agregar`. Mientras se arrastra encima, `Mueble.arrastrando` avisa a la casa: el panel muestra un **resplandor dorado que late** y el mueble se vuelve algo transparente (`resaltar(true)`). Es el tipo de **retroalimentación** que hace que un arrastre se sienta claro.

## Inventario
- `Inventario` (autoload): arreglo de fichas, `cambio`. Tiene fichas iniciales provisionales para una partida nueva.
- `inventario_ui.tscn`: panel inferior con `ScrollContainer` horizontal (script `scroll_deslizable.gd`) y una `SlotMueble` por ficha. Solo visible en modo decorar.
- **Gesto de la casilla**: deslizar de lado = mover la lista; arrastrar hacia arriba (>12 px) o mantener 0,35 s = sacar el mueble. Un toque suelto no hace nada (evita sacar uno sin querer al deslizar).

## Tienda
- `tienda.tscn`: panel con pestañas por categoría (botones creados por código con `theme_type_variation = &"Pestana"` y un `ButtonGroup`), lista vertical con `scroll_deslizable`, aviso, botón de anuncio y cerrar.
- Comprar = `Economia.pagar()` + `Inventario.agregar()`; el botón se desactiva si no alcanza (`Economia.cambio`).
- Dos monedas: **común** (se gana jugando) y **gemas** (se ganan viendo un anuncio, hoy simulado con `Anuncios`).

## Ventanas como muebles
`ventana.tscn` es un `Mueble` con `solo_en_pared` y un hijo `Visual` (script `Ventana`). Tres diseños × dos tamaños (grande y 65 %) = seis fichas. Cada diseño necesita en `assets/ventanas/`: `<d>_marco.png`, `<d>_cristal.png` (máscara) y `<d>_parche.png` (forma de la mancha de luz). El script `scripts/procesar_ventanas.py` genera esas tres a partir de una hoja de IA. Ver `luz-dia-clima.md`.

## Lámparas y luces
Ficha con `emite_luz`: crea un `PointLight2D` con textura radial (`CicloDia.textura_radial()`): alumbra poco de día y mucho de noche (`oscuridad()`); un clic fuera del modo decorar la apaga o enciende (`encendida`, se guarda). Las sombras de los demás objetos reaccionan a las lámparas (grupo `lamparas`).

## Receta para otro juego con decoración
1. Copiar `mueble.gd`, `mueble_data.gd`, `inventario*.gd`, `slot_mueble.gd`, `scroll_deslizable.gd`, `tienda.gd`, `item_tienda.gd`, `economia.gd`, `casa.gd` (y sus escenas).
2. Cambiar las constantes del suelo (`Y_SUELO_MIN`, `Y_SUELO_MAX`, `X_MIN_PARED`...) a las de la nueva habitación.
3. Hacer las primeras 5 fichas con arte de placeholder (`textura` vacía + `color`), comprobar el flujo comprar → inventario → colocar → guardar, y **recién entonces** generar arte (`arte-con-ia.md`).

## Vender y ordenar el inventario
- **Vender**: al arrastrar un mueble (colocado o recién sacado del inventario) aparece una **franja arriba** (`zona_venta`) que se ilumina cuando el mueble está encima; al soltarlo ahí, el mueble se esconde y una **ventana de confirmación** (`confirmar_venta`) pregunta "Vender" (paga la mitad del precio, `MuebleData.precio_venta()`) o "Guardar" (al inventario). Cancelar nunca pierde el mueble. Lo que tenía encima (objetos apoyados) vuelve al inventario.
- **Inventario más manejable**: los muebles iguales se **agrupan en una casilla con cantidad** ("Silla  ×3") en vez de crecer la lista; sacar una casilla saca una unidad.
- Patrón general: una acción destructiva o irreversible lleva siempre una salida segura (aquí, "Guardar").

## Habitación en esquina isométrica (en vez de rectángulo de frente)
Si el arte de los muebles es 3/4 diagonal, una pared recta de frente lo contradice (la biblioteca parece torcida). Solución probada: **esquina vista desde adentro**, con el vértice arriba en el centro y las dos paredes bajando en diagonal (pendiente ~0,54): el piso ocupa todo lo de abajo hasta los bordes, así el espacio de juego casi no se reduce (un rombo cerrado lo achicaría 5 veces). Toda la geometría en UNA clase (`geometria_cuarto.gd`: `y_borde(x)`, `ajustar_base(pos, mitad, fondo)` que usa la esquina trasera más lejana del centro, `poligono_paredes(subir)` para un `CollisionPolygon2D`); la caja de colisión del personaje tiene su alto, así que el polígono se sube ~24 px para que los pies rocen la pared. Si la imagen generada deja demasiada pared, **cortar una banda de pared lisa y estirar el piso abajo** repitiendo filas con la traslación vertical que alinea las tablas (buscarla minimizando la diferencia). Ver `assets/zarita/scripts/geometria_cuarto.gd`.

**Ventanas en paredes inclinadas sin arte nuevo**: aplicar al cuerpo de la ventana (marco, cristal con `clip_children` y cielo) una **cizalla**: `Transform2D(Vector2(e, e*k), Vector2(0, e), Vector2.ZERO)` con `k = ±PENDIENTE` (negativa en la pared izquierda, positiva en la derecha); las verticales no cambian y la máscara de cristal sigue funcionando. Se coloca en `y_borde(x) - ALTURA_VENTANA`. Los astros (que viajaban por una trayectoria global) se trasladan a la altura de cada ventana. **Un `class_name` nuevo hace fallar el parseo ("Parse error") en un editor ya abierto hasta que reescanea: usar `const X = preload("res://...")` para las clases nuevas.**

**Que los límites se vean y se ajusten en el editor**: la geometría (esquina, pendiente) no va como constantes sueltas: un nodo `@tool` (`guia_cuarto.gd`) con `@export` y `_draw()` dibuja la línea del piso y la zona de colisión sobre el fondo en el editor (y opcionalmente al jugar), y al arrancar vuelca sus valores en la clase estática de geometría. Además, el `.tscn` de la escena debe tener el fondo NUEVO asignado (si se cambia por código al jugar, en el editor se sigue viendo el viejo).

## Grilla, contra la pared y sombras
La colocación en grilla, la pendiente del arte, lo guardado frente a lo nuevo y las sombras de contacto están explicados en general en `references/colocar-objetos-en-grilla.md` (sirve igual para torres en un terreno). Lo propio de la casa: marcar `contra_pared` en la ficha de cocinas, heladeras y mesadas para quitarles la sombra (contra la pared una sombra de contacto las hace parecer flotando), y `acomodar_al_suelo()` al cargar para los muebles guardados con una geometría anterior.
