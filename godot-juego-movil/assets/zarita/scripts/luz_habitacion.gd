class_name LuzHabitacion
extends Node2D
## Luz interior de la habitación: cálida, y mucho más visible de noche, para que contraste con la luz fría de la luna.

@export var radio: float = 520.0
@export var color_luz: Color = Color(1.0, 0.84, 0.58)

var encendida: bool = true

@onready var _luz: PointLight2D = $Luz


func _ready() -> void:
	add_to_group("luz_habitacion")
	_luz.texture = CicloDia.textura_radial()
	_luz.texture_scale = radio * 2.0 / 256.0
	_luz.color = color_luz
	_luz.energy = 0.0


func set_encendida(valor: bool) -> void:
	encendida = valor


## Cuánta luz da ahora, de 0 a 1. Las sombras de los objetos la consultan.
func intensidad() -> float:
	return clampf(_luz.energy / 0.7, 0.0, 1.0)


func _process(_delta: float) -> void:
	var oscuridad := CicloDia.oscuridad()
	var objetivo := (0.05 + 0.65 * oscuridad) if encendida else 0.0
	_luz.energy = lerpf(_luz.energy, objetivo, 0.1)   # cambio suave al apagar o encender
