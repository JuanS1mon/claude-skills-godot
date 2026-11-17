class_name RopaZarita
extends Node2D
## Pone sobre Zarita la prenda que lleva puesta (Ropero.puesta): instancia la escena de su ficha (PrendaData.crear_prenda) como
## hija. Es hija de Zarita, así que su origen son los pies. Se actualiza con `refrescar()` (grupo "ropa_zarita").

var _actual: Node2D


func _ready() -> void:
	add_to_group("ropa_zarita")
	z_index = 1   # por encima de su cuerpo
	refrescar()


func refrescar() -> void:
	if _actual != null:
		_actual.queue_free()
		_actual = null
	var ficha := Ropero.prenda_puesta()
	if ficha == null or ficha.escena == null:
		return
	_actual = ficha.crear_prenda()
	add_child(_actual)
