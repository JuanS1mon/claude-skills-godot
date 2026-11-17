# Estética 2D en un mundo 3D

## Proyecto
- Renderer **Forward+** (`renderer/rendering_method="forward_plus"`): hace falta para `instance uniform`, SSAO, glow y buenas sombras. `gl_compatibility` (el que trae un proyecto nuevo de Godot 4.7 en algunos casos) no los tiene. Si después se lleva al celular, revisar.
- Física **Jolt** (`3d/physics_engine="Jolt Physics"`).
- `msaa_3d = 2` suaviza los bordes de los bloques.
- El editor de Godot reescribe `project.godot` en formato largo (eventos de input con todos los campos) y quita las líneas con valor por defecto: es normal.

## Sprites en 3D (`Sprite3D` / `AnimatedSprite3D`)
| Propiedad | Valor | Por qué |
|---|---|---|
| `shaded` | `true` | recibe las luces de la escena (sol, fogonazo, luz de la bala) |
| `alpha_cut` | `2` (opaque prepass) | bordes suaves y proyecta sombra; `1` (discard) también da sombra pero borde duro |
| `texture_filter` | por defecto (lineal) para dibujo; `0` (nearest) solo si es pixel art | |
| `billboard` | desactivado | cámara lateral fija; el sprite queda en el plano |
| `flip_h` | según `mirando` | **el lienzo del cuadro debe ser simétrico respecto del torso**, si no el personaje "salta" al girar (el script de recorte ya lo hace) |

- **Tamaño**: `pixel_size = altura_deseada_m / alto_del_personaje_en_px`. Zorro: ~170 px → 1,6 m → `0.0095`. Muñeco: `0.0115` (un poco más alto que el zorro, se leía chico con `0.0083`).
- **Origen en los pies**: el `CharacterBody3D` tiene su origen en el piso; el sprite va a `y = (alto_lienzo/2 - margen) * pixel_size` (zorro: lienzo 199 px → `y = 0.93`).
- Los marcadores que dependen del lado (boca del arma, punto de agarre, zona de agarre) se espejan por código: `marker.position.x = abs_x * mirando`.

## Toon shader + contorno (`assets/shaders/`)
- `toon.gdshader`: la luz se corta en `bandas` (3 por defecto) dentro de `light()`; `DIFFUSE_LIGHT += b * LIGHT_COLOR / PI`. Luz de borde suave (`brillo_borde`) para separar la silueta del fondo. Color por instancia: `instance uniform vec4 color` → en el `.tscn`: `instance_shader_parameters/color = Color(...)`.
- `contorno.gdshader` (va en `next_pass`): `cull_front, unshaded`, empuja los vértices con `normalize(VERTEX) * grosor` (**desde el centro, no por la normal**: con normales las cajas se abren en las esquinas). Funciona bien en mallas convexas centradas (cajas, bloques).
- `toon_vertice.tres`: misma base con `usar_color_vertice = true`, para modelos que guardan el color en los vértices (Mojulo).

## Texturas dibujadas en bloques, cajas y piso (mismo shader toon)
- Una hoja de Gemini con 2x2 texturas cuadradas "seamless tileable" separadas por canaletas verdes (caja de cartón, piedra, tira de pasto+tierra, tablones) + un fondo 16:9 aparte. Recorte: `herramientas/cortar_texturas.py` (rectángulos no verdes, 6 px hacia adentro). **El pasto es verde y se corta mal**: esa tira se recorta a mano por coordenadas.
- El shader proyecta la textura **por ejes** (frente XY, arriba XZ, costado ZY) sin usar las UV: sirve igual para un bloque de 1 m o una plataforma de 3 m. `metros_por_textura` = tamaño de una repetición.
- **Cajas que se mueven**: `espacio_objeto = true`, `metros = tamaño de la caja`, `desfase = 0.5` → una cara entera por lado, y la textura gira con la caja.
- **Piso**: caja de 60 x 4 x 5 con el frente en z = 1,5 (los personajes en z = 0 caminan sobre la cara de arriba, verde liso: `solo_frente = true`). El frente muestra la tira de pasto+tierra (`tira_de_suelo`): debajo de la primera repetición se repite solo la tierra **en espejo** (la tierra de la IA no repite en vertical y se veía el corte).
- Con `fract()` en la UV hay que muestrear con `textureGrad` y las derivadas de la UV sin cortar; si no, el mipmap dibuja una línea en cada repetición. Dejar margen (0,56-0,98) para que el filtrado no traiga el pasto del borde opuesto.
- **Matas de pasto**: un `QuadMesh` de 60 m en el borde del piso con alpha scissor, `uv1_scale.x = 60 / ancho_tira`. Agregar filas transparentes abajo del PNG: con `repeat` el filtrado traía la fila de abajo al borde de arriba (línea blanca).
- **Fondo pintado**: `QuadMesh` 48 x 26,8 sin sombreado a z = -12, con `fondo_parallax.gd` (sigue a la cámara al 85 %). Reemplaza la pared y el cielo procedural.
- **Caja cargada**: la pose "cargando" del sprite trae una caja dibujada más chica (0,67 m). En vez de ocultar la caja real, se la pone encima tapando la dibujada (`PuntoAgarre` en (0.07, 1.66, 0.05), medido sobre el PNG): carga una caja del mismo tamaño y estilo que las del piso.
- El cofre de Mojulo (blanco) se sacó de la escena: desentonaba con todo lo dibujado.

## Escena (`mundo.tscn`)
- `DirectionalLight3D` con sombras, inclinado hacia -Z y -X (en la base: filas `(0.866,-0.383,0.3214)(0,0.6428,0.766)(-0.5,-0.6634,0.5567)`), así las sombras caen detrás y a un costado y se ven.
- **Pared del fondo de un color que contraste con el cielo** (arena `0.85,0.72,0.55`): con un azul parecido al del cielo procedural parecía que no existía.
- **Piso profundo hacia la cámara** (60 x 1 x 16, corrido +3,5 en Z): si el piso es angosto, la cámara ve su borde frontal y el horizonte de abajo (40 % de la pantalla desperdiciada).
- `WorldEnvironment`: cielo procedural, `ambient_light_source = 3` (cielo), `tonemap_mode = 2` (filmic), SSAO y glow encendidos.
- Luces que aprovechan el 3D: `OmniLight3D` en la boca del arma (se prende 0,05 s al disparar) y una luz chica en cada bala que ilumina el piso al pasar.

## Cámara lateral (`camara.gd`)
- `Camera3D` con `fov = 50`, inclinada -10° (filas `(1,0,0)(0,0.9848,0.1736)(0,-0.1736,0.9848)`), a `distancia = (0, 3, 10.5)` del jugador.
- Sigue con `lerp(destino, 1 - exp(-suavizado * delta))` (independiente de los FPS) y **se adelanta hacia donde mira** el personaje (`adelanto = 1.5`).
