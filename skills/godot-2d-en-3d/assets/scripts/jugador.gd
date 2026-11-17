## Personaje 2.5D: vive en el plano X/Y (Z siempre 0) y se dibuja con un sprite.
## Mecánicas: correr, salto (coyote, buffer, variable), doble salto, dash, deslizarse y saltar
## de paredes (grupo "pared"), disparar en 8 direcciones (con carga y tipos de disparo que dan
## las estrellas), golpe cuerpo a cuerpo, agarrar / soltar / arrojar objetos y enemigos
## derribados (con carga), absorber el poder de un enemigo y vida con invulnerabilidad.
## Nodos que usa: Sprite (AnimatedSprite3D), Boca/Destello, PuntoAgarre, ZonaAgarre, Mira,
## EfectoGolpe, Caparazon (Sprite3D, opcional).
extends CharacterBody3D

signal disparo(posicion: Vector3)
signal vida_cambio(vida: int, vida_max: int)
signal poder_cambio(poder: String)

@export var stats: JugadorStats
@export var escena_bala: PackedScene

@onready var sprite: AnimatedSprite3D = $Sprite
@onready var boca: Marker3D = $Boca
@onready var punto_agarre: Marker3D = $PuntoAgarre
@onready var zona_agarre: Area3D = $ZonaAgarre
@onready var destello: OmniLight3D = $Boca/Destello
@onready var mira: Node3D = $Mira
@onready var efecto_golpe: Sprite3D = $EfectoGolpe
@onready var caparazon: Sprite3D = get_node_or_null("Caparazon")

## Hombro desde donde sale el disparo; la boca del arma gira alrededor de este punto.
const HOMBRO := Vector3(0.1, 0.95, 0.0)
const LARGO_ARMA := 0.8

var mirando := 1.0
var estado := "quieto"
## Lo que lleva cargado: una caja (RigidBody3D) o un enemigo derribado (Enemigo).
var objeto: PhysicsBody3D = null
var vida := 5
var apuntado := Vector3.RIGHT

## Poder absorbido de un enemigo: "" / "escarabajo" / "volador" / "slime".
var poder := ""
## Tipos de disparo desbloqueados con estrellas y el que está en uso.
var tipos_disparo: Array[String] = ["normal"]
var tipo_disparo := "normal"
## Carga del disparo y del lanzamiento, de 0 a 1 (las lee el HUD).
var carga_disparo := 0.0
var carga_lanzar := 0.0
var volando := false
var en_caparazon := false
var t_vuelo := 0.0

var _t_coyote := 0.0
var _t_buffer := 0.0
var _t_disparo := 0.0
var _zona_x := 0.0
var _agarre_x := 0.0
## Animación corta que se muestra encima del estado (disparar, arrojar, aterrizar...).
var _accion := ""
var _t_accion := 0.0
var _en_piso_antes := true

var _saltos_restantes := 0
var _t_dash := 0.0
var _t_enfriamiento_dash := 0.0
var _dashes_restantes := 0
var _dir_dash := Vector3.RIGHT
var _t_estela := 0.0
var _tween_vuelta: Tween

var _normal_pared := 0.0     # +1 pared a la izquierda, -1 a la derecha, 0 ninguna
var _en_pared := false
var _t_coyote_pared := 0.0
var _t_sin_control := 0.0

var _t_golpe := 0.0
var _t_enfriamiento_golpe := 0.0
var _golpeados: Array = []

var _t_invulnerable := 0.0
var _inicio := Vector3.ZERO

var _cargando_disparo := false
var _cargando_lanzar := false
var _brillo_carga: MeshInstance3D
var _t_clink := 0.0
var _t_baba := 0.0
var _ultima_baba := Vector3.INF


## true mientras dura un dash (lo usa el HUD y la animación).
func esta_en_dash() -> bool:
	return _t_dash > 0.0


