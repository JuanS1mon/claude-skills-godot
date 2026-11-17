class_name Clima
extends Node
## Clima del juego. Lo crea CicloDia (no es un autoload aparte) y se usa como `CicloDia.clima`.
## Cada clima es un conjunto de valores de 0 a 1 que cambian poco a poco hacia su objetivo:
## nubes, lluvia, nieve, hojas, viento y calor. Los consultan las ventanas (lo que se ve por el cristal),
## CicloDia (luz ambiente) y las luces. Con lluvia caen relámpagos que iluminan toda la casa.

enum Tipo { DESPEJADO, NUBLADO, LLUVIA, CALOR, OTONO, NIEVE, VIENTO }

const NOMBRES: Array[String] = ["Despejado", "Nublado", "Lluvia", "Calor", "Otoño", "Nieve", "Viento"]
## Segundos que dura cada clima en modo automático.
const SEGUNDOS_POR_CLIMA: float = 150.0
## Qué tan rápido pasa de un clima a otro (por segundo).
const VELOCIDAD_CAMBIO: float = 0.5
const CENTRO_CASA: Vector2 = Vector2(360, 640)
const RADIO_RELAMPAGO: float = 950.0
const COLOR_RELAMPAGO: Color = Color(0.80, 0.88, 1.0)
## Cada cuántos segundos cae un relámpago durante la lluvia: mínimo y máximo.
const ESPERA_RELAMPAGO_MIN: float = 5.0
const ESPERA_RELAMPAGO_MAX: float = 13.0

## Se emite cuando cambia el modo (automático o fijo) o el clima actual.
signal modo_cambiado

## Valores objetivo de cada clima, en el orden de Tipo. Lo que no aparece vale 0.
var _objetivos: Array = [
	{},                                                                   # despejado
	{"nubes": 1.0},                                                       # nublado
	{"nubes": 1.0, "lluvia": 1.0, "viento": 0.25},                        # lluvia (con relámpagos)
	{"calor": 1.0},                                                       # calor
	{"nubes": 0.35, "hojas": 1.0, "viento": 0.35},                        # otoño
	{"nubes": 0.8, "nieve": 1.0},                                         # nieve
	{"nubes": 0.35, "viento": 1.0, "hojas": 0.4},                         # viento
]
## Probabilidad relativa de cada clima en modo automático.
var _pesos: Array[float] = [3.0, 2.0, 2.0, 1.0, 1.0, 1.0, 1.0]

var tipo: int = Tipo.DESPEJADO
var automatico: bool = true
var nubes: float = 0.0
var lluvia: float = 0.0
var nieve: float = 0.0
var hojas: float = 0.0
var viento: float = 0.0
var calor: float = 0.0
## Destello del relámpago ahora mismo, de 0 a 1.
var relampago: float = 0.0
## true si hay alguna ventana: sin ventanas, la luz del relámpago no entra a la casa.
var hay_ventanas: bool = false

var _modo: int = -1   # -1 = automático; 0 en adelante = un clima fijo
var _restante: float = SEGUNDOS_POR_CLIMA
var _proximo_relampago: float = 6.0
var _luz: PointLight2D
var _tween_relampago: Tween


func _ready() -> void:
	# Luz del relámpago: cubre la casa entera. Su energía sigue al destello.
	var degradado := Gradient.new()
	degradado.set_color(0, Color.WHITE)
	degradado.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.width = 256
	textura.height = 256
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	_luz = PointLight2D.new()
	_luz.texture = textura
	_luz.texture_scale = RADIO_RELAMPAGO * 2.0 / 256.0
	_luz.color = COLOR_RELAMPAGO
	_luz.energy = 0.0
	_luz.position = CENTRO_CASA
	add_child(_luz)


