# Mecánicas de plataformas 2.5D (`assets/scripts/`)

## Capas de física (nombradas en `project.godot` → `[layer_names]`)
| Capa | Bit | Quién | Máscara |
|---|---|---|---|
| mundo | 1 | piso, bloques | 0 |
| jugador | 2 | `CharacterBody3D` | 21 (mundo + enemigo + agarrable: se puede parar sobre las cajas) |
| enemigo | 4 | `StaticBody3D` del muñeco | 0 |
| bala | 8 | `Area3D` | 21 |
| agarrable | 16 | cajas `RigidBody3D` | 23 |
| (zona de agarre) | 0 | `Area3D` delante del jugador | 16 |

## Personaje (`jugador.gd` + `JugadorStats`)
- **Moverse**: `move_toward` con `aceleracion`/`frenado`; en el aire se multiplica por `control_aire`.
- **Saltar**: coyote time (se puede saltar 0,1 s después de dejar el borde), buffer (un salto apretado 0,12 s antes de tocar el piso cuenta), **salto variable** (al soltar en subida `velocity.y *= corte_salto`), caída más rápida (`mult_caida`) y velocidad de caída máxima.
- **Disparar**: instancia `bala.tscn` en el `Marker3D` `Boca` con `direccion = mirando`; cadencia por temporizador; retroceso horizontal; fogonazo de luz. La bala daña a quien tenga `recibir_dano(cantidad, punto)` y **empuja los `RigidBody3D`** que toca.
- **Agarrar / arrojar** (misma tecla): busca en `ZonaAgarre` el cuerpo más cercano con `al_agarrar()`. La caja se congela (`freeze`), pierde sus capas de colisión y sigue a `PuntoAgarre`. Al arrojar: recupera capas, `linear_velocity` con ángulo (`angulo_lanzamiento`) + parte de la velocidad del jugador, y un giro. La caja arrojada daña según la velocidad del impacto (`caja.gd`, guarda la velocidad del frame anterior porque al chocar ya frenó).
- **Doble salto** (`saltos_extra`, `fuerza_doble_salto`): solo con un toque NUEVO en el aire y **cuando ya no hay coyote** (si no, el segundo toque cerca del borde sería el salto normal y se gastaría el extra). Consume el buffer. Se recarga al tocar el piso. Visual: vuelta de 360° del sprite en Z con un tween (`-TAU * mirando`, 0,3 s). Medido: salto simple ~2 m, con doble ~3,5 m.
- **Dash** (acción `dash`: Shift, L, RB): dirección = input o hacia donde mira; mientras dura (`duracion_dash` 0,14 s) la velocidad es fija `(dir * velocidad_dash, 0)`, **sin gravedad ni control**; al terminar sale con la velocidad normal (sin frenazo). `enfriamiento_dash` y `dashes_aereos` (se recargan en el piso). Chocar una caja en dash le da un impulso y corta el dash (`get_slide_collision`). Visual: estirar el sprite (1,3 x 0,85, vuelve con lerp), pose inclinada, y **estela**: cada 0,03 s un `Sprite3D` con la textura del cuadro actual (`sprite_frames.get_frame_texture`) teñido naranja que se desvanece en 0,2 s. Medido: 4 m de recorrido en el aire a altura constante.
- Las cajas en el aire **pueden tapar balas** (las absorben y se empujan): no es un error, pero confunde al medir daño.
- `R` reinicia la escena (`reload_current_scene`).

## Animación por estado + "acciones" cortas
- `estado` = quieto / corriendo / saltando / cumbre (|vy| < 2) / cayendo.
- Encima, una **acción** con duración (`_hacer("disparando", 0.12)`): disparando, levantar, arrojar, aterrizar (al tocar el piso). Mientras dura, se muestra esa animación.
- Disparar **corriendo** no cambia la animación: la carrera ya tiene la pistola apuntando adelante.
- `speed_scale` de la carrera según `|velocity.x| / velocidad`.
- **Pose de cargar con la caja dibujada**: si la IA dibuja el objeto en la pose, **ocultar el objeto real** (`objeto.visible = false`) mientras se carga y mostrarlo al arrojar; si no, se ven dos cajas. Limitación: con una sola pose de carga, correr cargando "desliza" sin mover las piernas.

