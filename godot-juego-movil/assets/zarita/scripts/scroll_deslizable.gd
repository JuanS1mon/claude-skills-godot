extends ScrollContainer
## ScrollContainer que se desliza arrastrando con el dedo o con el mouse (sin usar la barra), con un poco de inercia.
## `horizontal` elige el sentido: true de lado a lado (el inventario), false de arriba abajo (la tienda).
## Las casillas del inventario, que son botones, le pasan sus arrastres con `empujar()` y `soltar()`.
## Las barras se ocultan en la escena (modo de scroll "Nunca mostrar"); la rueda del mouse sigue funcionando.

@export var horizontal: bool = false

## Cuánto hay que mover (px) antes de considerar que es un arrastre y no un toque.
const UMBRAL: float = 10.0
## Qué tan rápido se frena la inercia (más es más rápido).
const FRICCION: float = 5.0
## Por debajo de esta velocidad (px/s) la inercia se detiene.
const VELOCIDAD_MINIMA: float = 25.0

var _presionado: bool = false
var _arrastrando: bool = false
var _inicio: Vector2 = Vector2.ZERO
var _velocidad: float = 0.0
var _ultimo_ms: int = 0
var _inercia: bool = false
var _exacto: float = 0.0


func _gui_input(evento: InputEvent) -> void:
	# En el celular el dedo llega como toque y también como clic del mouse: se usa solo el clic, y se frena el
	# desplazamiento propio de Godot para que no se sume al nuestro.
	if evento is InputEventScreenTouch or evento is InputEventScreenDrag:
		accept_event()
		return
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		if evento.pressed:
			_presionado = true
			_arrastrando = false
			_inicio = evento.position
			_inercia = false
			_velocidad = 0.0
			_ultimo_ms = Time.get_ticks_msec()
		else:
			_presionado = false
			if _arrastrando:
				_arrastrando = false
				soltar()
	elif evento is InputEventMouseMotion and _presionado:
		if not _arrastrando:
			var recorrido: Vector2 = evento.position - _inicio
			if (absf(recorrido.x) if horizontal else absf(recorrido.y)) > UMBRAL:
				_arrastrando = true
		if _arrastrando:
			empujar(evento.relative)
			accept_event()


## Mueve el contenido lo que se movió el dedo. Lo usan también las casillas del inventario.
func empujar(relativo: Vector2) -> void:
	var desplazamiento := relativo.x if horizontal else relativo.y
	_poner(float(scroll_horizontal if horizontal else scroll_vertical) - desplazamiento)
	var ahora := Time.get_ticks_msec()
	var segundos := maxf((ahora - _ultimo_ms) / 1000.0, 0.008)
	_ultimo_ms = ahora
	_velocidad = lerpf(_velocidad, -desplazamiento / segundos, 0.4)
	_inercia = false


## El dedo se levantó: si iba rápido, el contenido sigue deslizándose y se va frenando.
func soltar() -> void:
	_exacto = float(scroll_horizontal if horizontal else scroll_vertical)
	_inercia = absf(_velocidad) > VELOCIDAD_MINIMA and Time.get_ticks_msec() - _ultimo_ms < 120
	if not _inercia:
		_velocidad = 0.0


func _process(delta: float) -> void:
	if not _inercia:
		return
	_poner(_exacto + _velocidad * delta)
	_velocidad *= exp(-FRICCION * delta)
	if absf(_velocidad) < VELOCIDAD_MINIMA:
		_inercia = false


func _poner(valor: float) -> void:
	_exacto = valor
	if horizontal:
		scroll_horizontal = int(roundf(valor))
	else:
		scroll_vertical = int(roundf(valor))
