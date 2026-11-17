# Juego idle / auto-batalla con gacha: sistemas, economía y balance

Aprendido con *Héroes Idle Espacial* (vertical 720x1280, Godot 4.7, olas de enemigos, equipo que dispara solo, invocación de héroes). Vale para cualquier juego de olas, idle o gacha. El proyecto real tiene el detalle en su `CLAUDE.md` y `docs/diseno.md`.

## Estructura que funcionó
- **Autoloads con una sola responsabilidad**: `Economia` (monedas), `Progreso` (olas/hitos), `Tripulacion` (equipo y niveles), `Gacha`, `Mision` (la partida en curso), `Anuncios`, `Diarias`, `Mejoras`, `Guardado`. Cada uno emite señales; la pantalla solo se dibuja.
- **Datos en `Resource`**: una ficha por héroe y una por enemigo (`.tres`). Un enemigo nuevo = ficha + escena + (opcional) comportamiento. Las escenas viven en carpetas por tema (`scenes/personajes/heroes`, `.../enemigos`, `scenes/efectos`, `scenes/hud`): **un personaje = una escena** que funciona sola (F6).
- **Todo lo que se afina va como `@export_group`** en el script de la batalla ("Dificultad", "Experiencia del equipo"): vida/daño lineal y exponencial por ola, enemigos base, máximo en pantalla, curación entre olas, etc. Se cambian en el editor y el simulador los pasa como `ajustes`.

## Enemigos y olas
- **Tabla de referencia del usuario primero**: si pasa capturas de tablas (vida, ataque, velocidad y % de aparición por ola), copiar **la forma de la curva y una base baja**, no inventar. Si "está muy difícil al principio", casi siempre es la base, no la pendiente.
- **Spawn ponderado por ola**: cada enemigo tiene `peso(ola)` (interpolación entre su peso inicial y el de la última ola, con `OLA_PESO_FINAL = 100`). Los raros (tanques, a distancia) tienen peso bajo y suben. Jefe cada 10 olas que suelta cristales.
- **Comportamientos como `match` en la ficha** (`distancia`, `protector`, `vampiro`, `divisor`, `rayo`, `saboteador`, `comandante`, `sobrecarga`, `jefe`): un solo script de enemigo, la variedad sale de los datos.
- **Sin tope duro de nivel**: poner un tope lejano (1000 olas) y **premios por hito** (cada 25 olas; en la ola 100 un héroe SSR). El tope se anuncia con una victoria.
- **Experiencia compartida dentro de la partida** (se reinicia en cada misión): al subir de nivel el equipo gana bonus de vida/daño y se cura un poco. Sin esto, a olas altas el equipo no escala y el jugador siente que "los tripulantes no suben".
- **Velocidad de olas como mejora permanente**: NO acortar el intervalo de aparición (rompe la dificultad: cayó de la ola 45 a la 33). Acelerar el tiempo del juego con `Engine.time_scale` **relativo** (multiplicar y deshacer al salir) y dejar la profundidad igual.
- Los textos de hito, "ola superada", etc. se **encolan**: si salen a la vez, uno tapa al otro.

## Habilidades y control
- **Mantener apretada la tarjeta de habilidad (0,5 s) = modo automático** del tripulante (insignia AUTO, vibración, se guarda). Un toque corto la usa a mano. En automático se usa cuando está lista **y conviene** (`_conviene_usar`: área si hay 2+ enemigos, curación si alguien baja de 65 %...).
- El jugador toca al tripulante y después el lugar; se queda ahí y dispara solo. Con 4+ tripulantes las tarjetas se achican y pasan a 2 filas (el HUD informa cuánto alto reserva).

## Economía de monedas premium (cristales/gemas)
1. **Fijar primero la meta de tiempo** ("los 8 espacios de equipo en ~1 mes con juego diario") y calcular el ingreso gratis por día con una tabla de fuentes; el coste de cada compra sale de ahí. Ejemplo: misiones 80 + anuncios 75 + racha 10 + refinado 40 ≈ 205/día.
2. **Compras con coste doble por paso** (slots de equipo 150, 300, 600, 1200, 2400) se pueden afinar con una sola constante.
3. **Los materiales no se vuelven inútiles**: desbloquear con moneda premium, **subir de nivel con materiales** (decisión del usuario). Mejoras caras y lentas a propósito.
4. **Misiones diarias** (se renuevan a medianoche local) + **racha de 7 días** con premio mayor el día 7; duplicar el premio de una misión mirando un anuncio.
5. **Mejoras permanentes ocultas**: unas pocas visibles; al pagar una suma grande (1000) se desbloquea una **tanda** nueva que antes se ve como "???". Dejar clarísimo en la interfaz qué es **permanente** y qué es solo de la partida.
6. **Ocultar en las pruebas, apagar al lanzar**: un `MODO_PRUEBAS` que regala 1000 monedas al empezar; recordar ponerlo en `false` antes de publicar.

## Anuncios (patrón de "puerta única")
- Un autoload `Anuncios` con `mostrar_recompensa() -> bool` (hoy simulado, mañana AdMob): todas las pantallas llaman a lo mismo.
- **Un solo tope diario compartido** por todos los lugares (5 por día). El contador va en su propio archivo (`user://anuncios.json`), no en la partida, y si el reloj retrocede no se regala un día nuevo.
- Lugares que funcionaron: la cápsula de invocación (+15 cristales), duplicar una misión diaria y **el cartel de fin de misión**.
- **Cartel de fin de misión que duplica**: botón "▶ Duplicar el oro y los recursos". Reglas: se oculta si no hubo premio; se apaga ("Recompensa duplicada") tras usarlo; si no quedan anuncios dice "Anuncios de hoy agotados"; **no duplica premios por hito ni la moneda premium**; con la bodega llena lo que no entra se pierde; **bloquear el botón de cerrar mientras corre el anuncio** y ignorar un segundo toque (`_ocupado`). Mostrar "(x2)" junto a cada línea.
- Nunca anuncios en medio del combate.

