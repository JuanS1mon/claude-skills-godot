@tool
class_name ReproductorMusica
extends Mueble
## Mueble que controla la música (caja musical, radio, reproductor moderno...).
## Cada toque, fuera del modo Decorar, pasa por apagado -> pista 1 -> pista 2 -> ... -> apagado.
## Un letrero sobre el mueble dice qué suena. La música en sí vive en el autoload Musica.

const SEGUNDOS_LETRERO: float = 2.0

var _letrero: Label
var _tween_letrero: Tween


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	# La casa cuenta los miembros de este grupo para saber si hay música permitida.
	add_to_group("reproductores")
	_crear_letrero()


func al_tocar() -> void:
	Musica.siguiente_estado()
	_mostrar_letrero()


## Letrero flotante sobre el mueble. Se crea por código porque su altura depende del tamaño de la ficha.
func _crear_letrero() -> void:
	_letrero = Label.new()
	_letrero.mouse_filter = Control.MOUSE_FILTER_IGNORE   # que no bloquee los clics al mueble
	_letrero.custom_minimum_size = Vector2(260, 0)
	_letrero.position = Vector2(-130, -tamano.y - 44)
	_letrero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letrero.add_theme_font_size_override("font_size", 22)
	_letrero.add_theme_color_override("font_color", Color.WHITE)
	_letrero.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_letrero.add_theme_constant_override("outline_size", 6)
	_letrero.z_index = 100   # por encima de los demás muebles, aunque estén "delante" por su Y
	_letrero.modulate.a = 0.0
	add_child(_letrero)


func _mostrar_letrero() -> void:
	_letrero.text = Musica.nombre_estado() if Musica.estado == 0 else "Suena: " + Musica.nombre_estado()
	if _tween_letrero:
		_tween_letrero.kill()
	_letrero.modulate.a = 1.0
	_tween_letrero = create_tween()
	_tween_letrero.tween_interval(SEGUNDOS_LETRERO)
	_tween_letrero.tween_property(_letrero, "modulate:a", 0.0, 0.5)
