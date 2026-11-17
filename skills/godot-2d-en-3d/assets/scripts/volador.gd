## Enemigo volador: flota yendo y viniendo a cierta altura; cuando el jugador pasa cerca
## se lanza en picada hacia él y vuelve a subir. Derribado, cae al piso como cualquier objeto.
extends Enemigo

@export var velocidad := 2.5
@export var radio_patrulla := 3.5
## Distancia horizontal a la que ve al jugador y se tira en picada.
@export var rango_vision := 5.0
@export var velocidad_picada := 9.0
@export var enfriamiento_picada := 2.0

var _t := 0.0
var _t_enfriamiento := 0.0
var _objetivo := Vector3.ZERO


func _usa_gravedad() -> bool:
	return false


func _comportamiento(delta: float) -> void:
	_t += delta
	_t_enfriamiento -= delta
	match estado:
		"patrulla":
			if global_position.x < _inicio.x - radio_patrulla:
				_dir = 1.0
			elif global_position.x > _inicio.x + radio_patrulla:
				_dir = -1.0
			# Vuelve a su altura con un vaivén suave.
			var y_deseada := _inicio.y + sin(_t * 2.5) * 0.4
			velocity = Vector3(_dir * velocidad, (y_deseada - global_position.y) * 4.0, 0.0)
			_animar("volar")
			var jug := _jugador()
			if jug and _t_enfriamiento <= 0.0:
				var d := jug.global_position - global_position
				if absf(d.x) < rango_vision and d.y < 0.0 and d.y > -8.0:
					_objetivo = jug.global_position + Vector3(0.0, 0.9, 0.0)
					_dir = signf(d.x) if d.x != 0.0 else _dir
					_cambiar("avisar", 0.4)
		"avisar":
			# Un instante quieto antes de tirarse: da tiempo a esquivar.
			velocity = Vector3(0.0, 1.5, 0.0)
			_animar("volar")
		"picada":
			_animar("picada")
			if _t_estado <= 0.0 or is_on_floor() or is_on_wall():
				_t_enfriamiento = enfriamiento_picada
				_cambiar("patrulla", 0.0)
	if estado == "avisar" and _t_estado <= 0.0:
		velocity = (_objetivo - global_position).normalized() * velocidad_picada
		_cambiar("picada", 0.9)
