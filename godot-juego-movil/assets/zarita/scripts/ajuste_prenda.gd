@tool
extends Node2D
## Para ajustar a ojo cómo le queda una prenda a Zarita. Muestra sus cuatro vistas (frente, espalda, derecha e izquierda) con la
## prenda encima. En el editor, mueve y agranda el nodo `Capa` de cada vista (con las herramientas Mover y Escalar, o en el Inspector:
## Position y Scale) hasta que quede bien, y marca `guardar_en_ficha`: copia esos valores a la ficha de la prenda (PrendaData:
## desplazamiento_* y escala_*), que usa el juego (RopaZarita). Para ver otra prenda, cambia `ficha` y marca `volver_a_cargar`.
## Las medidas son las de los cuadros de Zarita (en el juego se dibuja a escala 0,25).

const DIRECCIONES: Array[String] = ["abajo", "arriba", "derecha", "izquierda"]

## La prenda que se ajusta (data/prendas/*.tres).
@export var ficha: PrendaData
## Márcalo para guardar la posición y el tamaño de las cuatro capas en la ficha (se desmarca solo).
@export var guardar_en_ficha: bool = false:
	set(valor):
		if valor and Engine.is_editor_hint() and is_node_ready():
			_guardar()
		guardar_en_ficha = false
## Márcalo para volver a poner las capas como las tiene la ficha (descarta lo que hayas movido).
@export var volver_a_cargar: bool = false:
	set(valor):
		if valor and is_node_ready():
			_cargar()
		volver_a_cargar = false


func _ready() -> void:
	_cargar()


func _capa(direccion: String) -> Sprite2D:
	return get_node_or_null("Vista%s/Zarita/Capa" % direccion.capitalize()) as Sprite2D


## Pone cada capa con su imagen y los valores que guarda la ficha.
func _cargar() -> void:
	if ficha == null:
		return
	for direccion in DIRECCIONES:
		var capa := _capa(direccion)
		if capa == null:
			continue
		var animacion := StringName("caminar_" + direccion)
		capa.texture = ficha.capa_para(animacion)
		capa.position = ficha.desplazamiento_para(animacion)
		capa.scale = ficha.escala_para(animacion)


func _guardar() -> void:
	if ficha == null or ficha.resource_path == "":
		push_warning("No hay ficha que guardar.")
		return
	for direccion in DIRECCIONES:
		var capa := _capa(direccion)
		if capa == null:
			continue
		ficha.set("desplazamiento_" + direccion, capa.position)
		ficha.set("escala_" + direccion, capa.scale)
	var error := ResourceSaver.save(ficha, ficha.resource_path)
	print("Ajuste de %s guardado (%s)." % [ficha.nombre, error_string(error)])