func _ready() -> void:
	add_to_group("jugador")
	_zona_x = absf(zona_agarre.position.x)
	_agarre_x = absf(punto_agarre.position.x)
	destello.visible = false
	efecto_golpe.visible = false
	if caparazon:
		caparazon.visible = false
	# Bolita que crece en la boca del arma mientras se carga el disparo.
	_brillo_carga = Efectos.esfera(Color(1.0, 0.85, 0.3, 0.9), 0.12)
	boca.add_child(_brillo_carga)
	_brillo_carga.visible = false
	vida = stats.vida_max
	_inicio = global_position
	vida_cambio.emit.call_deferred(vida, stats.vida_max)


func _physics_process(delta: float) -> void:
	if is_on_floor():
		_saltos_restantes = stats.saltos_extra
		_dashes_restantes = stats.dashes_aereos
		t_vuelo = stats.tiempo_vuelo

	_t_enfriamiento_dash -= delta
	if en_caparazon:
		# Cubierto: no se mueve ni salta, solo frena y cae.
		_t_dash = 0.0
		volando = false
		velocity.x = move_toward(velocity.x, 0.0, stats.frenado * delta)
		if not is_on_floor():
			velocity.y = maxf(velocity.y - stats.gravedad * stats.mult_caida * delta, -stats.velocidad_caida_max)
	else:
		if Input.is_action_just_pressed("dash") and _t_enfriamiento_dash <= 0.0 and _dashes_restantes > 0:
			_empezar_dash()
		if esta_en_dash():
			_dashear(delta)
		else:
			_mover(delta)
			_saltar(delta)

	velocity.z = 0.0
	move_and_slide()
	position.z = 0.0
	if esta_en_dash():
		_empujar_en_dash()
	_detectar_pared()
	_dejar_baba(delta)

	apuntado = _direccion_apuntado()
	_actualizar_disparo(delta)

	_t_enfriamiento_golpe -= delta
	if Input.is_action_just_pressed("golpe") and _t_enfriamiento_golpe <= 0.0 and objeto == null \
			and not en_caparazon:
		_empezar_golpe()
	if _t_golpe > 0.0:
		_t_golpe -= delta
		_aplicar_golpe()

	_actualizar_agarre(delta)

	if objeto:
		var desfase = objeto.get("desfase_agarre")
		objeto.global_position = punto_agarre.global_position + (desfase if desfase is Vector3 else Vector3.ZERO)
		# Cargando el lanzamiento: el objeto tiembla cada vez más.
		if carga_lanzar > 0.0:
			objeto.global_position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * 0.05 * carga_lanzar

	if is_on_floor() and not _en_piso_antes and _accion == "":
		_hacer("aterrizar", 0.08)
	_en_piso_antes = is_on_floor()
	_t_accion -= delta
	if _t_accion <= 0.0:
		_accion = ""

	_t_invulnerable -= delta
	_t_clink -= delta
	sprite.visible = _t_invulnerable <= 0.0 or fmod(_t_invulnerable, 0.12) < 0.07

	_actualizar_visual()


func _hacer(accion: String, duracion: float) -> void:
	_accion = accion
	_t_accion = duracion


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reiniciar"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("cambiar_disparo"):
		cambiar_disparo()


# --- Movimiento ------------------------------------------------------------

func _mover(delta: float) -> void:
	var dir := Input.get_axis("mover_izq", "mover_der")
	if _t_sin_control > 0.0:
		_t_sin_control -= delta
		return  # recién saltó de una pared: la velocidad la fija el salto
	if dir != 0.0:
		mirando = signf(dir)
	var acel := stats.aceleracion if dir != 0.0 else stats.frenado
	if not is_on_floor():
		acel *= stats.control_aire
	velocity.x = move_toward(velocity.x, dir * stats.velocidad, acel * delta)


