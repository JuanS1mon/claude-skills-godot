extends Node2D
## Una prenda puesta sobre Zarita, como un mueble hecho de datos: la escena base (scenes/prenda.tscn) y sus variantes
## (scenes/prendas/*.tscn) se ven con formas de color (nodos del grupo "tinte" y "tinte_borde") hasta que haya arte; la ficha
## PrendaData le pone color, posición y escala, y su `frames` o `textura` reemplaza las formas por la imagen (animada si trae
## varios cuadros). El origen es el de Zarita: sus pies. Sola (F6) se muestra en el centro de la pantalla.

var ficha: PrendaData

@onready var _forma: Node2D = $Forma
@onready var _imagen: AnimatedSprite2D = $Imagen


func _ready() -> void:
	if get_parent() == get_tree().root:   # escena suelta (F6)
		position = get_viewport_rect().size / 2.0 + Vector2(0.0, 64.0)
	aplicar()


## Pone en la escena lo que dice la ficha (si la hay).
func aplicar() -> void:
	if ficha != null:
		position = ficha.posicion
		scale = Vector2.ONE * ficha.escala
		for nodo in _forma.find_children("*", "Polygon2D"):
			if nodo.is_in_group("tinte"):
				(nodo as Polygon2D).color = ficha.color
			elif nodo.is_in_group("tinte_borde"):
				(nodo as Polygon2D).color = ficha.color_borde
		var cuadros := ficha.frames_prenda()
		if cuadros != null:
			_imagen.sprite_frames = cuadros
	if _imagen.sprite_frames != null:
		_forma.visible = false
		_imagen.play("default")
