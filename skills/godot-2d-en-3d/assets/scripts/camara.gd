## Cámara lateral que sigue al objetivo con suavizado y mira un poco hacia adelante.
extends Camera3D

@export var objetivo: Node3D
@export var distancia := Vector3(0.0, 3.0, 10.5)
@export var suavizado := 5.0
@export var adelanto := 1.5

var _sacudida := 0.0


## Sacudida corta (golpes del jefe, impactos fuertes).
func sacudir(fuerza: float) -> void:
	_sacudida = maxf(_sacudida, fuerza)


func _ready() -> void:
	if objetivo:
		global_position = objetivo.global_position + distancia


func _physics_process(delta: float) -> void:
	if not objetivo:
		return
	var mira := 0.0
	if "mirando" in objetivo:
		mira = objetivo.mirando * adelanto
	var destino := objetivo.global_position + distancia + Vector3(mira, 0.0, 0.0)
	global_position = global_position.lerp(destino, 1.0 - exp(-suavizado * delta))
	if _sacudida > 0.0:
		_sacudida = maxf(_sacudida - delta, 0.0)
		global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * _sacudida * 0.35
