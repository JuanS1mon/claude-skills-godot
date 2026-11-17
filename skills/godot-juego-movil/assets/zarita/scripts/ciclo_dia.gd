extends Node
## Ciclo del día (autoload): lleva la hora del juego, acelerada, y reparte colores y luz según la hora.

## Segundos reales que dura un día completo (24 h) del juego.
const SEGUNDOS_POR_DIA: float = 240.0

## Hora del juego, de 0 a 24. Empieza con la hora real del dispositivo.
var hora: float = 8.0

## Tablas [hora, valor]: entre una hora y la siguiente se interpola. Terminan en 24 y empiezan en 0.
var tabla_ambiente: Array = [
	[0.0, Color(0.40, 0.46, 0.72)],
	[5.0, Color(0.40, 0.46, 0.72)],
	[6.5, Color(0.98, 0.80, 0.68)],
	[8.5, Color(1.00, 0.99, 0.96)],
	[17.0, Color(1.00, 0.98, 0.93)],
	[18.5, Color(1.00, 0.76, 0.54)],
	[20.0, Color(0.62, 0.54, 0.74)],
	[21.5, Color(0.40, 0.46, 0.72)],
	[24.0, Color(0.40, 0.46, 0.72)],
]
## Color de la luz del sol que entra por la ventana: dorada al amanecer y al atardecer.
var tabla_luz_sol: Array = [
	[0.0, Color(1.00, 0.70, 0.38)],
	[6.3, Color(1.00, 0.70, 0.38)],
	[8.5, Color(1.00, 0.93, 0.78)],
	[12.0, Color(1.00, 0.98, 0.90)],
	[16.5, Color(1.00, 0.90, 0.70)],
	[18.5, Color(1.00, 0.58, 0.26)],
	[24.0, Color(1.00, 0.58, 0.26)],
]
var tabla_energia_sol: Array = [
	[0.0, 0.0], [5.8, 0.0], [6.5, 1.0], [8.5, 0.75], [12.0, 0.55],
	[16.5, 0.75], [18.5, 1.1], [19.5, 0.0], [24.0, 0.0],
]
var tabla_energia_luna: Array = [
	[0.0, 0.6], [5.0, 0.6], [6.0, 0.0], [19.5, 0.0], [21.0, 0.6], [24.0, 0.6],
]
## 0 = pleno día, 1 = noche cerrada. Mueve las luces interiores.
var tabla_oscuridad: Array = [
	[0.0, 1.0], [5.0, 1.0], [6.5, 0.0], [18.5, 0.0], [20.5, 1.0], [24.0, 1.0],
]
## Opacidad de cada capa del cielo, de abajo arriba: noche (base), amanecer, día, atardecer y noche (arriba).
## Cada capa entra sobre la anterior y se apaga cuando la siguiente ya la cubre por completo.
var tabla_capas: Array = [
	[[0.0, 1.0], [24.0, 1.0]],
	[[0.0, 0.0], [5.0, 0.0], [6.3, 1.0], [9.0, 1.0], [9.01, 0.0], [24.0, 0.0]],
	[[0.0, 0.0], [7.0, 0.0], [9.0, 1.0], [18.3, 1.0], [18.31, 0.0], [24.0, 0.0]],
	[[0.0, 0.0], [16.5, 0.0], [18.3, 1.0], [21.0, 1.0], [21.01, 0.0], [24.0, 0.0]],
	[[0.0, 0.0], [19.5, 0.0], [21.0, 1.0], [24.0, 1.0]],
]

## Clima actual (nubes, lluvia, relámpagos...). Lo crea esta misma clase, así no hace falta otro autoload.
var clima: Clima

var _modulador: CanvasModulate
var _textura_radial: Texture2D


func _ready() -> void:
	var ahora := Time.get_time_dict_from_system()
	hora = float(ahora.hour) + float(ahora.minute) / 60.0
	clima = Clima.new()
	clima.name = "Clima"
	add_child(clima)
	# Tiñe todo el mundo 2D (no la interfaz, que va en otra capa).
	_modulador = CanvasModulate.new()
	add_child(_modulador)
	_modulador.color = _color_ambiente_final()


func _process(delta: float) -> void:
	hora = fposmod(hora + delta * 24.0 / SEGUNDOS_POR_DIA, 24.0)
	_modulador.color = _color_ambiente_final()


## Luz ambiente: la de la hora del día, teñida por el clima, y aclarada de golpe por un relámpago.
func _color_ambiente_final() -> Color:
	var c: Color = color_en(tabla_ambiente) * clima.mult_ambiente()
	var destello: float = clima.relampago * clima.factor_ventanas()
	return c.lerp(Color(0.90, 0.95, 1.00), clampf(destello * 0.75, 0.0, 1.0))


