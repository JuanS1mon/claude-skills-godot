## Jefe: jabalí de guerra acorazado. Pelea por patrón fijo que se repite:
##   1) EMBESTIDA: patea el suelo (aviso) y cruza la arena; choca contra la pared y queda
##      ATURDIDO unos segundos (ahí recibe daño DOBLE: esa es la ventana principal).
##   2) SALTO: salta hacia el jugador y al caer larga ondas de choque que recorren el piso
##      en ambas direcciones (se saltan).
##   3) LLUVIA: se planta y dispara bellotas en arco que caen sobre la arena.
## Al llegar a la vida de furia (15 %) ruge, se tiñe de rojo y repite el patrón más rápido
## y con más proyectiles. Siempre recibe daño (no hace falta esperar la ventana), pero el
## caparazón de números hace que el aturdido valga la pena.
## Nodos: Sprite (AnimatedSprite3D, dibujo mirando a la IZQUIERDA), Contacto (Area3D), Vida (Label3D).
extends CharacterBody3D

signal vida_cambio(vida: int, vida_max: int)
signal derrotado

@export var vida_max := 500
@export var gravedad := 30.0
## Fracción de vida a la que entra en furia y multiplicador de velocidad del patrón.
@export_range(0.05, 0.5) var vida_furia := 0.15
@export var mult_furia := 1.5
## Embestida.
@export var velocidad_embestida := 14.0
@export var aviso_embestida := 0.9
@export var segundos_aturdido := 2.8
## Salto.
@export var fuerza_salto := 14.0
@export var velocidad_onda := 7.0
## Lluvia de bellotas.
@export var proyectiles_lluvia := 5
@export var escena_proyectil: PackedScene
## Daño por contacto y empuje al jugador.
@export var dano_contacto := 1

## Límites de la arena (los fija el script de la arena al empezar).
var x_izq := 56.0
var x_der := 74.0

@onready var sprite: AnimatedSprite3D = $Sprite
@onready var contacto: Area3D = $Contacto
@onready var etiqueta_vida: Label3D = $Vida

var vida := 0
var estado := "dormido"   # dormido → patrón: embestir / saltar / lluvia / aturdido → muerto
var furia := false
var _t := 0.0
var _dir := -1.0
var _paso := 0            # posición dentro del patrón
var _patron := ["embestir", "saltar", "lluvia", "saltar"]
var _disparados := 0
var _t_disparo := 0.0
var _tween_tinte: Tween


func _ready() -> void:
	add_to_group("enemigo")
	add_to_group("jefe")
	vida = vida_max
	etiqueta_vida.visible = false
	set_physics_process(false)  # duerme hasta que la arena lo despierta


## La arena lo despierta cuando el jugador entra.
func despertar() -> void:
	if estado != "dormido":
		return
	estado = "entrada"
	_t = 1.2
	set_physics_process(true)
	vida_cambio.emit(vida, vida_max)
	Efectos.texto_flotante(get_parent(), "¡GRUUUNF!", global_position + Vector3(0, 3.2, 0), Color(1.0, 0.5, 0.3), 72)


func _velocidad_patron() -> float:
	return mult_furia if furia else 1.0


