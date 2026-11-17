## Objeto físico que se puede agarrar y arrojar. Si golpea algo con `recibir_dano`
## mientras vuela, le hace daño según la velocidad del impacto.
extends RigidBody3D

@export var dano_por_velocidad := 2.0
@export var velocidad_min_dano := 3.0

var lanzada := false
var _capa := 0
var _mascara := 0
var _ultima_vel := Vector3.ZERO


func _ready() -> void:
	_capa = collision_layer
	_mascara = collision_mask
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_al_chocar)


func _physics_process(_delta: float) -> void:
	_ultima_vel = linear_velocity


func al_agarrar() -> void:
	freeze = true
	collision_layer = 0
	collision_mask = 0
	rotation = Vector3.ZERO
	lanzada = false


func al_soltar(velocidad: Vector3) -> void:
	freeze = false
	collision_layer = _capa
	collision_mask = _mascara
	linear_velocity = velocidad
	angular_velocity = Vector3(0.0, 0.0, -signf(velocidad.x) * 6.0)
	lanzada = true


func _al_chocar(cuerpo: Node) -> void:
	if not lanzada:
		return
	lanzada = false
	var rapidez := _ultima_vel.length()
	if rapidez >= velocidad_min_dano and cuerpo.has_method("recibir_dano") and not cuerpo.is_in_group("jugador"):
		cuerpo.recibir_dano(int(rapidez * dano_por_velocidad), global_position)