func _saltar(delta: float) -> void:
	if is_on_floor():
		_t_coyote = stats.coyote_time
		volando = false
	else:
		_t_coyote -= delta
		var vy_antes := velocity.y
		var g := stats.gravedad * (stats.mult_caida if velocity.y < 0.0 else 1.0)
		velocity.y = maxf(velocity.y - g * delta, -stats.velocidad_caida_max)
		if _en_pared and poder == "slime":
			# Poder del slime: se queda pegado; con abajo se desliza.
			velocity.y = -stats.velocidad_deslizar if Input.is_action_pressed("abajo") else 0.0
		elif _en_pared and velocity.y < -stats.velocidad_deslizar:
			velocity.y = -stats.velocidad_deslizar  # deslizarse de a poco
		# Poder del volador: gastado el doble salto, mantener saltar lo hace volar un rato.
		volando = poder == "volador" and _saltos_restantes <= 0 and _t_coyote <= 0.0 and not _en_pared \
			and t_vuelo > 0.0 and Input.is_action_pressed("saltar")
		if volando:
			t_vuelo -= delta
			velocity.y = maxf(velocity.y, move_toward(vy_antes, stats.velocidad_vuelo, stats.aceleracion_vuelo * delta))
			_t_estela -= delta
			if _t_estela <= 0.0:
				_t_estela = 0.08
				_dejar_estela(Color(0.6, 0.85, 1.0, 0.45))

	_t_coyote_pared -= delta
	if Input.is_action_just_pressed("saltar"):
		_t_buffer = stats.buffer_salto
	else:
		_t_buffer -= delta

	if _t_buffer > 0.0 and _t_coyote > 0.0:
		velocity.y = stats.fuerza_salto
		_t_buffer = 0.0
		_t_coyote = 0.0
	elif Input.is_action_just_pressed("saltar") and _t_coyote_pared > 0.0:
		# Salto de pared: hacia afuera y arriba, con un instante sin control para que se despegue.
		velocity = Vector3(_normal_pared * stats.empuje_pared, stats.fuerza_salto_pared, 0.0)
		mirando = _normal_pared
		_t_sin_control = stats.bloqueo_tras_salto_pared
		_t_coyote_pared = 0.0
		_t_buffer = 0.0
		_en_pared = false
	elif Input.is_action_just_pressed("saltar") and _t_coyote <= 0.0 and _saltos_restantes > 0:
		# Doble salto: solo con un toque nuevo en el aire y sin coyote (si no, sería el salto normal).
		_saltos_restantes -= 1
		velocity.y = stats.fuerza_doble_salto
		_t_buffer = 0.0
		_vuelta_en_el_aire()

	if Input.is_action_just_released("saltar") and velocity.y > 0.0 and _t_sin_control <= 0.0:
		velocity.y *= stats.corte_salto


## Agarrado a la pared = en el aire, tocando un cuerpo del grupo "pared" y empujando hacia ella.
## Con el poder del slime sirve cualquier pared fija y no hace falta seguir empujando.
func _detectar_pared() -> void:
	var antes := _en_pared
	_en_pared = false
	if is_on_floor():
		return
	var dir := Input.get_axis("mover_izq", "mover_der")
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if absf(n.x) > 0.7 and _es_pared(c.get_collider()):
			if dir != 0.0 and signf(dir) == -signf(n.x) and velocity.y <= 0.5:
				_agarrarse(signf(n.x))
	if not _en_pared and antes and poder == "slime" and _t_sin_control <= 0.0 and signf(dir) != _normal_pared:
		# Pegado: sigue agarrado mientras la pared siga ahí y no se aleje a propósito.
		var choque := KinematicCollision3D.new()
		if test_move(global_transform, Vector3(-_normal_pared * 0.1, 0.0, 0.0), choque) \
				and _es_pared(choque.get_collider()):
			_agarrarse(_normal_pared)
	if _en_pared:
		mirando = _normal_pared  # mira hacia afuera, listo para saltar


func _es_pared(cuerpo: Object) -> bool:
	if not cuerpo is Node:
		return false
	return (cuerpo as Node).is_in_group("pared") or (poder == "slime" and cuerpo is StaticBody3D)


func _agarrarse(normal: float) -> void:
	_en_pared = true
	_normal_pared = normal
	_t_coyote_pared = stats.coyote_pared
	# Tocar una pared recarga el doble salto y el dash aéreo.
	_saltos_restantes = stats.saltos_extra
	_dashes_restantes = stats.dashes_aereos


