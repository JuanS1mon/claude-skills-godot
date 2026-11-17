class_name GeometriaCuarto
extends RefCounted
## Forma de las habitaciones: una esquina isométrica vista desde adentro (assets/fondos/casa_esquina.png). La esquina de atrás
## está arriba en el centro; desde ahí las dos paredes bajan en diagonal hacia los costados y el piso ocupa todo lo de abajo.
## Todo lo que pisa el suelo (Zarita, muebles, sombras) usa estas funciones en vez de asumir un rectángulo.

## Punto donde las dos paredes tocan el piso (el vértice de la "V" invertida). Valores por defecto: se ajustan en el
## nodo GuiaCuarto de casa.tscn, que los fija al arrancar.
static var esquina: Vector2 = Vector2(360.0, 375.0)
## Cuántos píxeles baja el borde del piso por cada píxel que se aleja de la esquina hacia un costado (2:1 = 0,5).
static var pendiente: float = 0.54
## Costados y fondo de la casa (el piso llega hasta los bordes de la pantalla).
const X_MIN: float = 24.0
const X_MAX: float = 696.0
const Y_MAX: float = 1233.0
const ANCHO: float = 720.0


## Y del borde del piso (la línea donde la pared toca el suelo) en la columna `x`.
static func y_borde(x: float) -> float:
	return esquina.y + pendiente * absf(x - esquina.x)


static func es_piso(punto: Vector2) -> bool:
	return punto.y >= y_borde(punto.x)


## Deja la base de un objeto (centro `pos` en el borde de abajo, medio ancho `mitad`, profundidad `fondo`) sobre el piso:
## dentro de los costados y con su borde de atrás sin entrar en las paredes. El dibujo puede subir por la pared.
static func ajustar_base(pos: Vector2, mitad: float, fondo: float) -> Vector2:
	pos.x = clampf(pos.x, X_MIN + mitad, X_MAX - mitad)
	# la esquina de atrás más lejana del centro es la que primero toca la pared
	var y_min := esquina.y + pendiente * (absf(pos.x - esquina.x) + mitad) + fondo
	pos.y = clampf(pos.y, y_min, Y_MAX)
	return pos


## Región sólida de las dos paredes (para la colisión): todo lo que está sobre el borde del piso. `subir` la corre hacia
## arriba: la caja de colisión de Zarita tiene su propio alto sobre los pies, y así los pies llegan a rozar la pared.
static func poligono_paredes(subir: float = 0.0) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, -200.0), Vector2(ANCHO, -200.0),
		Vector2(ANCHO, y_borde(ANCHO) - subir), esquina - Vector2(0.0, subir), Vector2(0.0, y_borde(0.0) - subir),
	])


## Grilla del piso: rombos isométricos que se cuentan desde la esquina. `lado` es lo que avanza una casilla en horizontal
## (el rombo entero mide 2 x `lado` de ancho); `PENDIENTE_GRILLA` es la de los dibujos de los muebles (2:1), que no es
## la de la pared del fondo. Los muebles grandes se apoyan siempre en un punto de esta grilla, así dos vecinos quedan alineados.
static var lado: float = 36.0
const PENDIENTE_GRILLA: float = 0.5


## Punto de la grilla (u casillas hacia la derecha-abajo, v hacia la izquierda-abajo, desde la esquina).
static func punto_grilla(u: int, v: int) -> Vector2:
	return esquina + Vector2(lado * (u - v), lado * PENDIENTE_GRILLA * (u + v))


## El punto de la grilla más cercano a `pos` que deja la base entera sobre el piso (misma regla que `ajustar_base`).
static func a_grilla(pos: Vector2, mitad: float, fondo: float) -> Vector2:
	var r := pos - esquina
	var u := (r.x / lado + r.y / (lado * PENDIENTE_GRILLA)) * 0.5
	var v := (r.y / (lado * PENDIENTE_GRILLA) - r.x / lado) * 0.5
	var mejor := ajustar_base(pos, mitad, fondo)
	var distancia := INF
	for du in range(-2, 3):
		for dv in range(-2, 3):
			var c := punto_grilla(roundi(u) + du, roundi(v) + dv)
			if ajustar_base(c, mitad, fondo).distance_to(c) > 1.0:
				continue
			var d := c.distance_to(pos)
			if d < distancia:
				distancia = d
				mejor = c
	return mejor
