## Onda de choque del jefe: una cresta que recorre el piso hasta la pared de la arena.
## Lastima al jugador si la toca (hay que saltarla).
class_name Onda
extends Area3D

var dir := 1.0
var velocidad := 7.0
var x_min := 0.0
var x_max := 100.0


static func crear(padre: Node, origen: Vector3, direccion: float, vel: float, izq: float, der: float) -> Onda:
	var o := Onda.new()
	o.dir = direccion
	o.velocidad = vel
	o.x_min = izq + 0.4
	o.x_max = der - 0.4
	o.collision_layer = 0
	o.collision_mask = 2  # jugador
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(0.5, 0.9, 1.5)
	forma.shape = caja
	forma.position.y = 0.45
	o.add_child(forma)
	# Visual: cresta naranja que palpita.
	var m := Efectos.esfera(Color(1.0, 0.6, 0.2, 0.8), 0.5)
	m.scale = Vector3(0.5, 0.9, 0.6)
	m.position.y = 0.3
	o.add_child(m)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.6, 0.2)
	luz.light_energy = 1.2
	luz.omni_range = 1.8
	luz.position.y = 0.5
	o.add_child(luz)
	padre.add_child(o)
	o.global_position = Vector3(origen.x, 0.0, 0.0)
	return o


func _ready() -> void:
	body_entered.connect(_al_tocar)


func _physics_process(delta: float) -> void:
	position.x += dir * velocidad * delta
	# Palpita un poco para que se lea como energía.
	scale.y = 1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.15
	if position.x < x_min or position.x > x_max:
		queue_free()


func _al_tocar(cuerpo: Node3D) -> void:
	if cuerpo.is_in_group("jugador"):
		cuerpo.recibir_dano(1, global_position)
