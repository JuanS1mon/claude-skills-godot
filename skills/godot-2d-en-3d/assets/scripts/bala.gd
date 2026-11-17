## Bala que viaja en línea recta por el plano en cualquiera de las 8 direcciones.
## Daña a quien tenga `recibir_dano` y empuja los objetos físicos que toca.
## Variantes (las arma el jugador según el tipo de disparo):
## - `escala` > 1: disparo cargado, más grande.
## - `perforante`: atraviesa enemigos y rompe la defensa de los que rebotan balas.
## - `rebotes` > 0: rebota contra el piso y las paredes esa cantidad de veces.
## - `radio_explosion` > 0: al tocar algo explota y daña todo lo que haya en ese radio.
extends Area3D

var direccion := Vector3.RIGHT
var velocidad := 24.0
var dano := 10
var escala := 1.0
var perforante := false
var rebotes := 0
var radio_explosion := 0.0
var color := Color.WHITE
@export var vida := 1.5
@export var empuje := 2.0

var _ya_tocados: Array = []


func _ready() -> void:
	body_entered.connect(_al_tocar)
	direccion = direccion.normalized()
	scale = Vector3.ONE * escala
	$Sprite.modulate = color
	$Luz.light_color = Color(1.0, 0.7, 0.3) * color
	_orientar()


## El dibujo de la bala apunta a la derecha: se gira hacia donde viaja.
func _orientar() -> void:
	$Sprite.rotation.z = atan2(direccion.y, direccion.x)


func _physics_process(delta: float) -> void:
	var paso := direccion * velocidad * delta
	if rebotes > 0:
		# Un Area3D no sabe contra qué cara chocó: se mira con un rayo antes de avanzar.
		var rayo := PhysicsRayQueryParameters3D.create(
			global_position, global_position + paso + direccion * 0.2, 1)
		var golpe := get_world_3d().direct_space_state.intersect_ray(rayo)
		if golpe:
			rebotes -= 1
			direccion = direccion.bounce(golpe.normal)
			direccion.z = 0.0
			direccion = direccion.normalized()
			global_position = golpe.position + golpe.normal * 0.2
			vida = maxf(vida, 0.8)
			_orientar()
			return
	position += paso
	vida -= delta
	if vida <= 0.0:
		queue_free()


func _al_tocar(cuerpo: Node3D) -> void:
	if cuerpo in _ya_tocados:
		return
	if radio_explosion > 0.0:
		_explotar()
		return
	# Enemigo cubierto (escarabajo en su caparazón): la bala común rebota.
	if cuerpo.has_method("rebota_balas") and cuerpo.rebota_balas() and not perforante:
		_ya_tocados.append(cuerpo)
		direccion = Vector3(-direccion.x, randf_range(0.3, 0.9), 0.0).normalized()
		dano = 0
		vida = minf(vida, 0.6)
		_orientar()
		Efectos.texto_flotante(get_parent(), "¡clink!", global_position, Color(0.8, 0.9, 1.0), 40)
		return
	if cuerpo.has_method("recibir_dano") and not cuerpo.is_in_group("jugador"):
		if dano > 0:
			cuerpo.recibir_dano(dano, global_position)
		if perforante:
			_ya_tocados.append(cuerpo)
			return  # sigue de largo
	elif rebotes > 0 and cuerpo is StaticBody3D:
		return  # el rebote contra el mundo lo resuelve el rayo
	if cuerpo is RigidBody3D:
		cuerpo.apply_central_impulse(direccion * empuje * escala)
	queue_free()


func _explotar() -> void:
	var forma := SphereShape3D.new()
	forma.radius = radio_explosion
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis(), global_position)
	consulta.collision_mask = 4 | 16
	for r in get_world_3d().direct_space_state.intersect_shape(consulta, 16):
		var c: Object = r.collider
		if c.has_method("recibir_dano") and not c.is_in_group("jugador"):
			c.recibir_dano(dano, c.global_position + Vector3(0.0, 0.8, 0.0))
		if c is RigidBody3D:
			var d: Vector3 = c.global_position - global_position
			c.apply_central_impulse((d.normalized() + Vector3(0.0, 0.6, 0.0)) * 5.0)
	Efectos.explosion(get_parent(), global_position, radio_explosion, Color(1.0, 0.55, 0.2))
	queue_free()