## Poder del slime: va dejando manchas de baba en la pared por donde pasa.
func _dejar_baba(delta: float) -> void:
	if not (_en_pared and poder == "slime"):
		return
	_t_baba -= delta
	var punto := Vector3(global_position.x - _normal_pared * 0.7, global_position.y + randf_range(0.5, 1.1), 1.03)
	if _t_baba <= 0.0 and punto.distance_to(_ultima_baba) > 0.3:
		_t_baba = 0.1
		_ultima_baba = punto
		Efectos.baba(get_parent(), punto)


func _vuelta_en_el_aire() -> void:
	if stats.duracion_vuelta <= 0.0:
		return
	if _tween_vuelta:
		_tween_vuelta.kill()
	sprite.rotation.z = 0.0
	_tween_vuelta = create_tween()
	# Vuelta hacia adelante: en sentido horario si mira a la derecha.
	_tween_vuelta.tween_property(sprite, "rotation:z", -TAU * mirando, stats.duracion_vuelta) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween_vuelta.tween_callback(func(): sprite.rotation.z = 0.0)


## El dash va en 8 direcciones, igual que el apuntado (abajo solo en el aire).
func _empezar_dash() -> void:
	var x := signf(Input.get_axis("mover_izq", "mover_der"))
	var y := signf(Input.get_axis("abajo", "arriba"))
	if is_on_floor() and y < 0.0:
		y = 0.0
	if x == 0.0 and y == 0.0:
		x = mirando
	_dir_dash = Vector3(x, y, 0.0).normalized()
	if x != 0.0:
		mirando = x
	_t_dash = stats.duracion_dash
	_t_enfriamiento_dash = stats.enfriamiento_dash
	if not is_on_floor():
		_dashes_restantes -= 1
	_t_estela = 0.0


func _dashear(delta: float) -> void:
	_t_dash -= delta
	# Recto y sin gravedad: el dash ignora el control normal mientras dura.
	velocity = Vector3(_dir_dash.x, _dir_dash.y * stats.factor_dash_vertical, 0.0) * stats.velocidad_dash
	_t_estela -= delta
	if _t_estela <= 0.0:
		_t_estela = 0.03
		_dejar_estela()
	if _t_dash <= 0.0:
		# Sale del dash con la velocidad normal, sin frenazo de golpe.
		velocity = Vector3(_dir_dash.x * stats.velocidad, _dir_dash.y * stats.velocidad * 0.5, 0.0)


## Copia fantasma del cuadro actual que se desvanece: marca el recorrido del dash.
func _dejar_estela(color := Color(1.0, 0.75, 0.45, 0.6)) -> void:
	var fantasma := Sprite3D.new()
	fantasma.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	fantasma.pixel_size = sprite.pixel_size
	fantasma.flip_h = sprite.flip_h
	fantasma.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	fantasma.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fantasma.modulate = color
	get_parent().add_child(fantasma)
	fantasma.global_position = sprite.global_position + Vector3(0.0, 0.0, -0.05)
	var t := fantasma.create_tween()
	t.tween_property(fantasma, "modulate:a", 0.0, 0.2)
	t.tween_callback(fantasma.queue_free)


func _empujar_en_dash() -> void:
	for i in get_slide_collision_count():
		var cuerpo := get_slide_collision(i).get_collider()
		if cuerpo is RigidBody3D and cuerpo != objeto:
			cuerpo.apply_central_impulse(_dir_dash * stats.empuje_dash + Vector3(0.0, 1.5, 0.0))
			_t_dash = 0.0  # el choque corta el dash


# --- Apuntar y disparar ----------------------------------------------------

## 8 direcciones: horizontal con izq/der, vertical con arriba/abajo. Sin nada, hacia donde mira.
## En el piso no se apunta hacia abajo (se dispararía al suelo).
func _direccion_apuntado() -> Vector3:
	var x := signf(Input.get_axis("mover_izq", "mover_der"))
	var y := signf(Input.get_axis("abajo", "arriba"))
	if is_on_floor() and y < 0.0:
		y = 0.0
	if _en_pared:
		x = _normal_pared  # agarrado a la pared se dispara hacia afuera
	if x == 0.0 and y == 0.0:
		x = mirando
	return Vector3(x, y, 0.0).normalized()


