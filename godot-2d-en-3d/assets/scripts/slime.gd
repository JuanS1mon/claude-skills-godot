## Slime: avanza a los saltitos. Si ve al jugador salta hacia él; si no, va y viene.
extends Enemigo

@export var radio_patrulla := 3.5
@export var rango_vision := 7.0
## Segundos quieto entre salto y salto.
@export var pausa_entre_saltos := 0.9
@export var salto := Vector2(3.5, 8.0)

var _t_pausa := 0.5


func _comportamiento(delta: float) -> void:
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		_animar("quieto")
		_t_pausa -= delta
		if _t_pausa <= 0.0:
			_t_pausa = pausa_entre_saltos
			var jug := _jugador()
			if jug and absf(jug.global_position.x - global_position.x) < rango_vision \
					and absf(jug.global_position.y - global_position.y) < 4.0:
				_dir = signf(jug.global_position.x - global_position.x)
			elif global_position.x < _inicio.x - radio_patrulla:
				_dir = 1.0
			elif global_position.x > _inicio.x + radio_patrulla:
				_dir = -1.0
			velocity = Vector3(_dir * salto.x, salto.y, 0.0)
	else:
		_animar("saltar")
		if is_on_wall():
			_dir = -_dir