## Apuntar en 8 direcciones
- `apuntado = (signo(izq/der), signo(abajo/arriba)).normalized()`; sin input, hacia donde mira. En el piso no se apunta abajo; agarrado a la pared se apunta hacia afuera.
- La `Boca` gira alrededor de un `HOMBRO` fijo (`hombro + apuntado * 0.8`); una `Mira` (esfera naranja sin profundidad) a 1,9 m muestra hacia dónde sale. La bala recibe un `Vector3` y gira su sprite con `atan2`.
- Sin cuadros dibujados apuntando arriba, el sprite se **inclina** un 30 % del ángulo (provisorio).
- **W dejó de saltar**: W/S son arriba/abajo; saltar es solo Espacio.

## Pared (grupo "pared")
- Solo se agarra a cuerpos del grupo `pared` (así no se trepa por el costado de cornisas o cajas, que rompería el puzzle). Condición: en el aire, normal de colisión con |x| > 0,7, empujando hacia la pared y sin estar subiendo.
- Se desliza con `velocidad_deslizar` (2,5). Tocar pared recarga doble salto y dash. Mira hacia afuera.
- Salto de pared: `(normal * empuje_pared, fuerza_salto_pared)` + `bloqueo_tras_salto_pared` (0,16 s sin control horizontal, si no se vuelve a pegar). `coyote_pared` 0,1 s. Prioridad: salto normal > salto de pared > doble salto.
- Chimenea de prueba: dos paredes de piedra separadas 4 m, la derecha empieza a 2,2 m para poder entrar caminando.

## Golpe cuerpo a cuerpo
- `PhysicsShapeQueryParameters3D` con una caja delante (`alcance_golpe`), máscara enemigos + objetos, durante `duracion_golpe`; cada cuerpo se golpea una sola vez por golpe (lista `_golpeados`). Daño + impulso a las cajas.
- Visual: pose "arrojar" + `Sprite3D` del efecto (arco blanco de Gemini) que crece y se desvanece.

## Soltar / lanzar la caja
- **S + agarrar**: rayo hacia abajo 1 m adelante (máscara mundo + objetos, excluye jugador y la caja) y la caja se apoya **encima de lo que haya**: así se apilan cajas (base del puzzle).
- **W + agarrar**: la lanza en la dirección del apuntado (arriba o diagonal), un 15 % más fuerte.
- Sin dirección: el arco de siempre. Pararse en la esquina de una caja la hace salir disparada (física de Jolt): a Juan le gustó, se dejó.

## Vida del jugador
- `vida_max` 5 corazones; cada golpe resta 1, empuja hacia atrás, suelta lo que carga y da `invulnerable` 1 s (parpadeo). En 0 reaparece en el inicio. Señal `vida_cambio` → HUD con corazones dibujados (TextureRect por corazón).
- Las balas y cajas propias no dañan al grupo `jugador`.

## Enemigo que patrulla y ataca (`escarabajo.gd`)
- `CharacterBody3D` con estados: patrulla (radio alrededor del inicio, da vuelta en paredes) → ve al jugador (rango 9 m, |dy| < 3) → apuntar 0,45 s → disparar (bola de energía dirigida, vertical limitada a ±0,5) → patrulla, enfriamiento 1,8 s. Daño por contacto con un `Area3D`. Golpe 0,25 s; derrotado → sin colisión, a los 3 s se desvanece y reaparece.
- El dibujo de Gemini salió mirando a la DERECHA (se pidió izquierda): `flip_h = dir < 0`.
- `Efectos.numero_flotante()` (clase estática) para los números de daño.

## Dash en 8 direcciones
- Misma regla que el apuntado (W/S + A/D; abajo solo en el aire). La parte vertical va a `factor_dash_vertical` (0,6) de la velocidad; al terminar conserva la mitad de la velocidad vertical. Se estira a lo alto si es vertical.
- **Cada movimiento nuevo cambia lo que el jugador alcanza: volver a medir y recalibrar los puzzles.** Script `pruebas/prueba_altura.gd`: salto + doble 3,64 m; + dash arriba 5,47; dash arriba en el piso + doble + dash arriba 5,66 (el dash desde el piso no gasta el dash aéreo). Con eso la cornisa del puzzle pasó a tener la parte de arriba a 6,8 m: 1 caja → 6,0-6,6 (no llega), 2 cajas → ~7 y con dash diagonal aterriza (`pruebas/prueba_puzzle.gd`).
- Ojo al probar alturas: si el test empuja hacia la cornisa desde el principio, el personaje se golpea la cabeza contra la parte de abajo; y si sigue empujando después de aterrizar, la cruza y se cae. Registrar "aterrizó arriba en algún momento", no la posición final.

