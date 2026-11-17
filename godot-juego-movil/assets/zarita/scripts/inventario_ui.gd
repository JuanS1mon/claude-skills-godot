extends PanelContainer
## Panel del inventario: una casilla por cada ficha que tiene el jugador. Se desliza de lado con el dedo o el mouse
## (ver scroll_deslizable.gd) y se ilumina el borde cuando se arrastra un mueble encima para guardarlo.

signal ficha_elegida(ficha: MuebleData)

@export var escena_slot: PackedScene

@onready var _lista: HBoxContainer = $Scroll/Lista
## Sin tipo: es un ScrollContainer con su propio script (empujar, soltar).
@onready var _scroll = $Scroll
@onready var _resplandor: Panel = $Resplandor

var _tween: Tween


func _ready() -> void:
	_resplandor.visible = false   # en el editor se ve encendido para poder diseñarlo
	Inventario.cambio.connect(_redibujar)
	_redibujar()


func _redibujar() -> void:
	for hijo in _lista.get_children():
		hijo.queue_free()
	# Los muebles iguales se agrupan en una sola casilla con su cantidad: el inventario no se llena de repetidos.
	var cantidades: Dictionary = {}
	var orden: Array[MuebleData] = []
	for ficha in Inventario.muebles:
		if not cantidades.has(ficha):
			cantidades[ficha] = 0
			orden.append(ficha)
		cantidades[ficha] += 1
	for ficha in orden:
		var slot := escena_slot.instantiate() as SlotMueble
		_lista.add_child(slot)
		slot.configurar(ficha, cantidades[ficha])
		slot.seleccionado.connect(ficha_elegida.emit)
		slot.desplazado.connect(_scroll.empujar)
		slot.liberado.connect(_scroll.soltar)


## Enciende (o apaga) el resplandor del borde: avisa de que soltar el mueble aquí lo guarda en el inventario.
func resaltar(activo: bool) -> void:
	if activo == _resplandor.visible:
		return
	if _tween != null:
		_tween.kill()
	_resplandor.visible = activo
	if not activo:
		return
	# Late suave mientras el mueble siga encima.
	_resplandor.modulate.a = 1.0
	_tween = create_tween().set_loops()
	_tween.tween_property(_resplandor, "modulate:a", 0.45, 0.4).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_resplandor, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