## Balance medido, no a ojo (`assets/idle/simulador.gd`)
- Un autoload `Prueba` que corre la **batalla real** sin pantalla y acelerada: `godot --headless --path <copia> --fixed-fps 60` más `Engine.time_scale`. Cada configuración tarda segundos.
- Jugador "perezoso" (tripulantes quietos, habilidades automáticas) como **piso**; el real rinde más. Repetir 3 veces y tomar la mediana; el ruido es ±2 olas.
- Objetivos que se usaron: equipo inicial ≈ ola 11, equipo medio ≈ 44, con 4 mejoras de nave nivel 2 ≈ 54, nivel 4 ≈ 68. Si una mejora cambia el resultado menos que el ruido, no sirve.
- Se midió cada decisión (acelerar olas, curación 10 %, satélite, minas) antes de dejarla.

## Búsqueda evolutiva de la dificultad (`assets/idle/busqueda.gd`) — sin red neuronal
Cuando el usuario pide "desafiante pero no imposible", **definir objetivos en olas** (equipo inicial ~11, medio ~45, fuerte ~60) y dejar que el simulador busque los números:
- Un autoload `Prueba` hace una estrategia evolutiva (1+λ): muta 1-3 de los 7 valores (`vida_exponencial`, `dano_exponencial`, `escala_vida`, `dano_enemigo`, `curacion_base`, `curar_al_subir`, `bono_por_nivel`), mide los 3 equipos y se queda con la combinación de menor error relativo cuadrático (+ una pizca de preferencia por cambiar poco). La FORMA de las curvas que dio el usuario (los coeficientes lineales) no se toca.
- **En paralelo**: 6 instancias de Godot sin pantalla, cada una en SU copia del proyecto con otro `config/name` (si no, comparten `user://partida.json`), prioridad `BelowNormal`, una arrancando de los valores actuales y las otras de puntos al azar. 25 min, ~30 evaluaciones cada una; al final cada una verifica su mejor con más corridas. (La PC tiene 8 núcleos; `time_scale` 10 rinde más que 20 o 40.)
- **Trampa: el tope de tiempo del simulador** (6000 s de juego) hace que un equipo fuerte siempre "caiga" en la misma ola (68); ese objetivo no distingue nada. Poner los objetivos por debajo del tope.
- **Trampa de PowerShell**: `$n` y `$N` son la MISMA variable (sin distinción de mayúsculas): un `param([int]$N)` y un `for ($n ...)` nunca entran al bucle. Usar nombres distintos.
- Resultado en el juego real, verificado con 3-7 corridas: inicial 13 / medio 40 / medio+Nv2 54 / medio+Nv4 61 (objetivo 11 / 45 / 60).
- Una red neuronal / aprendizaje por refuerzo (un "director de oleadas") es la versión grande: se entrenaría contra el bot perezoso, no contra una persona, así que primero conviene la búsqueda de parámetros.

## Pendientes típicos que conviene anotar
Curación entre olas que pese poco; pocos héroes SSR; arte provisional (enemigos teñidos); AdMob/Billing reales; AAB firmado.

## Elegir 1 de 3 tras el jefe, y empezar más arriba (Albatros, 2026-11-10)
Dos cosas que le dan decisiones y quitan tiempo muerto a un idle de olas, y las trampas que aparecieron:
- **Botín del jefe** (`assets/idle/botin.gd`): cada jefe ofrece 3 cartas al azar que valen solo para esa partida. Todas en **porcentaje** sobre lo que el equipo ya tiene (si los enemigos crecen exponencial, un bono fijo deja de servir a las pocas olas), con rarezas, un tope en las que no pueden crecer sin límite (recarga, lentitud) y dos o tres cartas "de codicia" (oro, recursos, experiencia) contra las de poder: esa es la decisión. Si el jugador no toca nada en 15 s el juego elige sola (sigue siendo idle), y al simulador de balance se le da un interruptor para que elija al instante sin panel.
- **Detener la batalla sin `get_tree().paused`**: la batalla pone su propio `process_mode = DISABLED` y el panel de cartas, hijo suyo, lleva `process_mode = ALWAYS` (un hijo "siempre" sigue vivo con el padre detenido). La corrutina que espera la señal del panel se reanuda igual. Los tweens y la cuenta atrás del panel van en tiempo real (`set_ignore_time_scale`, `Time.get_ticks_msec`).
- **Lo pendiente se guarda**: los botines sin elegir y qué jefe ya pagó van en el guardado. Si no, cerrar el juego tras matar al jefe (la ola en curso empieza de nuevo y el jefe vuelve a salir) regala otra carta en cada reinicio.
- **Empezar desde un punto de control** (60% del récord): el equipo recibe lo que las olas salteadas le habrían dado PARA ESA PARTIDA (experiencia, botines). **Nunca el oro ni los recursos**: se probó cobrarlos y bajar-cobrar-retirarse daba medio millón de oro cada 10 segundos. Lo que se gana al saltear es tiempo. El récord se guarda por zona de dificultad (acá, por sistema estelar), y una partida vieja se siembra con lo seguro.
- **Antes de tocar un archivo grande, mirar si cambió**: otra sesión había hecho las hordas en el mismo `batalla.gd` mientras esta trabajaba; un reemplazo que "no coincide" con el texto esperado fue el aviso. Comparar con la copia de pruebas (`cmp`) y leer la nota nueva del `CLAUDE.md` antes de seguir.