## Enemigos: base común (`enemigo.gd`, `class_name Enemigo`)
- `escarabajo.gd`, `volador.gd` y `slime.gd` extienden `Enemigo` y solo redefinen `_comportamiento(delta)`, `_usa_gravedad()`, `_tras_golpe()` y `rebota_balas()`. La base maneja vida, daño por contacto, estado `golpe`, derrota y reaparición (contador en `_physics_process`, sin `await`: no se pisan dos reapariciones).
- **Derribado = objeto agarrable**: pasa a la capa 16 (agarrable) con máscara 1|4|16, tiene `al_agarrar()` / `al_soltar(vel)` / `lanzada` igual que la caja, así el jugador lo trata como una caja (`objeto: PhysicsBody3D`). Sigue siendo `CharacterBody3D`: cae con gravedad propia y, si está `lanzada`, daña con `velocidad x dano_por_velocidad` a lo que choque en `get_slide_collision`. El golpe cuerpo a cuerpo lo patea. El tiempo para reaparecer no corre mientras lo cargan.
- El origen del enemigo está en los pies y el de la caja en el centro: `desfase_agarre` (export) corrige dónde queda sobre la cabeza. Si el dibujo derribado es chato (slime hecho charco) no tapa la caja dibujada de la pose `cargando`: `anim_agarrado` permite mostrar otro cuadro (el slime usa `golpe`).
- **Escarabajo**: tras cada golpe se esconde `tiempo_escondido` s; escondido, `rebota_balas()` es true y `bala.gd` invierte la bala (sin daño, "¡clink!"). Lo dañan el golpe, las cajas, los enemigos arrojados y el disparo cargado al máximo (`perforante`).
- **Volador**: sin gravedad; vaivén con seno alrededor de su altura; si el jugador pasa por debajo: `avisar` 0,4 s (telegrafía) → `picada` en línea recta → vuelve. Derribado cae al piso.
- **Slime**: en el piso espera `pausa_entre_saltos` y salta hacia el jugador (o patrulla).

## Disparo y lanzamiento cargados
- Disparar dejó de ser automático: **un toque = una bala**; mantener carga (`tiempo_carga` 0,8 s) y al soltar sale una bala con daño y tamaño interpolados (`dano_cargado`, `escala_cargada`); con carga 1 es `perforante` (atraviesa enemigos). Una bolita en la boca del arma crece con la carga. Con algo en las manos no se dispara.
- Agarrar con algo en las manos: **se arroja al SOLTAR el botón**; mantener hasta `tiempo_carga_lanzar` multiplica la fuerza hasta `mult_lanzamiento_cargado` (x2; medido 9 → 18 m/s). El objeto tiembla mientras carga. `S + agarrar` sigue siendo inmediato.

## Poderes absorbidos (`jugador.poder`)
- Con un enemigo en las manos, **S + agarrar** lo absorbe (`al_absorber()`: se achica, desaparece y reaparece más tarde). Un poder por vez; se pierde al morir.
- `escarabajo`: S + agarrar mantenido, con las manos libres → `en_caparazon`: quieto, no recibe daño y `proyectil_enemigo.gd` rebota (`reflejado`, pasa a dañar enemigos). Nodo `Caparazon` (Sprite3D) tapa al zorro.
- `volador`: gastado el doble salto, mantener saltar da `tiempo_vuelo` (2,5 s) subiendo a `velocidad_vuelo`; se recarga en el piso; el dash funciona en vuelo. Medido: 17 m de altura (sin vuelo 5,7).
- `slime`: cualquier `StaticBody3D` vertical cuenta como pared, se queda pegado sin empujar (`test_move` hacia la pared con `KinematicCollision3D` para saber contra qué), S desliza, alejarse lo suelta; deja manchas de baba (`Efectos.baba`) en la cara FRONTAL de la pared (z = 1,03): la cara lateral se ve de canto con cámara lateral.
- Ojo: este poder permite trepar por el costado de cualquier cosa fija (rompe puzzles pensados sin él).

## Estrellas = tipos de disparo
- `estrella.gd` tiene `@export_enum("ninguno", "triple", "rebote", "explosivo")` (un `@export_enum` no acepta un valor vacío ""). Al juntarla llama `jugador.desbloquear_disparo(tipo)`; `Q` / LB (`cambiar_disparo`) rota entre los desbloqueados.
- `bala.gd` recibe la variante: `rebotes` (un `Area3D` no conoce la normal: rayo contra la capa mundo antes de avanzar y `direccion.bounce`), `radio_explosion` (consulta con esfera + `Efectos.explosion`), `perforante`, `escala`, `color`.
- `Input.action_press` en las pruebas NO genera eventos para `_unhandled_input`: lo que se lee ahí (reiniciar, cambiar disparo) se prueba llamando a la función.