## Un toque dispara. Si se mantiene apretado, carga; al soltar sale un disparo más fuerte
## (al máximo es perforante). Con un objeto en las manos no se dispara.
func _actualizar_disparo(delta: float) -> void:
	_t_disparo -= delta
	if objeto != null or en_caparazon:
		_cargando_disparo = false
		carga_disparo = 0.0
	else:
		if Input.is_action_just_pressed("disparar"):
			if _t_disparo <= 0.0:
				_disparar(0.0)
			_cargando_disparo = true
			carga_disparo = 0.0
		elif _cargando_disparo:
			if Input.is_action_pressed("disparar"):
				carga_disparo = minf(carga_disparo + delta / stats.tiempo_carga, 1.0)
			else:
				if carga_disparo >= stats.carga_minima:
					_disparar(carga_disparo)
				_cargando_disparo = false
				carga_disparo = 0.0
	# Bolita de carga: crece y, llena, late en blanco.
	_brillo_carga.visible = carga_disparo >= 0.15
	if _brillo_carga.visible:
		var latido := 1.0 + (sin(Time.get_ticks_msec() * 0.03) * 0.2 if carga_disparo >= 1.0 else 0.0)
		_brillo_carga.scale = Vector3.ONE * (0.5 + carga_disparo * 2.0) * latido
		var mat: StandardMaterial3D = (_brillo_carga.mesh as SphereMesh).material
		mat.albedo_color = Color(1.0, 1.0, 0.9, 0.9) if carga_disparo >= 1.0 else Color(1.0, 0.8, 0.3, 0.8)


## `carga` 0 = disparo común; 1 = carga completa. El tipo de disparo lo dan las estrellas.
func _disparar(carga: float) -> void:
	_t_disparo = stats.cadencia
	var dirs: Array[Vector3] = [apuntado]
	var dano := lerpf(stats.dano_bala, stats.dano_cargado, carga)
	if tipo_disparo == "triple":
		var ang := deg_to_rad(stats.angulo_triple)
		dirs = [apuntado.rotated(Vector3.BACK, ang), apuntado, apuntado.rotated(Vector3.BACK, -ang)]
		dano *= 0.7
	for d in dirs:
		var bala: Node3D = escena_bala.instantiate()
		bala.direccion = d
		bala.velocidad = stats.velocidad_bala
		bala.dano = int(dano)
		bala.escala = lerpf(1.0, stats.escala_cargada, carga)
		bala.perforante = carga >= 1.0
		match tipo_disparo:
			"triple":
				bala.color = Color(0.7, 1.0, 0.5)
			"rebote":
				bala.rebotes = stats.rebotes
				bala.vida = 2.5
				bala.color = Color(0.5, 0.9, 1.0)
			"explosivo":
				bala.radio_explosion = stats.radio_explosion * lerpf(1.0, 1.6, carga)
				bala.dano = int(stats.dano_explosion * lerpf(1.0, 2.0, carga))
				bala.velocidad = stats.velocidad_explosivo
				bala.escala *= 1.5
				bala.color = Color(1.0, 0.45, 0.4)
		get_parent().add_child(bala)
		bala.global_position = boca.global_position
	if is_on_floor():
		velocity.x -= apuntado.x * stats.retroceso * (1.0 + carga * 4.0)
	_hacer("disparando", 0.12 + carga * 0.1)
	_destellar()
	disparo.emit(boca.global_position)


## Las estrellas desbloquean tipos de disparo; el nuevo queda puesto.
func desbloquear_disparo(tipo: String) -> void:
	if tipo == "" or tipo == "ninguno":
		return
	if not tipo in tipos_disparo:
		tipos_disparo.append(tipo)
	tipo_disparo = tipo
	Efectos.texto_flotante(get_parent(), "Disparo: " + tipo, global_position + Vector3(0.0, 2.0, 0.0), Color(1.0, 0.9, 0.4))


