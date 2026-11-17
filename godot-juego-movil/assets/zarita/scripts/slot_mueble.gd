class_name SlotMueble
extends Button
## Casilla del inventario: muestra la imagen (o el color) y el nombre de una ficha.
## Tocarla y arrastrar hacia los lados desliza la lista; arrastrar hacia arriba, o mantenerla apretada un momento,
## saca el mueble para ponerlo en la casa.

## Se emite cuando el jugador saca el mueble de la lista.
signal seleccionado(ficha: MuebleData)
## Mientras el dedo desliza la lista (movimiento relativo), y cuando se levanta.
signal desplazado(relativo: Vector2)
signal liberado

## Cuánto hay que mover el dedo (px) para decidir si es un deslizamiento o sacar el mueble.
const UMBRAL: float = 12.0
## Cuánto hay que mantener apretado (segundos) para sacar el mueble sin moverlo.
const SEGUNDOS_MANTENER: float = 0.35

var ficha: MuebleData

var _presionado: bool = false
var _deslizando: bool = false
var _inicio: Vector2 = Vector2.ZERO
var _temporizador: Timer


func _ready() -> void:
	_temporizador = Timer.new()
	_temporizador.one_shot = true
	_temporizador.wait_time = SEGUNDOS_MANTENER
	_temporizador.timeout.connect(_al_mantener)
	add_child(_temporizador)


## `cantidad` > 1 cuando hay varios iguales en el inventario: se muestran juntos, p. ej. "Silla  ×3".
func configurar(nueva: MuebleData, cantidad: int = 1) -> void:
	ficha = nueva
	$VBox/Nombre.text = ficha.nombre if cantidad <= 1 else "%s  ×%d" % [ficha.nombre, cantidad]
	var tiene_imagen := ficha.imagen() != null
	$VBox/Imagen.visible = tiene_imagen
	$VBox/Muestra.visible = not tiene_imagen
	$VBox/Imagen.texture = ficha.imagen()
	$VBox/Muestra.color = ficha.color


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		if evento.pressed:
			_presionado = true
			_deslizando = false
			_inicio = evento.global_position
			_temporizador.start()
		else:
			_terminar_toque()
	elif evento is InputEventMouseMotion and _presionado:
		if _deslizando:
			desplazado.emit(evento.relative)
			return
		var recorrido: Vector2 = evento.global_position - _inicio
		if absf(recorrido.x) > UMBRAL and absf(recorrido.x) > absf(recorrido.y):
			_deslizando = true
			_temporizador.stop()
			desplazado.emit(Vector2(recorrido.x, 0.0))   # lo que ya se movió antes de decidir
		elif recorrido.y < -UMBRAL:
			_sacar()


func _al_mantener() -> void:
	if _presionado and not _deslizando:
		_sacar()


func _sacar() -> void:
	_presionado = false
	_temporizador.stop()
	seleccionado.emit(ficha)


func _terminar_toque() -> void:
	_temporizador.stop()
	if _presionado and _deslizando:
		liberado.emit()
	_presionado = false
	_deslizando = false