func _physics_process(delta: float) -> void:
	if not is_on_floor() and estado != "saltando":
		velocity.y -= gravedad * delta
	_t -= delta * (_velocidad_patron() if estado != "aturdido" else 1.0)

	match estado:
		"entrada":
			velocity.x = 0.0
			_animar("aviso")
			if _t <= 0.0:
				_siguiente_paso()
		"aviso_embestida":
			velocity.x = 0.0
			_mirar_al_jugador()
			_animar("aviso")
			if _t <= 0.0:
				estado = "embistiendo"
				_animar("embestida")
		"embistiendo":
			velocity.x = _dir * velocidad_embestida * _velocidad_patron()
			_animar("embestida")
			_polvo(delta)
			if is_on_wall():
				# Se estampa contra la pared de la arena: aturdido = ventana de daño.
				estado = "aturdido"
				_t = segundos_aturdido
				velocity.x = 0.0
				_animar("aturdido")
				_sacudir_camara()
				Efectos.texto_flotante(get_parent(), "¡PUMBA!", global_position + Vector3(0, 3.0, 0), Color(1.0, 0.8, 0.3), 60)
		"aturdido":
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			_animar("aturdido")
			if _t <= 0.0:
				_siguiente_paso()
		"aviso_salto":
			velocity.x = 0.0
			_mirar_al_jugador()
			_animar("agachado")
			if _t <= 0.0:
				estado = "saltando"
				var jug := _jugador()
				var destino_x: float = jug.global_position.x if jug else (x_izq + x_der) / 2.0
				# Margen mayor que el medio ancho del jabalí (1,55): si cae tocando la pared,
				# queda superpuesto, la física lo separa cada frame y `is_on_wall()` queda
				# prendido, con lo que la embestida siguiente se aturde sin moverse.
				destino_x = clampf(destino_x, x_izq + 2.3, x_der - 2.3)
				var t_aire := 2.0 * fuerza_salto / gravedad / _velocidad_patron()
				velocity = Vector3((destino_x - global_position.x) / t_aire, fuerza_salto, 0.0)
				_animar("saltando")
		"saltando":
			velocity.y -= gravedad * _velocidad_patron() * delta
			_animar("saltando" if velocity.y > 0.0 else "cayendo")
			if is_on_floor() and velocity.y <= 0.0:
				estado = "caida"
				_t = 0.8
				velocity.x = 0.0
				# Tras tocar el piso sigue un par de frames con la velocidad del salto y puede
				# terminar apoyado CONTRA la pared; ahí `is_on_wall()` queda prendido y la
				# embestida siguiente se aturdiría sin moverse. Se lo separa siempre.
				global_position.x = clampf(global_position.x, x_izq + 2.0, x_der - 2.0)
				_animar("caida")
				_sacudir_camara()
				_lanzar_ondas()
		"caida":
			if _t <= 0.0:
				_siguiente_paso()
		"aviso_lluvia":
			velocity.x = 0.0
			_mirar_al_jugador()
			_animar("aviso")
			if _t <= 0.0:
				estado = "lluvia"
				_disparados = 0
				_t_disparo = 0.0
		"lluvia":
			velocity.x = 0.0
			_animar("agachado")
			_t_disparo -= delta * _velocidad_patron()
			var total := proyectiles_lluvia + (2 if furia else 0)
			if _t_disparo <= 0.0 and _disparados < total:
				_t_disparo = 0.22
				_disparar_bellota(total)
			if _disparados >= total:
				estado = "caida"  # pausa corta y sigue
				_t = 0.7
		"muerto":
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)

	velocity.z = 0.0
	move_and_slide()
	position.z = 0.0
	sprite.flip_h = _dir > 0.0  # el dibujo mira a la izquierda

	if estado != "muerto":
		for cuerpo in contacto.get_overlapping_bodies():
			if cuerpo.is_in_group("jugador"):
				cuerpo.recibir_dano(dano_contacto, global_position)


func _siguiente_paso() -> void:
	var paso: String = _patron[_paso % _patron.size()]
	_paso += 1
	match paso:
		"embestir":
			estado = "aviso_embestida"
			_t = aviso_embestida
		"saltar":
			estado = "aviso_salto"
			_t = 0.55
		"lluvia":
			estado = "aviso_lluvia"
			_t = 0.5


func _jugador() -> Node3D:
	return get_tree().get_first_node_in_group("jugador") as Node3D


func _mirar_al_jugador() -> void:
	var jug := _jugador()
	if jug:
		_dir = signf(jug.global_position.x - global_position.x)
		if _dir == 0.0:
			_dir = -1.0


func _animar(anim: String) -> void:
	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	sprite.speed_scale = _velocidad_patron()


