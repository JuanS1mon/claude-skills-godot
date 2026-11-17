class_name BolsaYerba
extends Node2D
## La bolsa de yerba del minijuego del mate: mantenerla apretada llena el mate. Su origen es la esquina de arriba a la
## izquierda; `tamano` debe coincidir con el `Fondo`.

@export var tamano: Vector2 = Vector2(190.0, 120.0)
## Cuánto se inclina la bolsa al verter (radianes, hacia el mate) y dónde queda su boca respecto de la boca del mate.
@export var inclinacion: float = 1.5
@export var boca_sobre_mate: Vector2 = Vector2(-20.0, -70.0)

## Punto de la imagen (sin escala) por donde sale la yerba: el borde de arriba.
const BOCA_LOCAL := Vector2(0.0, -45.0)

var _pos_reposo: Vector2
var _tween: Tween

@onready var _imagen: Sprite2D = $Imagen


func _ready() -> void:
	_pos_reposo = _imagen.position


func contiene(punto_global: Vector2) -> bool:
	return Rect2(global_position, tamano).has_point(punto_global)


## Por dónde caen los granos (la boca de la bolsa, que sigue a la imagen al inclinarse).
func salida_global() -> Vector2:
	return _imagen.to_global(BOCA_LOCAL)


## La bolsa se levanta y se inclina sobre el mate (`boca_mate`, global) o vuelve a su lugar.
func verter(activa: bool, boca_mate: Vector2) -> void:
	var pos := _pos_reposo
	var giro := 0.0
	if activa:
		giro = inclinacion
		var boca_rotada := (BOCA_LOCAL * _imagen.scale).rotated(giro)
		pos = to_local(boca_mate) + boca_sobre_mate - boca_rotada
	z_index = 1 if activa else 0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_imagen, "position", pos, 0.3)
	_tween.tween_property(_imagen, "rotation", giro, 0.3)
