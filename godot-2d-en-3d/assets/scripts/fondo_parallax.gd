## Fondo pintado lejano que acompaña a la cámara con parallax:
## se mueve una fracción de lo que se mueve la cámara, así parece estar muy lejos.
extends MeshInstance3D

@export var camara: Camera3D
## 1 = queda pegado a la cámara (infinitamente lejos); 0 = quieto como el resto del mundo.
@export_range(0.0, 1.0) var seguimiento := 0.85

var _inicial := Vector3.ZERO
var _cam_inicial := Vector3.ZERO


func _ready() -> void:
	_inicial = position
	if camara:
		_cam_inicial = camara.global_position


func _process(_delta: float) -> void:
	if camara:
		position.x = _inicial.x + camara.global_position.x * seguimiento
		# En vertical lo sigue casi entero: al trepar la chimenea no se ve el borde del cuadro.
		position.y = _inicial.y + (camara.global_position.y - _cam_inicial.y) * 0.9
