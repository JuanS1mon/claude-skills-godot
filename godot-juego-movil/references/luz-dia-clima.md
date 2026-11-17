# Día/noche, clima, ventanas, luces y sombras

Código: `assets/zarita/scripts/ciclo_dia.gd`, `clima.gd`, `ventana.gd`, `luz_natural.gd`, `luz_habitacion.gd`, `sombra.gd`, `selector_clima.gd`. Los dos primeros son **genéricos y se pueden copiar tal cual** a otro juego; los demás dependen del sistema de muebles/ventanas.

## Idea central
Todo el aspecto del tiempo sale de **tablas `[hora, valor]` que se interpolan** y de **valores de 0 a 1 que se acercan a un objetivo**. Nada está "programado a mano" hora por hora: para cambiar el atardecer se edita una fila de la tabla.

## `CicloDia` (autoload)
- `hora` de 0 a 24 que avanza acelerada (`SEGUNDOS_POR_DIA`, p. ej. 240 s = un día; "ciclo acelerado" para ver todo rápido). Arranca con la **hora real** del dispositivo.
- **Tablas** (arreglos de `[hora, valor]`, empiezan en 0 y terminan en 24): `tabla_ambiente` (color), `tabla_luz_sol` (color), `tabla_energia_sol`, `tabla_energia_luna`, `tabla_oscuridad` (0 día, 1 noche), `tabla_capas` (opacidad de cada capa de cielo).
- `valor_en(tabla)` y `color_en(tabla)` interpolan linealmente entre filas (`_tramo`, `_fraccion`).
- Un `CanvasModulate` (hijo del autoload) **tiñe el mundo** con el color ambiente × el del clima. La interfaz queda sin teñir porque va en `CanvasLayer`.
- `oscuridad()` = máximo entre la tabla y la oscuridad que añaden las nubes: así las lámparas se encienden también en un día gris.
- `textura_radial()`: `GradientTexture2D` radial reutilizable para lámparas, luz de habitación y relámpago.
- Para añadir otra variable del día (p. ej. niebla): nueva tabla + `valor_en`.

### Cielo por capas
Cuatro imágenes de cielo (noche, amanecer, día, atardecer) apiladas con la noche dos veces para cerrar el ciclo; `tabla_capas` da la opacidad de cada una por hora (con saltos `9.0 → 9.01` para que una capa se apague cuando la siguiente ya la cubre por completo). Sol y luna son **uno solo para toda la casa** (`posicion_astro(t, altura)`, un arco en coordenadas de la pared) y cada ventana los muestra solo si pasan por su cristal.

## `Clima` (hijo de `CicloDia`, `CicloDia.clima`)
- Tipos: despejado, nublado, lluvia, calor, otoño, nieve, viento. Cada uno es un **diccionario de objetivos** (`{"nubes": 1.0, "lluvia": 1.0, "viento": 0.25}`); los valores `nubes, lluvia, nieve, hojas, viento, calor` se acercan con `move_toward` (`VELOCIDAD_CAMBIO`), así los cambios son graduales.
- **Automático** (`SEGUNDOS_POR_CLIMA`, elección por pesos, nunca el mismo dos veces) o **fijo** con `ciclar()` (el botón Clima recorre: auto → cada clima).
- Sale de `Clima`: `mult_ambiente()` (tinte de toda la casa: gris con nubes, azulado con nieve, cálido con calor), `factor_sol()`, `tinte_cielo()`, `oscuridad_extra()`, `relampago` (0-1), `hay_ventanas` (sin ventanas el relámpago no entra).
- **Relámpagos** (solo con lluvia, cada 5-13 s): un `Tween` de `relampago` = 1.0 → 0.15 → 0.75 → 0 (dos destellos y un apagado largo). Ese número alimenta: (a) una `PointLight2D` enorme (`RADIO_RELAMPAGO`, energía `relampago * 2.6`), (b) el color ambiente (`lerp` hacia azul blanquecino), (c) el destello blanco dentro del cristal de cada ventana, (d) las sombras (una luz breve y dura). **Lo que importa es que un solo valor mueva todo.**
- Ajustes de color (nublado "más nubes, más oscuro y gris", etc.) están en los `lerp` de `mult_ambiente`/`tinte_cielo`: subir el coeficiente para más efecto.