## Oscuridad de 0 (día) a 1 (noche). Un día nublado también cuenta: enciende las lámparas.
func oscuridad() -> float:
	return maxf(valor_en(tabla_oscuridad), clima.oscuridad_extra())


## El sol y la luna son UNO para toda la casa: cruzan la pared de izquierda a derecha en un arco, en estas
## coordenadas del mundo. Cada ventana los muestra solo si pasan por su cristal.
const X_ASTRO_MIN: float = 40.0
const X_ASTRO_MAX: float = 680.0
const Y_HORIZONTE: float = 155.0
## Para las sombras: la luz natural viene "desde detrás de la pared", así las sombras caen hacia el espectador.
const Y_ORIGEN_LUZ_NATURAL: float = -200.0


## Luz natural real (LuzNatural): la registra aquí cuando está activa. Entonces el sol y la luna son luces
## muy lejanas, detrás de la pared, y su recorrido lo define esa escena.
var luz_natural_activa: bool = false
var luz_natural: LuzNatural


## Dónde está la luz del sol o de la luna (t de 0 a 1 es su recorrido), según la escena LuzNatural.
func posicion_luz_natural(t: float) -> Vector2:
	return luz_natural.posicion_luz(t)


## Punto del mundo por el que pasa un astro: t de 0 a 1 es su recorrido, y `altura` lo que sube en el arco.
func posicion_astro(t: float, altura: float) -> Vector2:
	return Vector2(lerpf(X_ASTRO_MIN, X_ASTRO_MAX, t), Y_HORIZONTE - altura * sin(PI * t))


## Luz natural que hay ahora, para las sombras: [{"pos", "intensidad" (0 a 1), "k" (largo relativo), "es_sol"}].
## "k" crece cuando el sol está bajo (amanecer y atardecer).
func fuentes_naturales() -> Array:
	var lista: Array = []
	var ts := (hora - 6.0) / 13.0
	if ts > 0.0 and ts < 1.0:
		lista.append({
			"pos": posicion_luz_natural(ts) if luz_natural_activa and luz_natural != null else Vector2(lerpf(X_ASTRO_MIN, X_ASTRO_MAX, ts), Y_ORIGEN_LUZ_NATURAL),
			"intensidad": clampf(sin(PI * ts) * 2.2, 0.0, 1.0) * minf(clima.factor_sol(), 1.0),
			"k": 0.25 + 0.9 * absf(2.0 * ts - 1.0),
			"es_sol": true,
		})
	var hl := hora if hora >= 18.0 else hora + 24.0
	var tl := (hl - 18.0) / 12.0
	if tl > 0.0 and tl < 1.0:
		lista.append({
			"pos": posicion_luz_natural(tl) if luz_natural_activa and luz_natural != null else Vector2(lerpf(X_ASTRO_MIN, X_ASTRO_MAX, tl), Y_ORIGEN_LUZ_NATURAL),
			"intensidad": clampf(sin(PI * tl) * 1.6, 0.0, 1.0) * (1.0 - 0.7 * clima.nubes),
			"k": 0.35,
			"es_sol": false,
		})
	# Un relámpago es una luz muy fuerte y breve que entra por las ventanas: sombras cortas y duras.
	if clima.relampago > 0.05:
		lista.append({
			"pos": Vector2(360.0, Y_ORIGEN_LUZ_NATURAL),
			"intensidad": clima.relampago,
			"k": 0.45,
			"es_sol": true,
		})
	return lista


func valor_en(tabla: Array) -> float:
	var i := _tramo(tabla)
	var a: Array = tabla[i]
	var b: Array = tabla[i + 1]
	return lerpf(float(a[1]), float(b[1]), _fraccion(a, b))


func color_en(tabla: Array) -> Color:
	var i := _tramo(tabla)
	var a: Array = tabla[i]
	var b: Array = tabla[i + 1]
	return (a[1] as Color).lerp(b[1] as Color, _fraccion(a, b))


## Opacidad de la capa de cielo número `indice` (0 = noche base ... 4 = noche encima).
func alfa_capa(indice: int) -> float:
	return valor_en(tabla_capas[indice])


## Luz redonda y suave, para lámparas y para la luz de la habitación.
func textura_radial() -> Texture2D:
	if _textura_radial == null:
		var degradado := Gradient.new()
		degradado.set_color(0, Color.WHITE)
		degradado.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = degradado
		t.width = 256
		t.height = 256
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_textura_radial = t
	return _textura_radial


func _fraccion(a: Array, b: Array) -> float:
	var ancho := float(b[0]) - float(a[0])
	if ancho <= 0.0:
		return 0.0
	return clampf((hora - float(a[0])) / ancho, 0.0, 1.0)


func _tramo(tabla: Array) -> int:
	for i in tabla.size() - 1:
		if hora <= float(tabla[i + 1][0]):
			return i
	return tabla.size() - 2
