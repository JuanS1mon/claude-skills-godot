@tool
class_name BarraMedidor
extends Control
## Barra de medición para el minijuego del mate (temperatura del agua, nivel de yerba). Se ve en el editor: ajustá el tamaño
## de la instancia, `vertical` (se llena de abajo hacia arriba), la zona buena en verde (`zona_ini`..`zona_fin`, de 0 a 100)
## y una `marca` (línea blanca; -1 = sin marca). `fijar(valor)` mueve el relleno; `fijar_color` lo tiñe.

@export var vertical: bool = false:
	set(v):
		vertical = v
		_actualizar()
@export_range(0.0, 100.0) var zona_ini: float = 70.0:
	set(v):
		zona_ini = v
		_actualizar()
@export_range(0.0, 100.0) var zona_fin: float = 80.0:
	set(v):
		zona_fin = v
		_actualizar()
@export_range(-1.0, 100.0) var marca: float = -1.0:
	set(v):
		marca = v
		_actualizar()
@export_range(0.0, 100.0) var valor: float = 0.0:
	set(v):
		valor = v
		_actualizar()
@export var titulo: String = "":
	set(v):
		titulo = v
		_actualizar()


func _ready() -> void:
	resized.connect(_actualizar)
	_actualizar()


func fijar(nuevo: float) -> void:
	valor = clampf(nuevo, 0.0, 100.0)


func fijar_color(color: Color) -> void:
	$Relleno.color = color


## Coloca una franja entre `ini` y `fin` (0 a 1) a lo largo de la barra.
func _franja(nodo: ColorRect, ini: float, fin: float) -> void:
	if vertical:
		nodo.position = Vector2(0.0, size.y * (1.0 - fin))
		nodo.size = Vector2(size.x, size.y * (fin - ini))
	else:
		nodo.position = Vector2(size.x * ini, 0.0)
		nodo.size = Vector2(size.x * (fin - ini), size.y)


func _actualizar() -> void:
	if not is_node_ready():
		return
	_franja($Zona, zona_ini / 100.0, zona_fin / 100.0)
	_franja($Relleno, 0.0, valor / 100.0)
	var m := $Marca as ColorRect
	m.visible = marca >= 0.0
	if m.visible:
		var punto := marca / 100.0
		if vertical:
			m.position = Vector2(-10.0, size.y * (1.0 - punto) - 2.0)
			m.size = Vector2(size.x + 20.0, 4.0)
		else:
			m.position = Vector2(size.x * punto - 2.0, -10.0)
			m.size = Vector2(4.0, size.y + 20.0)
	($Titulo as Label).text = titulo
