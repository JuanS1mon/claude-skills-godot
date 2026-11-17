# Cómo se trabaja con Juan (y por qué)

## Objetivo del proyecto
Juan no solo quiere un juego: quiere **aprender Godot** haciéndolo. Por eso:
- Responder **siempre en español**, con ortografía completa (tildes, ñ, ü).
- Avanzar **paso a paso**; explicar cada concepto nuevo (escena, nodo, señal, grupo, `Resource`, tema...) **antes** de usarlo, en pocas frases y con la razón de por qué se hace así.
- **Las escenas las arma Juan en el editor** cuando son simples y didácticas (la primera escena de Zarita, la casa, el movimiento). Con el tiempo, y cuando es mucho texto repetitivo, Claude escribe el `.tscn` directamente (formato texto) y Juan lo abre en el editor. Siempre decir qué se hizo y dónde mirarlo.
- Juego **relajante**, inspirado en *Tsuki's Odyssey*: sin presión, con detalles que dan vida (parpadeo, cola, clima, luz).
- Está pensado para **celular**: todo lo táctil primero (ver `interfaz-movil.md`).

## Ritmo de cada entrega
1. Entender el pedido; si hay dos caminos con consecuencias distintas, ofrecer opciones concretas con una recomendación (herramienta de preguntas con 2-4 opciones). Si no, elegir el valor razonable y avisar.
2. Mirar el código existente **antes** de editar (`Read`/`Grep`). El proyecto tiene `CLAUDE.md` con la arquitectura: leerlo y mantenerlo.
3. Implementar en el mínimo de archivos; reusar patrones ya existentes (grupos, señales, fichas).
4. **Verificar sin Godot**: comprobar que cada `ExtResource`/`SubResource` usado esté definido, que los nombres de nodos coincidan con los `$Ruta` del script, que no queden referencias a archivos borrados (`grep`), y — para arte — hacer una **vista previa** con Pillow y mirarla.
5. Actualizar `CLAUDE.md` (arquitectura + decisiones + trampas nuevas).
6. Cerrar con un resumen en español: qué cambió, qué archivos, **qué no se probó**, y qué probar (3-4 puntos). Pedir el **primer error del Depurador** si algo falla.

## Orden que funcionó para construir el juego
1. Personaje que se mueve (CharacterBody2D + `Input.get_vector`) con animación.
2. La casa: suelo, paredes con colisión, personaje dentro.
3. Mueble base (`Area2D` que se arrastra) → escenas heredadas → fichas `Resource`.
4. Modo decorar + inventario + tienda + economía + guardado JSON.
5. Arte real (hojas de IA recortadas), sombras, colisión por huella, orden de dibujo.
6. Día/noche, ventanas, luces, clima.
7. Pantalla de inicio, logo, HUD, tema, controles táctiles, ajustes.
8. Android.

Cada paso dejó algo jugable; nunca se acumularon cambios grandes sin poder ver el resultado.

## Edición de archivos mientras Juan tiene el editor abierto
Godot guarda en memoria su versión de las escenas abiertas y **pisa** los cambios hechos desde fuera (pasó: quedaron `textura = null` en instancias, se perdieron nodos). Reglas:
- Antes de modificar varios `.tscn`/`project.godot`, decirle que **cierre Godot sin guardar las escenas afectadas** y lo reabra después.
- Para `project.godot`, autoloads y ajustes de exportación preferir que Juan lo haga por el diálogo; si se edita el archivo, avisar.
- Los `.gd` nuevos y los recursos nuevos hacen que Godot muestre "invalid UID ... using text path": es inofensivo.
- Si algo recién creado "no está declarado", casi siempre es caché del editor (ver `trampas-godot.md`).

## Herramientas de la máquina (Windows)
- Shell principal PowerShell; también Bash (Git Bash). Para editar texto en bloque, lo más fiable fue `python - <<'PYEOF' ... PYEOF` con funciones `edit(archivo, viejo, nuevo)` que **fallan si el texto viejo no aparece exactamente una vez**. Un heredoc con muchas comillas mezcladas falló alguna vez con "unexpected EOF": para archivos largos usar la herramienta de escritura de archivos.
- Pillow, numpy y scipy están disponibles con `python` (sin `-I`: con `-I` no ve los paquetes del usuario).
- Los archivos temporales y vistas previas van en el directorio de scratchpad de la sesión; el arte final, en `assets/` del proyecto.
- Godot **sí** se puede ejecutar desde Claude Code, sobre una copia (ver `probar-en-godot-desde-claude.md`). Para editar archivos con tildes, usar un script Python escrito con la herramienta de escritura, nunca un heredoc.

## Qué suele pedir Juan y cómo responder
- "Quiero poder ver X en Godot": convertir lo que se crea por código en **nodos de escena** (con `@tool` si hay que dibujarlo en el editor) y **paneles visibles en el editor** (esconderlos en `_ready`, no con `visible = false` en el `.tscn`).
- "Funciona pero es tosco": añadir **ayuda al gesto** (imán, deslizamiento suave, resaltado, saltito al soltar), no más funciones.
- "Quiero reutilizarlo en otros juegos": separar lo genérico (autoload de clima, scroll deslizable, joystick) de lo específico y documentarlo; para eso existe este skill.
- Arte: Juan genera con IA y manda la imagen; Claude recorta, limpia y prepara. Pasar **textos de prompt** listos para copiar (ver `arte-con-ia.md`).