## Pasa al siguiente tipo de disparo desbloqueado.
func cambiar_disparo() -> void:
	tipo_disparo = tipos_disparo[(tipos_disparo.find(tipo_disparo) + 1) % tipos_disparo.size()]
	Efectos.texto_flotante(get_parent(), tipo_disparo, global_position + Vector3(0.0, 2.0, 0.0), Color(1.0, 0.9, 0.4), 40)


func _destellar() -> void:
	destello.visible = true
	await get_tree().create_timer(0.05).timeout
	destello.visible = false


# --- Golpe cuerpo a cuerpo ------------------------------------------------

func _empezar_golpe() -> void:
	_t_golpe = stats.duracion_golpe
	_t_enfriamiento_golpe = stats.enfriamiento_golpe
	_golpeados.clear()
	_hacer("arrojar", 0.18)  # pose con el brazo hacia adelante
	efecto_golpe.visible = true
	efecto_golpe.flip_h = mirando > 0.0  # el dibujo original abre hacia la izquierda
	efecto_golpe.position = Vector3(0.9 * mirando, 0.95, 0.1)
	efecto_golpe.scale = Vector3.ONE * 0.6
	efecto_golpe.modulate.a = 1.0
	var t := efecto_golpe.create_tween().set_parallel()
	t.tween_property(efecto_golpe, "scale", Vector3.ONE * 1.1, 0.12)
	t.tween_property(efecto_golpe, "modulate:a", 0.0, 0.18).set_delay(0.06)
	t.chain().tween_callback(func(): efecto_golpe.visible = false)


## Mientras dura el golpe, cada cuerpo dentro de la caja de alcance recibe el golpe UNA vez.
func _aplicar_golpe() -> void:
	var forma := BoxShape3D.new()
	forma.size = stats.alcance_golpe
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis(), global_position + Vector3(0.8 * mirando, 0.95, 0.0))
	consulta.collision_mask = 4 | 16  # enemigos y objetos
	consulta.exclude = [get_rid()]
	for r in get_world_3d().direct_space_state.intersect_shape(consulta, 8):
		var cuerpo: Object = r.collider
		if cuerpo in _golpeados:
			continue
		_golpeados.append(cuerpo)
		var punto := global_position + Vector3(0.8 * mirando, 0.95, 0.0)
		if cuerpo.has_method("recibir_dano"):
			cuerpo.recibir_dano(stats.dano_golpe, punto)
		if cuerpo is RigidBody3D:
			cuerpo.apply_central_impulse(Vector3(mirando * stats.empuje_golpe, 2.5, 0.0))
		elif cuerpo is Enemigo and cuerpo.estado == "derrotado":
			cuerpo.al_soltar(Vector3(mirando * stats.empuje_golpe, 4.0, 0.0))  # patear al derribado


# --- Agarrar, soltar, arrojar ---------------------------------------------

## Botón de agarrar (acción):
## - sin nada: agarra lo que haya adelante (caja o enemigo derribado);
## - abajo + botón, con el poder del escarabajo y las manos libres: se cubre mientras se mantenga;
## - con algo en las manos y abajo: una caja se apoya adelante; de un enemigo se ABSORBE el poder;
## - con algo en las manos: al soltar el botón lo arroja; cuanto más se mantiene, más fuerte.
func _actualizar_agarre(delta: float) -> void:
	var abajo := Input.is_action_pressed("abajo")
	if Input.is_action_just_pressed("agarrar"):
		if objeto:
			if abajo:
				if objeto is Enemigo and objeto.poder != "":
					_absorber()
				else:
					_soltar_en_el_lugar()
			else:
				_cargando_lanzar = true
				carga_lanzar = 0.0
		elif abajo and poder == "escarabajo":
			en_caparazon = true
		else:
			_agarrar()
	if en_caparazon and not Input.is_action_pressed("agarrar"):
		en_caparazon = false
	if _cargando_lanzar:
		if objeto == null:
			_cargando_lanzar = false
			carga_lanzar = 0.0
		elif Input.is_action_pressed("agarrar"):
			carga_lanzar = minf(carga_lanzar + delta / stats.tiempo_carga_lanzar, 1.0)
		else:
			_arrojar(carga_lanzar)
			_cargando_lanzar = false
			carga_lanzar = 0.0