func _process(delta: float) -> void:
	if automatico:
		_restante -= delta
		if _restante <= 0.0:
			_elegir_al_azar()
	var objetivo: Dictionary = _objetivos[tipo]
	var paso := VELOCIDAD_CAMBIO * delta
	nubes = move_toward(nubes, float(objetivo.get("nubes", 0.0)), paso)
	lluvia = move_toward(lluvia, float(objetivo.get("lluvia", 0.0)), paso)
	nieve = move_toward(nieve, float(objetivo.get("nieve", 0.0)), paso)
	hojas = move_toward(hojas, float(objetivo.get("hojas", 0.0)), paso)
	viento = move_toward(viento, float(objetivo.get("viento", 0.0)), paso)
	calor = move_toward(calor, float(objetivo.get("calor", 0.0)), paso)

	hay_ventanas = get_tree().get_nodes_in_group("ventanas").size() > 0
	if tipo == Tipo.LLUVIA and lluvia > 0.7:
		_proximo_relampago -= delta
		if _proximo_relampago <= 0.0:
			disparar_relampago()
			_proximo_relampago = randf_range(ESPERA_RELAMPAGO_MIN, ESPERA_RELAMPAGO_MAX)
	_luz.energy = relampago * 2.6 if hay_ventanas else 0.0


## Pasa al siguiente modo: automático, y luego cada clima fijo. Es lo que hace el botón Clima.
func ciclar() -> void:
	_modo += 1
	if _modo >= NOMBRES.size():
		_modo = -1
	automatico = _modo == -1
	if automatico:
		_restante = 0.0
	else:
		tipo = _modo
	modo_cambiado.emit()


func texto_modo() -> String:
	if automatico:
		return "Auto · " + NOMBRES[tipo]
	return NOMBRES[tipo]


## Un relámpago: dos destellos rápidos y un apagado largo. Lo dispara solo la lluvia, pero se puede llamar a mano.
func disparar_relampago() -> void:
	if _tween_relampago != null:
		_tween_relampago.kill()
	_tween_relampago = create_tween()
	_tween_relampago.tween_property(self, "relampago", 1.0, 0.04)
	_tween_relampago.tween_property(self, "relampago", 0.15, 0.08)
	_tween_relampago.tween_property(self, "relampago", 0.75, 0.04)
	_tween_relampago.tween_property(self, "relampago", 0.0, 0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


# --- Lo que el clima cambia en el resto del juego ---

## Tinte de toda la casa: nublado y lluvia la oscurecen, la nieve la aclara con un tono azulado,
## el calor y el otoño la calientan.
func mult_ambiente() -> Color:
	var c := Color(1.0, 1.0, 1.0)
	c = c.lerp(Color(0.52, 0.55, 0.62), nubes * 0.9)
	c = c.lerp(Color(0.42, 0.47, 0.60), lluvia * 0.7)
	c = c.lerp(Color(0.92, 0.96, 1.00), nieve * 0.6)
	c = c.lerp(Color(1.00, 0.93, 0.78), calor * 0.8)
	c = c.lerp(Color(1.00, 0.86, 0.68), hojas * 0.35)
	return c


## Cuánto sol llega: casi nada con nubes, y más con calor.
func factor_sol() -> float:
	return clampf(1.0 - 0.9 * nubes, 0.0, 1.0) * (1.0 + 0.35 * calor)


## Tinte del cielo que se ve por la ventana.
func tinte_cielo() -> Color:
	var c := Color(1.0, 1.0, 1.0)
	c = c.lerp(Color(0.48, 0.50, 0.56), nubes * 0.95)
	c = c.lerp(Color(0.40, 0.42, 0.50), lluvia * 0.6)
	c = c.lerp(Color(0.88, 0.92, 1.00), nieve * 0.6)
	c = c.lerp(Color(1.00, 0.95, 0.80), calor * 0.7)
	c = c.lerp(Color(1.00, 0.90, 0.75), hojas * 0.3)
	return c


## Oscuridad que añaden las nubes, para que las lámparas se enciendan también de día en un día gris.
func oscuridad_extra() -> float:
	return nubes * 0.55


## 1 si el relámpago puede entrar a la casa (hay ventanas), 0 si no.
func factor_ventanas() -> float:
	return 1.0 if hay_ventanas else 0.0


func _elegir_al_azar() -> void:
	var total := 0.0
	for p in _pesos:
		total += p
	var sorteo := randf() * total
	var elegido := tipo
	for i in _pesos.size():
		sorteo -= _pesos[i]
		if sorteo <= 0.0:
			elegido = i
			break
	if elegido == tipo:
		elegido = (tipo + 1) % NOMBRES.size()   # que no se repita el mismo clima dos veces seguidas
	tipo = elegido
	_restante = SEGUNDOS_POR_CLIMA
	modo_cambiado.emit()
