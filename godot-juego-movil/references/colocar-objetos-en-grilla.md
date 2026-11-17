# Colocar objetos sobre un terreno con una grilla (casa, tower defense, granja, ciudad...)

Aprendido decorando una casa isométrica, pero la idea es la misma para **torres sobre un terreno, cultivos, edificios o cualquier cosa que el jugador arrastra y suelta**. Los nombres (`Mueble`, `GeometriaCuarto`) son del juego de la casa; leelos como "objeto colocable" y "geometría del terreno".

## 1. Una sola regla de colocación, desde el principio
Alinear a ojo (pegar a los vecinos, banderas especiales, distancias medidas a mano) son parches de la falta de una grilla. Una regla los reemplaza: **el origen del objeto cae en un punto de una grilla** contada desde un punto fijo del terreno.
- Grilla isométrica de rombos: `punto_grilla(u, v) = origen + (lado*(u-v), lado*pendiente*(u+v))`. `a_grilla(pos, ...)` prueba los puntos cercanos y devuelve el más próximo a `pos` que además sea **válido**.
- **"Válido" es lo que cambia de un juego a otro**: en la casa, que la base entera quede sobre el piso; en un tower defense, que la torre no esté sobre el camino ni sobre otra torre; en una granja, que sea tierra labrable. Conviene aislarlo en una función (`es_valido(celda, objeto)`) y que la grilla solo la llame.
- Una grilla cuadrada (vista cenital) es el mismo código con `pendiente = 0` y ejes ortogonales.

## 2. Medir la pendiente del ARTE, no la del fondo
En la casa los dibujos bajaban 0,5 por píxel (2:1) y el fondo 0,54. Esa diferencia chica causó bordes ondulados y huecos entre objetos contiguos. Antes de programar, medir en una captura la pendiente de los sprites y usar esa para la grilla; el fondo se acomoda con una guía.

## 3. Qué va a la grilla y qué queda libre
Decidirlo por una propiedad de la ficha, no por un `if` por tipo. En la casa quedan libres lo que se apoya sobre otros objetos, las luces, las alfombras y las ventanas. En un tower defense serían libres, por ejemplo, los efectos o los proyectiles; las torres van siempre a la grilla.

## 4. La regla nueva se aplica al SOLTAR, no al CARGAR
Si al abrir la partida se vuelve a acomodar todo, se desarma lo que el jugador armó. Al cargar solo se corrige lo imposible (algo dentro de una pared, fuera del terreno).

## 5. Mostrar la grilla solo al editar
Un nodo hijo de la guía (que está encima de todo) con su propio `z_index` entre el suelo y los objetos y conectado a la señal `draw`. Un `lado_celda` exportado para ajustarlo en el Inspector. Dibujar solo los segmentos que caen sobre terreno válido.

## 6. Sombras y contactos
Una sombra mal puesta se nota más que su ausencia. El origen del objeto suele estar en la esquina de adelante de su base: una elipse de contacto centrada en la base queda toda escondida detrás del propio objeto. Conviene que asome por delante (centrada ~35 % del fondo hacia arriba, más ancha que la base, opacidad ~0,4). Y lo que va pegado a una pared no lleva sombra de suelo.

## 7. Cuando cambia la geometría, lo guardado queda mal
Al pasar de pared recta a esquina isométrica, lo ya guardado quedó flotando. Dejar un método `acomodar_al_suelo()` (solo corrige, sin grilla) que se llame al cargar.

## 8. Lo que falta (siguiente paso natural)
Que cada ficha diga cuántas casillas ocupa, para impedir superposiciones y para validar por casillas (en un tower defense, una torre de 2x2).

Código de referencia: `assets/zarita/scripts/geometria_cuarto.gd` (`punto_grilla`, `a_grilla`), `guia_cuarto.gd` (dibujo de la grilla) y `mueble.gd` (`_va_a_la_grilla`, `_ajustar_al_suelo`).
