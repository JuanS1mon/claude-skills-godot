extends Control
## Ventana para confirmar la venta de un mueble: muestra qué es y cuánto dan. "Vender" lo cobra; "Guardar" lo manda
## al inventario. Ocupa toda la pantalla (oscurece el fondo y bloquea los toques de abajo).

signal vendido
signal guardado

@onready var _imagen: TextureRect = $Panel/Caja/Imagen
@onready var _nombre: Label = $Panel/Caja/Nombre
@onready var _precio: Label = $Panel/Caja/Precio


func _ready() -> void:
	visible = false   # en el editor se ve abierta para poder diseñarla
	$Panel/Caja/Botones/BotonVender.pressed.connect(_responder.bind(true))
	$Panel/Caja/Botones/BotonGuardar.pressed.connect(_responder.bind(false))


## Abre la ventana para la ficha dada.
func preguntar(ficha: MuebleData) -> void:
	_imagen.texture = ficha.imagen()
	_imagen.visible = ficha.imagen() != null
	_nombre.text = ficha.nombre
	var unidad := "gemas" if ficha.moneda == MuebleData.Moneda.GEMAS else "monedas"
	_precio.text = "Te dan %d %s" % [ficha.precio_venta(), unidad]
	visible = true


func _responder(vender: bool) -> void:
	visible = false
	if vender:
		vendido.emit()
	else:
		guardado.emit()
