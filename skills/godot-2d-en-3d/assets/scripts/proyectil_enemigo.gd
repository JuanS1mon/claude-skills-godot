## Bola de energía del escarabajo: viaja recta, lastima al jugador y se deshace contra el mundo.
## Si el jugador está cubierto con el poder del escarabajo, rebota y pasa a dañar enemigos.
extends Area3D

var direccion := Vector3.LEFT
var velocidad := 9.0
var reflejado := false
@export var vida := 3.0
@export var dano_reflejado := 30


func _ready() -> void:
	body_entered.connect(_al_tocar)


func _physics_process(delta: float) -> void:
	position += direccion * velocidad * delta
	$Sprite.rotation.z += delta * 8.0
	vida -= delta
	if vida <= 0.0:
		queue_free()


func _al_tocar(cuerpo: Node3D) -> void:
	if cuerpo.is_in_group("jugador"):
		if reflejado:
			return
		if cuerpo.has_method("rebota_balas") and cuerpo.rebota_balas():
			reflejado = true
			direccion = -direccion
			velocidad *= 1.5
			vida = 3.0
			collision_mask |= 4  # ahora también toca enemigos
			$Sprite.modulate = Color(1.0, 0.8, 0.4)
			Efectos.texto_flotante(get_parent(), "¡clink!", global_position, Color(0.8, 0.9, 1.0), 40)
			return
		cuerpo.recibir_dano(1, global_position)
	elif reflejado and cuerpo.has_method("recibir_dano"):
		cuerpo.recibir_dano(dano_reflejado, global_position)
	elif cuerpo is RigidBody3D:
		cuerpo.apply_central_impulse(direccion * 2.0)
	queue_free()
