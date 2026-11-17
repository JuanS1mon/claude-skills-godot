## Base de los enemigos que se mueven (escarabajo, volador, slime).
## Vivos: cada uno define su comportamiento en `_comportamiento()` y lastiman al tocarlos.
## Derribados: quedan tirados, se pueden AGARRAR y ARROJAR como las cajas (dañan lo que
## golpean) y el jugador puede ABSORBER su poder. Al rato vuelven a aparecer en su lugar.
## Nodos: Sprite (AnimatedSprite3D, dibujo mirando a la DERECHA), Contacto (Area3D), Vida (Label3D).
class_name Enemigo
extends CharacterBody3D

@export var vida_max := 60
## Poder que le da al jugador al absorberlo: "escarabajo", "volador" o "slime".
@export var poder := ""
## Segundos que queda derribado antes de volver a aparecer (no corre mientras lo cargan).
@export var tiempo_reaparecer := 8.0
@export var gravedad := 30.0
## Daño al chocar cuando lo arrojan = velocidad del impacto x esto.
@export var dano_por_velocidad := 2.0
## Dónde queda respecto de la mano del jugador mientras lo cargan.
@export var desfase_agarre := Vector3(0.0, -0.55, 0.0)
## Animación mientras lo cargan (tiene que tapar la caja dibujada en la pose del jugador).
@export var anim_agarrado := "derrotado"

@onready var sprite: AnimatedSprite3D = $Sprite
@onready var contacto: Area3D = $Contacto
@onready var etiqueta_vida: Label3D = $Vida

var vida := 0
var estado := "patrulla"
var lanzada := false
var agarrado := false
var _dir := -1.0
var _inicio := Vector3.ZERO
var _t_estado := 0.0
var _t_derrotado := 0.0
var _capa := 0
var _mascara := 0


func _ready() -> void:
	add_to_group("enemigo")
	_inicio = global_position
	_capa = collision_layer
	_mascara = collision_mask
	vida = vida_max
	_actualizar_etiqueta()


func _physics_process(delta: float) -> void:
	_t_estado -= delta
	if agarrado:
		if estado == "absorbido":
			_t_derrotado -= delta
			if _t_derrotado <= 0.0:
				_reaparecer()
		return
	if estado == "derrotado":
		_fisica_derrotado(delta)
		return

	if _usa_gravedad() and not is_on_floor():
		velocity.y -= gravedad * delta
	if estado == "golpe":
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		if not _usa_gravedad():
			velocity.y = move_toward(velocity.y, 0.0, 20.0 * delta)
		_animar("golpe")
		if _t_estado <= 0.0:
			_tras_golpe()
	else:
		_comportamiento(delta)

	velocity.z = 0.0
	move_and_slide()
	position.z = 0.0
	sprite.flip_h = _dir < 0.0

	for cuerpo in contacto.get_overlapping_bodies():
		if cuerpo.is_in_group("jugador"):
			cuerpo.recibir_dano(1, global_position)


# --- Para que cada enemigo lo redefina -------------------------------------

func _comportamiento(_delta: float) -> void:
	pass


func _usa_gravedad() -> bool:
	return true


## Qué hace cuando termina el estado "golpe".
func _tras_golpe() -> void:
	_cambiar("patrulla", 0.0)


## true = las balas comunes rebotan en vez de dañarlo.
func rebota_balas() -> bool:
	return false


# --- Utilidades --------------------------------------------------------------

func _cambiar(nuevo: String, duracion: float) -> void:
	estado = nuevo
	_t_estado = duracion


func _animar(anim: String) -> void:
	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


func _jugador() -> Node3D:
	return get_tree().get_first_node_in_group("jugador") as Node3D


func _actualizar_etiqueta() -> void:
	etiqueta_vida.text = "%d / %d" % [vida, vida_max]


# --- Daño y derrota ----------------------------------------------------------

