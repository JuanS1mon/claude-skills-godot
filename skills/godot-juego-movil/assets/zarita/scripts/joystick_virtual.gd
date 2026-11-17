@tool
extends Control
## Joystick virtual para mover a Zarita con el pulgar. Se arrastra desde el centro; cuanto más lejos, más rápido camina.
## Es @tool para que se dibuje también en el editor; el nodo está en el grupo "joystick" (así lo encuentra Zarita).
## Funciona con el mouse y con el dedo (en Android el toque se convierte en clic del mouse). Zarita lee `direccion`.

## Alcance de la palanca desde el centro, en píxeles, y radio del círculo que se mueve.
const RADIO: float = 110.0
const RADIO_PALANCA: float = 48.0
## Por debajo de esta fuerza (0 a 1) se considera que el pulgar está quieto.
const ZONA_MUERTA: float = 0.18
const CREMA: Color = Color(1.0, 0.945, 0.86)
const MARRON: Color = Color(0.455, 0.267, 0.259)
const ROSA: Color = Color(0.957, 0.627, 0.675)

## Hacia dónde se empuja, de longitud 0 a 1 (Vector2.ZERO si está quieto o escondido).
var direccion: Vector2 = Vector2.ZERO

var _tocando: bool = false
var _palanca: Vector2 = Vector2.ZERO   # desplazamiento de la palanca respecto del centro


func _ready() -> void:
	visibility_changed.connect(_al_cambiar_visibilidad)


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		_tocando = evento.pressed
		if _tocando:
			_empujar(evento.position)
		else:
			_soltar()
	elif evento is InputEventMouseMotion and _tocando:
		_empujar(evento.position)   # mientras el dedo siga apretado, llegan aunque se salga del círculo


func _empujar(posicion: Vector2) -> void:
	_palanca = (posicion - size / 2.0).limit_length(RADIO)
	var fuerza := _palanca.length() / RADIO
	direccion = _palanca / RADIO if fuerza > ZONA_MUERTA else Vector2.ZERO
	queue_redraw()


func _soltar() -> void:
	_tocando = false
	_palanca = Vector2.ZERO
	direccion = Vector2.ZERO
	queue_redraw()


func _al_cambiar_visibilidad() -> void:
	if not visible:
		_soltar()


func _draw() -> void:
	var centro := size / 2.0
	var alfa := 0.75 if _tocando else 0.5
	# Base: círculo crema con borde marrón, como los marcos del resto de la interfaz.
	draw_circle(centro, RADIO, Color(CREMA, alfa * 0.6))
	draw_arc(centro, RADIO, 0.0, TAU, 48, Color(MARRON, alfa), 6.0, true)
	# Palanca: círculo rosa con su borde y un brillo.
	var punto := centro + _palanca
	draw_circle(punto, RADIO_PALANCA, Color(ROSA, alfa + 0.2))
	draw_arc(punto, RADIO_PALANCA, 0.0, TAU, 32, Color(MARRON, alfa + 0.2), 5.0, true)
	draw_circle(punto + Vector2(-14, -16), 8.0, Color(1, 1, 1, 0.6))
