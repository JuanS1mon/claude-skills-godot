## Bellota del jefe: sale en arco balístico, marca el lugar donde va a caer y al tocar el
## piso (o al jugador) explota en un golpecito corto.
extends Area3D

var direccion := Vector3.ZERO   # compatibilidad con proyectil_enemigo
var velocidad := 0.0
var balistica := Vector3.ZERO
var gravedad := 18.0
@export var vida := 5.0

var _marca: MeshInstance3D


func _ready() -> void:
	body_entered.connect(_al_tocar)
	# Marca en el piso donde va a caer (se calcula con la balística).
	var t_caida := (balistica.y + sqrt(balistica.y * balistica.y + 2.0 * gravedad * global_position.y)) / gravedad
	var x_caida := global_position.x + balistica.x * t_caida
	_marca = Efectos.esfera(Color(1.0, 0.4, 0.2, 0.4), 0.45)
	get_parent().add_child(_marca)
	_marca.global_position = Vector3(x_caida, 0.05, 0.3)
	_marca.scale = Vector3(1.0, 0.1, 0.6)


func _physics_process(delta: float) -> void:
	balistica.y -= gravedad * delta
	position += balistica * delta
	$Sprite.rotation.z += delta * 6.0
	if _marca:
		_marca.scale.x = 1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.2
	vida -= delta
	if vida <= 0.0 or position.y < -1.0:
		_limpiar()


func _limpiar() -> void:
	if is_instance_valid(_marca):
		_marca.queue_free()
	queue_free()


func _al_tocar(cuerpo: Node3D) -> void:
	if cuerpo.is_in_group("jugador"):
		cuerpo.recibir_dano(1, global_position)
	elif cuerpo.is_in_group("jefe") or cuerpo.is_in_group("enemigo"):
		return  # no se rompe contra el propio jefe
	Efectos.explosion(get_parent(), global_position, 0.8, Color(1.0, 0.55, 0.2))
	_limpiar()