func recibir_dano(cantidad: int, punto: Vector3) -> void:
	if estado == "derrotado" or estado == "absorbido":
		return
	vida = maxi(vida - cantidad, 0)
	_actualizar_etiqueta()
	Efectos.numero_flotante(get_parent(), cantidad, punto)
	var lado := signf(global_position.x - punto.x)
	velocity.x = lado * 3.0
	sprite.modulate = Color(1.0, 0.4, 0.4)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	if vida <= 0:
		_derrotar()
	else:
		_cambiar("golpe", 0.25)


func _derrotar() -> void:
	_cambiar("derrotado", 0.0)
	_t_derrotado = tiempo_reaparecer
	etiqueta_vida.text = "¡KO!  (agarralo)"
	_animar("derrotado")
	# Pasa a ser un objeto agarrable: choca con el mundo, otros enemigos y las cajas.
	collision_layer = 16
	collision_mask = 1 | 4 | 16
	velocity.y = maxf(velocity.y, 3.0)


## Derribado se comporta como un objeto: cae, rebota un poco y frena en el piso.
func _fisica_derrotado(delta: float) -> void:
	_t_derrotado -= delta
	if _t_derrotado <= 0.0:
		_desvanecer_y_reaparecer()
		return
	if not is_on_floor():
		velocity.y -= gravedad * delta
	var vel_antes := velocity
	velocity.z = 0.0
	move_and_slide()
	position.z = 0.0
	if lanzada:
		sprite.rotation.z -= signf(vel_antes.x) * 9.0 * delta
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			var cuerpo := c.get_collider()
			var rapidez := vel_antes.length()
			if cuerpo is Node and cuerpo.has_method("recibir_dano") and not cuerpo.is_in_group("jugador") \
					and rapidez >= 3.0:
				cuerpo.recibir_dano(int(rapidez * dano_por_velocidad), global_position + Vector3(0.0, 0.6, 0.0))
			if cuerpo is RigidBody3D:
				cuerpo.apply_central_impulse(vel_antes * 0.5)
			# Rebote corto contra lo que haya chocado.
			velocity = vel_antes.bounce(c.get_normal()) * 0.3
			lanzada = false
			break
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		if not lanzada:
			sprite.rotation.z = lerp_angle(sprite.rotation.z, 0.0, 0.3)


func _desvanecer_y_reaparecer() -> void:
	_cambiar("absorbido", 0.0)  # mismo camino que al ser absorbido: espera oculto y vuelve
	agarrado = true
	collision_layer = 0
	collision_mask = 0
	_t_derrotado = 0.4
	create_tween().tween_property(sprite, "modulate:a", 0.0, 0.3)


func _reaparecer() -> void:
	global_position = _inicio
	velocity = Vector3.ZERO
	vida = vida_max
	collision_layer = _capa
	collision_mask = _mascara
	agarrado = false
	lanzada = false
	visible = true
	sprite.scale = Vector3.ONE
	sprite.rotation.z = 0.0
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_actualizar_etiqueta()
	_cambiar("patrulla", 0.0)
	create_tween().tween_property(sprite, "modulate:a", 1.0, 0.3)


# --- Agarrar, arrojar, absorber (lo llama el jugador) ---------------------------

func al_agarrar() -> void:
	agarrado = true
	lanzada = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	sprite.rotation.z = 0.0
	etiqueta_vida.visible = false
	_animar(anim_agarrado)


func al_soltar(velocidad: Vector3) -> void:
	agarrado = false
	collision_layer = 16
	collision_mask = 1 | 4 | 16
	velocity = velocidad
	lanzada = velocidad.length() > 1.0
	etiqueta_vida.visible = true
	_animar("derrotado")


## El jugador se queda con su poder: el enemigo se achica hasta desaparecer y vuelve más tarde.
func al_absorber() -> void:
	_cambiar("absorbido", 0.0)
	agarrado = true
	_t_derrotado = tiempo_reaparecer
	etiqueta_vida.visible = false
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector3.ONE * 0.05, 0.25)
	t.tween_callback(func(): visible = false; etiqueta_vida.visible = true)