func _agarrar() -> void:
	var mejor: PhysicsBody3D = null
	var dist_min := INF
	for cuerpo in zona_agarre.get_overlapping_bodies():
		if cuerpo.has_method("al_agarrar"):
			var d := global_position.distance_to(cuerpo.global_position)
			if d < dist_min:
				dist_min = d
				mejor = cuerpo
	if mejor:
		objeto = mejor
		objeto.al_agarrar()
		# La pose "cargando" trae una caja dibujada más chica: el objeto real (mismo estilo,
		# tamaño real) se pone encima, en PuntoAgarre, y la tapa.
		_hacer("levantar", 0.15)


## Abajo + agarrar: la caja se apoya adelante, sobre lo que haya (piso u otra caja): así se apilan.
func _soltar_en_el_lugar() -> void:
	var x := global_position.x + 1.0 * mirando
	var rayo := PhysicsRayQueryParameters3D.create(
		Vector3(x, global_position.y + 3.0, 0.0), Vector3(x, global_position.y - 2.0, 0.0), 1 | 16)
	rayo.exclude = [get_rid(), objeto.get_rid()]
	var golpe := get_world_3d().direct_space_state.intersect_ray(rayo)
	var y: float = golpe.position.y if golpe else global_position.y
	objeto.al_soltar(Vector3.ZERO)
	objeto.global_position = Vector3(x, y + 0.47, 0.0)
	objeto.rotation = Vector3.ZERO
	objeto.lanzada = false
	_hacer("levantar", 0.15)
	objeto = null


## Con arriba (o apuntando en diagonal) lo lanza hacia donde se apunta; sin dirección vertical,
## en arco. `carga` (0 a 1) multiplica la fuerza hasta `mult_lanzamiento_cargado`.
func _arrojar(carga: float) -> void:
	var fuerza := stats.fuerza_lanzamiento * lerpf(1.0, stats.mult_lanzamiento_cargado, carga)
	var vel: Vector3
	if Input.is_action_pressed("arriba"):
		vel = apuntado * fuerza * 1.15
	else:
		var ang := deg_to_rad(stats.angulo_lanzamiento)
		vel = Vector3(cos(ang) * mirando, sin(ang), 0.0) * fuerza
	vel += Vector3(velocity.x, 0.0, 0.0) * stats.herencia_velocidad
	objeto.al_soltar(vel)
	_hacer("arrojar", 0.25)
	objeto = null


## Se queda con el poder del enemigo que tiene en las manos (reemplaza al poder anterior).
func _absorber() -> void:
	poder = objeto.poder
	objeto.al_absorber()
	objeto = null
	_cargando_lanzar = false
	carga_lanzar = 0.0
	_hacer("levantar", 0.2)
	Efectos.texto_flotante(get_parent(), "¡Poder: %s!" % poder, global_position + Vector3(0.0, 2.2, 0.0), Color(0.6, 1.0, 0.6))
	sprite.modulate = Color(0.6, 1.0, 0.6)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.4)
	poder_cambio.emit(poder)


## Cubierto con el poder del escarabajo: los proyectiles enemigos rebotan.
func rebota_balas() -> bool:
	return en_caparazon


# --- Vida ------------------------------------------------------------------