## Ventanas (`ventana.gd`)
- El cristal es una **máscara**: el nodo `Cristal` (Sprite2D con la forma del vidrio) tiene `clip_children` y contiene el cielo, el sol, la luna, las nubes, las partículas y el destello, así **solo se ven por el vidrio**.
- Capas del cielo = `Sprite2D` hijos con `modulate.a = CicloDia.alfa_capa(i)` y color de `clima.tinte_cielo()`.
- Nubes: un manto gris (`ColorRect`, opacidad ∝ nubes) y 16 sprites de nubes generadas **por código** (círculos con base plana, claras arriba y oscuras abajo), en dos capas (grandes y lentas / chicas y rápidas); el viento las acelera; con lluvia se oscurecen.
- Partículas (`CPUParticles2D` creadas por `_crear_emisor`): lluvia (rayas 2×12, rápidas), nieve (copos 4×4 lentos), hojas (8×5 con `color_initial_ramp` naranja/rojo/amarillo y giro), viento (rayas horizontales). `preprocess = lifetime` para que ya estén "llenas" al empezar; `local_coords = true`. `_actualizar_emisor` las enciende (`emitting`) con el valor del clima, ajusta su opacidad y **inclina la dirección con el viento**.
- Mancha de luz en el suelo: dos `PointLight2D` (sol y luna) con la imagen `<diseño>_parche.png`, inclinadas y alargadas según la posición del astro (`_actualizar_mancha`); **cada luz carga su propia copia de la textura**.
- Un mueble alto pegado a la pared tapa parte de la luz de la ventana (`_tapado_por_muebles`).
- Se puede **ejecutar la escena sola (F6)** y simular: ← → cambian la hora, Enter pausa, ↑ cambia el clima, ↓ lanza un relámpago. Muy útil para ajustar a ojo. En el editor muestra un mediodía fijo (`Engine.is_editor_hint()`).

## `LuzNatural`
Sol y luna "reales" como luces muy lejanas detrás de la pared, con un recorrido configurable por `@export` (altura, ángulo máximo, tinte del sol) y guías dibujadas en el editor (`@tool`). Puede apagarse (`activa = false`) porque **cuesta en celulares**; entonces las sombras vuelven al sistema dibujado.

## Luces interiores
- `LuzHabitacion`: una `PointLight2D` grande cálida cuya energía sigue a `oscuridad()` (poca de día, mucha de noche); interruptor (botón Luz).
- Lámparas (`Mueble.emite_luz`): lo mismo, más pequeñas; clic para apagar/encender.

## Sombras baratas (`sombra.gd`)
- Un `Node2D` hijo del objeto (origen = su base) que **dibuja elipses suaves** por código (7 capas de opacidad creciente = borde difuso) en el suelo; `z_index = -4` (sobre el piso, bajo todo lo demás; en pantallas con imagen de fondo usar `capa_z = 0`).
- Una **sombra de contacto** siempre, y una **sombra proyectada por cada luz** que le llega, hacia el lado contrario de la luz, con largo ∝ distancia/altura. Fuentes: sol/luna (solo si hay ventanas y solo donde cae la mancha: `Ventana.cobertura_en`), lámparas encendidas (`intensidad_luz`), luz de la habitación, relámpago.
- Se recalcula solo si cambia algo (se movió, o cada `PASO` = 0,1 s); el personaje usa `cada_cuadro = true`.
- **No usa `LightOccluder2D`** para las sombras (caro en móvil). Alfombras, ventanas y cosas apoyadas en mesas no llevan sombra.
- Para una pantalla sin luces (la de inicio) hay una sombra fija: `direccion_fija`, `largo_fijo`, `alfa_fijo`.

## Para otro juego
1. Copiar `ciclo_dia.gd` y `clima.gd`; registrar `CicloDia` como autoload (el clima se crea dentro).
2. Cambiar las tablas al estilo del juego (más fría, más cálida, noches más claras...).
3. Para un mundo sin ventanas, mostrar el clima como **overlay de pantalla** (un `CanvasLayer` con las mismas partículas a pantalla completa) en vez de por el cristal; la función de `_crear_emisor`/`_actualizar_emisor` sirve igual.
4. Un botón de clima para probar (`selector_clima.gd`) con un letrero que anuncia el modo.
5. Si hay audio: lluvia y trueno se disparan con los mismos valores (`clima.lluvia`, `disparar_relampago`). **No hecho aún en Zarita.**
