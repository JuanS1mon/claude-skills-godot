## Escarabajo: patrulla, ve al jugador, se frena, apunta y le dispara una bola de energía.
## Cuando le pegan se ESCONDE en el caparazón un rato: las balas comunes le rebotan
## (lo dañan el golpe, las cajas, los enemigos arrojados y el disparo cargado al máximo).
## Nodos extra: Boca (Marker3D).
extends Enemigo

@export var velocidad := 2.0
## Distancia que patrulla a cada lado de donde arranca.
@export var radio_patrulla := 4.0
@export var rango_vision := 9.0
@export var cadencia := 1.8
@export var velocidad_proyectil := 9.0
@export var escena_proyectil: PackedScene
## Segundos que se queda escondido en el caparazón después de recibir un golpe.
@export var tiempo_escondido := 2.2

@onready var boca: Marker3D = $Boca

var _t_enfriamiento := 0.0
var _boca_x := 0.0


func _ready() -> void:
	super()
	_boca_x = absf(boca.position.x)


func _comportamiento(delta: float) -> void:
	_t_enfriamiento -= delta
	match estado:
		"patrulla":
			velocity.x = _dir * velocidad
			if global_position.x < _inicio.x - radio_patrulla:
				_dir = 1.0
			elif global_position.x > _inicio.x + radio_patrulla:
				_dir = -1.0
			if is_on_wall():
				_dir = signf(get_wall_normal().x) if get_wall_normal().x != 0.0 else -_dir
			_buscar_jugador()
			_animar("caminar")
		"apuntar":
			velocity.x = 0.0
			_animar("apuntar")
			if _t_estado <= 0.0:
				_disparar()
				_cambiar("disparar", 0.3)
		"disparar":
			velocity.x = 0.0
			_animar("disparar")
			if _t_estado <= 0.0:
				_cambiar("patrulla", 0.0)
		"escondido":
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			_animar("escondido")
			if _t_estado <= 0.0:
				_cambiar("patrulla", 0.0)
	boca.position.x = _boca_x * _dir


func _tras_golpe() -> void:
	_cambiar("escondido", tiempo_escondido)


func rebota_balas() -> bool:
	return estado == "escondido"


func _buscar_jugador() -> void:
	if _t_enfriamiento > 0.0:
		return
	var jug := _jugador()
	if jug == null:
		return
	var d := jug.global_position - global_position
	if absf(d.x) < rango_vision and absf(d.y) < 3.0:
		_dir = signf(d.x)
		_cambiar("apuntar", 0.45)


func _disparar() -> void:
	_t_enfriamiento = cadencia
	var jug := _jugador()
	var dir := Vector3(_dir, 0.0, 0.0)
	if jug:
		dir = (jug.global_position + Vector3(0.0, 0.9, 0.0) - boca.global_position)
		dir.z = 0.0
		dir = dir.normalized()
		dir.y = clampf(dir.y, -0.5, 0.5)
	var p: Node3D = escena_proyectil.instantiate()
	p.direccion = dir.normalized()
	p.velocidad = velocidad_proyectil
	get_parent().add_child(p)
	p.global_position = boca.global_position