func recibir_dano(_cantidad: int, punto: Vector3) -> void:
	if _t_invulnerable > 0.0 or vida <= 0:
		return
	if en_caparazon:
		if _t_clink <= 0.0:
			_t_clink = 0.4
			Efectos.texto_flotante(get_parent(), "¡clink!", global_position + Vector3(0.0, 1.4, 0.0), Color(0.8, 0.9, 1.0), 40)
		return
	vida -= 1
	_t_invulnerable = stats.invulnerable
	var lado := signf(global_position.x - punto.x)
	if lado == 0.0:
		lado = -mirando
	velocity = Vector3(lado * stats.empuje_al_recibir.x, stats.empuje_al_recibir.y, 0.0)
	_t_sin_control = 0.2
	_t_dash = 0.0
	if objeto:
		objeto.al_soltar(Vector3(lado * 2.0, 2.0, 0.0))
		objeto = null
	vida_cambio.emit(vida, stats.vida_max)
	if vida <= 0:
		_reaparecer.call_deferred()


func _reaparecer() -> void:
	await get_tree().create_timer(0.6).timeout
	global_position = _inicio
	velocity = Vector3.ZERO
	vida = stats.vida_max
	poder = ""  # al caer derrotado se pierde el poder absorbido
	poder_cambio.emit(poder)
	_t_invulnerable = stats.invulnerable
	vida_cambio.emit(vida, stats.vida_max)


# --- Visual ----------------------------------------------------------------

func _actualizar_visual() -> void:
	sprite.flip_h = mirando < 0.0
	zona_agarre.position.x = _zona_x * mirando
	punto_agarre.position.x = _agarre_x * mirando
	# La boca del arma gira alrededor del hombro según el apuntado.
	var hombro := Vector3(HOMBRO.x * mirando, HOMBRO.y, 0.0)
	boca.position = hombro + apuntado * LARGO_ARMA
	mira.position = hombro + apuntado * 1.9
	mira.visible = objeto == null and not en_caparazon
	if caparazon:
		caparazon.visible = en_caparazon
		caparazon.flip_h = mirando < 0.0
		if en_caparazon:
			sprite.visible = false

	if en_caparazon:
		estado = "caparazón"
	elif esta_en_dash():
		estado = "dash"
	elif volando:
		estado = "volando"
	elif _en_pared:
		estado = "pared"
	elif not is_on_floor():
		if absf(velocity.y) < 2.0:
			estado = "cumbre"
		else:
			estado = "saltando" if velocity.y > 0.0 else "cayendo"
	elif absf(velocity.x) > 0.5:
		estado = "corriendo"
	else:
		estado = "quieto"

	var anim := estado
	if estado == "dash":
		anim = "cumbre"  # pose inclinada hacia adelante con la pistola
	elif estado == "pared":
		anim = "cayendo"
	elif estado == "volando":
		anim = "cumbre"
	elif estado == "caparazón":
		anim = "agacharse"
	# Estirado durante el dash; vuelve suave a la escala normal.
	var escala := Vector3.ONE
	if estado == "dash":
		# Se estira en el sentido del dash: a lo ancho si es de costado, a lo alto si es vertical.
		escala = Vector3(0.85, 1.3, 1.0) if absf(_dir_dash.y) > absf(_dir_dash.x) else Vector3(1.3, 0.85, 1.0)
	sprite.scale = sprite.scale.lerp(escala, 0.35)
	# Al apuntar en diagonal o vertical, el sprite se inclina un poco hacia el apuntado
	# (hasta tener cuadros dibujados apuntando hacia arriba).
	if not (_tween_vuelta and _tween_vuelta.is_running()):
		var inclinacion := atan2(apuntado.y, absf(apuntado.x)) * 0.3 * mirando
		sprite.rotation.z = lerp_angle(sprite.rotation.z, inclinacion if objeto == null else 0.0, 0.3)
	if objeto:
		anim = "cargando_corriendo" if estado == "corriendo" else "cargando"
	# Disparar mientras corre ya se ve bien con la carrera (la pistola apunta adelante).
	if _accion != "" and not (_accion == "disparando" and estado == "corriendo"):
		anim = _accion
	if objeto:
		estado += " (cargando)"

	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)
	# Velocidad de la carrera según lo rápido que se mueve.
	sprite.speed_scale = clampf(absf(velocity.x) / stats.velocidad, 0.6, 1.3) if anim.ends_with("corriendo") else 1.0