## Ondas de choque que salen de donde cae, una para cada lado (en furia, una segunda tanda
## más rápida un instante después).
func _lanzar_ondas() -> void:
	for dir in [-1.0, 1.0]:
		Onda.crear(get_parent(), global_position, dir, velocidad_onda * _velocidad_patron(), x_izq, x_der)
	if furia:
		var timer := get_tree().create_timer(0.55)
		timer.timeout.connect(func():
			if estado != "muerto":
				for dir in [-1.0, 1.0]:
					Onda.crear(get_parent(), global_position, dir, velocidad_onda * 1.8, x_izq, x_der))


func _disparar_bellota(total: int) -> void:
	_disparados += 1
	var p: Node3D = escena_proyectil.instantiate()
	# En abanico hacia arriba: caen repartidas por la arena.
	var ancho := x_der - x_izq - 2.0
	var destino_x := x_izq + 1.0 + ancho * float(_disparados - 1) / float(maxi(total - 1, 1))
	var t_aire := 1.5
	p.direccion = Vector3.ZERO  # la bellota usa gravedad propia (ver abajo)
	p.set("velocidad", 0.0)
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0, 2.6, 0)
	# Velocidad balística para caer en destino_x.
	var vx := (destino_x - p.global_position.x) / t_aire
	var vy := 0.5 * 18.0 * t_aire  # gravedad reducida: arco alto y legible
	p.set("balistica", Vector3(vx, vy, 0.0))
	_animar("agachado")


func recibir_dano(cantidad: int, punto: Vector3) -> void:
	if estado in ["dormido", "muerto"]:
		return
	var final := cantidad * (2 if estado == "aturdido" else 1)
	vida = maxi(vida - final, 0)
	Efectos.numero_flotante(get_parent(), final, punto,
		Color(1.0, 0.5, 0.2) if estado == "aturdido" else Color(1.0, 0.9, 0.3))
	if _tween_tinte:
		_tween_tinte.kill()
	sprite.modulate = Color(1.0, 0.4, 0.4)
	_tween_tinte = create_tween()
	_tween_tinte.tween_property(sprite, "modulate", Color(1.0, 0.55, 0.45) if furia else Color.WHITE, 0.2)
	vida_cambio.emit(vida, vida_max)
	if vida <= 0:
		_morir()
	elif not furia and vida <= int(vida_max * vida_furia):
		_enfurecer()


func _enfurecer() -> void:
	furia = true
	estado = "entrada"  # ruge un instante y retoma el patrón, ya acelerado
	_t = 1.0
	velocity.x = 0.0
	Efectos.texto_flotante(get_parent(), "¡FURIA!", global_position + Vector3(0, 3.4, 0), Color(1.0, 0.25, 0.2), 80)
	_sacudir_camara()
	sprite.modulate = Color(1.0, 0.55, 0.45)


func _morir() -> void:
	estado = "muerto"
	_animar("aturdido")
	collision_layer = 0
	contacto.monitoring = false
	derrotado.emit()
	Efectos.texto_flotante(get_parent(), "¡JEFE VENCIDO!", global_position + Vector3(0, 3.5, 0), Color(1.0, 0.9, 0.3), 90)
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color(0.6, 0.6, 0.6), 0.5)
	t.tween_interval(1.0)
	t.tween_property(sprite, "modulate:a", 0.0, 1.5)
	t.tween_callback(queue_free)


func _polvo(delta: float) -> void:
	# Estela de polvo simple durante la embestida.
	if randf() < delta * 20.0:
		var m := Efectos.esfera(Color(0.75, 0.65, 0.5, 0.5), randf_range(0.15, 0.3))
		get_parent().add_child(m)
		m.global_position = global_position + Vector3(-_dir * 1.5, randf_range(0.1, 0.6), 0.2)
		var t := m.create_tween()
		t.tween_property(m.mesh.material, "albedo_color:a", 0.0, 0.4)
		t.tween_callback(m.queue_free)


func _sacudir_camara() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("sacudir"):
		cam.sacudir(0.35)