## Jefe (`jefe.gd` + `arena_jefe.gd` + `onda.gd` + `bellota.gd`)
- **Jabalí de guerra**: pelea por patrón fijo `["embestir", "saltar", "lluvia", "saltar"]`, cada ataque con un AVISO antes (pose + pausa) para poder leerlo. No extiende `Enemigo` (no se agarra): script propio con estados.
  - **Embestida**: cruza la arena y al chocar la pared (`is_on_wall`) queda ATURDIDO ~3 s con daño x2: la ventana de daño principal.
  - **Salto**: balística hacia el jugador (`t_aire = 2 * fuerza / gravedad / mult`); al caer, 2 `Onda.crear()` (crestas que recorren el piso y se saltan; en furia, una 2.ª tanda más rápida).
  - **Lluvia**: bellotas en abanico balístico repartidas por la arena; cada una dibuja una MARCA en el piso donde va a caer (se calcula con la balística al nacer).
- **Furia** al 15 % de vida: `mult_furia` 1,5 acelera todo (velocidades, avisos y `speed_scale` de las animaciones), +2 bellotas, tinte rojo. Vida 500; aturdido, el daño cargado entra x2.
- **Arena** (`arena_jefe.gd`): el jefe duerme (`set_physics_process(false)`) hasta que el jugador pisa el `Area3D` de entrada; se cierra una puerta detrás, HUD muestra la barra (`mostrar_jefe`), y al vencerlo la puerta se abre y aparece la estrella de premio. El piso de la arena es un bloque aparte (el piso principal termina en x = 50).
- **Trampas de Jolt aprendidas** (las dos daban "embestida que se aturde sin moverse", `vx` quedaba 0):
  - Si un salto aterriza pegado a la pared, el cuerpo queda en contacto permanente y `is_on_wall()` sigue prendido en frames sin empuje: al aterrizar, `clampf` de la x con un margen MAYOR que el medio ancho del cuerpo.
  - Tras `is_on_floor()` el cuerpo sigue un par de frames con la velocidad horizontal del salto: cortarla al aterrizar.
- Sacudida de cámara: `camara.sacudir(fuerza)` (ruido que decae); texto flotante para "¡PUMBA!" / "¡FURIA!".
- Prueba: `pruebas/prueba_jefe.gd` (22 chequeos; el "jugador" esquiva teletransportándose al lado opuesto del jefe, si se queda en el rincón la embestida dura 1 frame y no se puede medir).

## Mapa de pruebas
De izquierda a derecha: chimenea con estrella arriba (pared), bloque alto, plataforma, cajas, inicio, bloque bajo, muñeco, **puzzle de cajas** (3 cajas y una cornisa con la parte de arriba a 5 m: con 1 caja no se llega, con 2 apiladas sí, porque el doble salto alcanza ~3,5 m), escarabajo patrullando y una estrella detrás. HUD: corazones y "★ n / 3" (cuenta las del grupo `estrella`). Después se sumaron: volador en x = -15 con una plataforma a 10,5 m encima (solo se llega volando), slime en x = 42 y una pared de 10 m en x = 47 para probar el poder del slime. Estrellas: chimenea = triple, cornisa = rebote, detrás del escarabajo = explosivo. Pruebas: `pruebas/prueba_poderes.gd` (30 chequeos) y `pruebas/prueba_enemigos.gd`.

## Enemigo de práctica (`enemigo_dummy.gd`)
- `StaticBody3D` con `recibir_dano(cantidad, punto)`: resta vida, número flotante (`Label3D` con billboard, sube y se desvanece), destello (`modulate` rojo → blanco con tween) y empujón elástico del sprite hacia el lado contrario al golpe.
- `AnimatedSprite3D`: `quieto` (bucle), `golpe` (sin bucle → vuelve a `quieto` en `animation_finished`), `ko` (bucle) y se reinicia solo a los `tiempo_reinicio` segundos.

## HUD de depuración (`hud_debug.gd`)
FPS, estado, velocidad, en el piso y los controles. Sirve para ajustar sensaciones y aparece en las capturas de prueba.

## Controles del prototipo
A/D o flechas (mover), W/S (apuntar), Espacio (saltar, dos veces = doble salto), Shift o L (dash), J o clic izq. (disparar; mantener = cargar), Q (cambiar disparo), H (golpe), K o clic der. (agarrar; soltar K arroja, mantener = más fuerte; S + K apoya la caja o absorbe al enemigo; W + K lanza hacia arriba), R (reiniciar).
