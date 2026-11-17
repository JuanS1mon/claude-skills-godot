@tool
class_name PavaMate
extends Mueble
## La pava silbadora de la cocina. Tocarla (fuera del modo Decorar) calienta el agua del mate: llena las cebadas de Mate.
## El botón Agua de la interfaz solo funciona si hay una pava en la habitación. Un letrero sobre ella lo confirma.

## Tocarla abre el minijuego del mate (la casa lo conecta: casa.gd::_ir_a_mate).
signal pedido_preparar

const SEGUNDOS_LETRERO: float = 2.0

var _letrero: Label
var _tween_letrero: Tween


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	add_to_group("pavas")
	_crear_letrero()


func al_tocar() -> void:
	if not pedido_preparar.get_connections().is_empty():
		pedido_preparar.emit()
		return
	Mate.calentar_agua()
	_mostrar_letrero("Agua caliente lista")


## Letrero flotante sobre la pava (se crea por código porque su altura depende del tamaño de la ficha).
func _crear_letrero() -> void:
	_letrero = Label.new()
	_letrero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letrero.custom_minimum_size = Vector2(260, 0)
	_letrero.position = Vector2(-130, -tamano.y - 44)
	_letrero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letrero.add_theme_font_size_override("font_size", 22)
	_letrero.add_theme_color_override("font_color", Color.WHITE)
	_letrero.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_letrero.add_theme_constant_override("outline_size", 6)
	_letrero.z_index = 100
	_letrero.modulate.a = 0.0
	add_child(_letrero)


func _mostrar_letrero(texto: String) -> void:
	_letrero.text = texto
	if _tween_letrero:
		_tween_letrero.kill()
	_letrero.modulate.a = 1.0
	_tween_letrero = create_tween()
	_tween_letrero.tween_interval(SEGUNDOS_LETRERO)
	_tween_letrero.tween_property(_letrero, "modulate:a", 0.0, 0.5)
