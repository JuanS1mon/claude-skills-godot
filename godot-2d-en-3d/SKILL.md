---
name: godot-2d-en-3d
description: Guía y código reutilizable para juegos de Godot 4 con estética 2D dentro de un mundo 3D (estilo 2.5D / HD-2D) - sprites que reciben luz y proyectan sombra, toon shader con contorno, cámara lateral, física 3D (Jolt) - aprendida armando el prototipo de mecánicas con Juan. Cubre personaje de plataformas (moverse, salto con coyote/buffer, disparar, agarrar y arrojar objetos), enemigo de práctica con daño y KO, generar hojas de sprites con Gemini desde Chrome y recortarlas, modelos 3D de Mojulo, y probar el juego desde Claude con input simulado y capturas. Usar siempre que se trabaje en un juego Godot 3D que deba verse 2D, en un prototipo de mecánicas 2.5D o en sprites dentro de escenas 3D, aunque no se nombre el skill. Para juegos 2D puros usar godot-juego-movil.
---

# Juegos 2D en un mundo 3D (Godot 4)

Lo aprendido armando el **prototipo de mecánicas** (`D:\Prototipo\nuevo-proyecto-de-juego`, Godot 4.7, Forward+, Jolt): un plano, un zorro aventurero, un muñeco de práctica, cajas para agarrar y arrojar, bloques para saltar. La idea: **se ve como dibujo 2D, pero tiene luces, sombras y física 3D de verdad**. Cada cosa nueva que funcione (o falle) se anota en la referencia que corresponda.

La forma de trabajar con Juan es la misma de `godot-juego-movil` (leer su `references/forma-de-trabajo.md`): en español, paso a paso, escenas en el editor, datos en `Resource`, probar con capturas y decir qué se probó y qué no.

## Qué leer según la tarea

| Si la tarea es... | Lee |
|---|---|
| Configurar el proyecto, sprites en 3D, toon shader, contorno, cámara lateral, luces | `references/estetica-2d-en-3d.md` |
| Personaje de plataformas: moverse, saltar, disparar, agarrar/arrojar; enemigo de práctica; capas de física; animaciones por estado | `references/mecanicas-plataforma.md` |
| Generar sprites con **Gemini desde Chrome** y recortarlos (sin créditos de SpriteCook) | `references/arte-gemini-sprites.md` |
| Modelos 3D con **Mojulo** (CLI, exportar .glb, problemas al importar) | `references/modelos-mojulo.md` |
| Probar el juego desde Claude: input simulado, capturas, logs; MCP `godot-mcp-runtime` | `references/probar-2d-en-3d.md` |

## Código listo para copiar (`assets/`)

- `assets/scripts/`: `jugador.gd`, `jugador_stats.gd`, `bala.gd`, `caja.gd`, `enemigo_dummy.gd`, `camara.gd`, `hud_debug.gd`, `modelo_importado.gd`. Comentados en español; cada uno dice de qué nodos depende.
- `assets/escenas/`: los `.tscn` del prototipo (jugador, bala, caja, enemigo, mundo), útiles como ejemplo del formato.
- `assets/shaders/`: `toon.gdshader`, `contorno.gdshader`, `toon.tres`, `toon_vertice.tres`.
- `assets/herramientas/cortar_hoja_personaje.py`: corta una hoja de sprites sobre verde en cuadros alineados.
- `assets/herramientas/cortar_hoja_relleno.py`: igual, pero para hojas con varios personajes o personajes verdosos (slime).
- `assets/pruebas/prueba_input.gd`: plantilla de prueba con teclas simuladas y capturas.
- `assets/pruebas/prueba_jefe.gd`: pelea de jefe por patrón con furia (ver `references/mecanicas-plataforma.md`).
- `assets/pruebas/prueba_poderes.gd` y `prueba_enemigos.gd`: enemigos agarrables, cargas, poderes absorbidos y tipos de disparo (ver `references/mecanicas-plataforma.md`).

## Principios que rindieron

- **Mecánicas primero con placeholders, arte después.** Rectángulos de color (`GradientTexture2D`) hasta que el movimiento se sienta bien; recién entonces se genera arte, así no se tira arte cuando cambia la mecánica.
- **Todos los números del personaje en un `Resource`** (`JugadorStats`): velocidad, salto, coyote, cadencia, fuerza de lanzamiento. Se ajustan en el Inspector con el juego corriendo.
- **El juego vive en el plano X/Y; Z solo es profundidad visual.** `axis_lock_linear_z` + `velocity.z = 0` + `position.z = 0` en el personaje; los `RigidBody3D` con z y rotaciones x/y bloqueadas.
- **Sprites con `shaded = true` y `alpha_cut = 2`** (opaque prepass): reciben la luz de la escena y proyectan sombra.
- **Un solo material toon para todo lo 3D**, con el color por instancia (`instance uniform`): cambiar el color de un bloque no crea materiales nuevos.
- **Probar con input simulado y capturas** después de cada cambio: así se cazaron la pared invisible (mismo color que el cielo), la cámara que tomaba un modelo importado y las balas tapadas por un bloque.
- **Antes de gastar créditos o tiempo en una herramienta nueva, mirar los límites**: SpriteCook gratis = 40 créditos (alcanza para 1 personaje + 1 animación); Gemini desde Chrome no tiene ese límite.
