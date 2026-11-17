@tool
class_name Mueble
extends Area2D
## Clase base de todos los muebles: se arrastran con mouse o dedo
## y al soltarlos se ajustan a una grilla.
## El aspecto se configura desde el Inspector con textura y color (tinte).

@export var tamano_grilla: int = 40
@export var textura: Texture2D:
	set(valor):
		textura = valor
		_actualizar_aspecto()
@export var color: Color = Color.WHITE:
	set(valor):
		color = valor
		_actualizar_aspecto()
## Tamaño en el juego (píxeles). La imagen se escala para encajar, sea cual sea su resolución.
@export var tamano: Vector2 = Vector2(120, 120):
	set(valor):
		tamano = valor
		_actualizar_aspecto()

## Zona del suelo que ocupa el mueble (su huella), en píxeles. Zarita no puede pisarla.
## Vector2.ZERO = automática, a partir del tamaño.
@export var huella: Vector2 = Vector2.ZERO
## false para objetos que se pueden pisar (alfombras).
@export var bloquea: bool = true
## true para las ventanas: al soltarlas se pegan a la pared de arriba y solo se deslizan de lado.
@export var solo_en_pared: bool = false
## Sin sombra (los muebles pegados a la pared parecen flotar con ella).
@export var contra_pared: bool = false
## Cara de arriba donde se pueden dejar objetos (mesas, cómodas): zona de la BASE del objeto apoyado, en píxeles
## desde el origen de este mueble. Rect2() vacío = no es una superficie.
@export var superficie: Rect2 = Rect2()
## true para objetos pequeños (radios, plantas) que se pueden dejar sobre un mueble con `superficie`.
@export var apoyable: bool = false
## Luz que emite de noche (lámparas): color, alcance en píxeles, altura sobre la base (fracción del alto) y fuerza.
@export var emite_luz: bool = false
@export var luz_color: Color = Color(1.0, 0.85, 0.55)
@export var luz_radio: float = 180.0
@export var luz_altura: float = 0.85
@export var luz_energia: float = 0.9

## Geometría de la esquina isométrica (por preload: un class_name nuevo no existe hasta que el editor reescanee el proyecto).
const Cuarto = preload("res://scripts/geometria_cuarto.gd")

## Posición de la base de los muebles de pared (Y) y los límites laterales, entre los bordes de la casa.
const Y_PARED: float = 190.0
const X_MIN_PARED: float = 24.0
const X_MAX_PARED: float = 696.0
const SEPARACION_EN_PARED: float = 8.0
## Cuánto sube la base de una ventana sobre la línea donde su pared toca el piso.
const ALTURA_VENTANA: float = 170.0
## Límites del suelo (donde pueden apoyarse los muebles): bajo la pared de arriba y sobre la de abajo, como en casa.tscn.
const Y_SUELO_MIN: float = 217.0
const Y_SUELO_MAX: float = 1233.0
## Mientras se arrastra un objeto apoyable, se dibuja por encima de los demás para verlo bien al acercarlo a una mesa.
const Z_ARRASTRE: int = 50
## Ayudas para apoyar objetos: a cuántos píxeles de la superficie empieza a atraer, qué tan rápido se desliza el objeto
## hacia donde irá (más es más pegado al dedo) y cuánto se pega al centro de la superficie.
const RADIO_IMAN: float = 32.0
const VELOCIDAD_DESLIZ: float = 28.0
const IMAN_CENTRO: Vector2 = Vector2(9.0, 6.0)
## Muebles que recibieron el clic en este cuadro: solo uno lo agarra (ver _elegir_agarre).
static var _candidatos: Array[Mueble] = []

## Se emite al soltar el mueble, ya ajustado a la grilla.
signal soltado(mueble: Mueble)
## Se emite cuando se enciende o apaga una lámpara.
signal luz_alternada
## Se emite mientras se arrastra el mueble (en cada movimiento): la casa avisa si está sobre el inventario.
signal arrastrando(mueble: Mueble)
## Se emite cuando cambia algo que hay que guardar sin haber movido el mueble (darlo vuelta).
signal cambio_aspecto

## Ficha de la que nació (null si se puso a mano en el editor).
var ficha: MuebleData
## true si está dado vuelta (mira hacia el otro lado): se dibuja la imagen en espejo.
var volteado: bool = false:
	set(valor):
		volteado = valor
		_actualizar_aspecto()
## El mueble sobre el que está apoyado (null si está en el suelo). Es también su nodo padre.
var apoyado_en: Mueble
var editable: bool = false
## Para los muebles que emiten luz: un clic fuera del modo Decorar la apaga o la enciende.
var encendida: bool = true
var _arrastrando: bool = false
var _desfase: Vector2 = Vector2.ZERO
var _forma_bloqueo: CollisionShape2D
var _luz: PointLight2D
var _sombra: Sombra
var _oclusor: LightOccluder2D
var _z_original: int = 0
## Dónde quiere estar el objeto apoyable que se arrastra (el dedo, ya atraído por la superficie); él se desliza hasta ahí.
var _objetivo: Vector2 = Vector2.ZERO
var _soporte_guia: Mueble
var _guia: Node2D
var _estado_guia: int = 0
var _tween_apoyo: Tween
var _boton_voltear: Button
var _reloj_boton: Timer
## El mueble que muestra ahora su botón de voltear (solo uno a la vez).
static var _con_boton: Mueble
## Los muebles de pared se arriman a la pared a esta distancia (píxeles).
const FONDO_CONTRA_PARED: float = 10.0


func _ready() -> void:
	set_process(false)
	_actualizar_aspecto()
	if not Engine.is_editor_hint():
		if get_parent() == get_tree().root:
			# Escena ejecutada suelta (F6): el origen es la base y el sprite sube desde ahí, así que se centra el mueble
			# en la pantalla para que se vea entero.
			var pantalla := get_viewport_rect().size
			position = Vector2(pantalla.x / 2.0, pantalla.y / 2.0 + tamano.y / 2.0)
		if solo_en_pared:
			position = _ajustar_a_pared(position)   # las guardadas con la pared recta de antes se acomodan a la esquina
			add_to_group("ventanas")   # su sola presencia deja entrar el sol y la luna: las sombras lo tienen en cuenta
		_crear_bloqueo()
		_crear_luz()
		_crear_sombra()
		_mostrar_sombras(apoyado_en == null)


## Una lámpara encendida alumbra poco de día y mucho de noche; apagada, no alumbra. El cambio es suave.
func _process(delta: float) -> void:
	if _arrastrando and apoyable:
		global_position = global_position.lerp(_objetivo, 1.0 - exp(-delta * VELOCIDAD_DESLIZ))
	if _luz == null:
		return
	var objetivo := 0.0
	if encendida:
		objetivo = (0.25 + 0.75 * CicloDia.oscuridad()) * luz_energia
	_luz.energy = lerpf(_luz.energy, objetivo, 0.15)


## Lo llama la casa (por grupo "muebles") al activar o desactivar el modo decorar.
## Mientras se decora, los muebles no bloquean: se pueden poner incluso encima de Zarita.
func set_editable(valor: bool) -> void:
	editable = valor
	if not editable:
		_arrastrando = false
		_ocultar_boton()
		get_tree().call_group("muebles", "fijar_guia", 0)
	_actualizar_bloqueo()


## Para muebles recién sacados del inventario: ya vienen "agarrados" por el dedo.
func empezar_arrastre() -> void:
	_arrastrando = true
	_desfase = Vector2.ZERO
	_levantar()


func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if editable:
			# Pueden estar bajo el dedo varios muebles a la vez (una radio sobre una mesa): al terminar el cuadro
			# agarra solo uno, el de más arriba.
			if not _candidatos.has(self):
				_candidatos.append(self)
			if _candidatos.size() == 1:
				_elegir_agarre.call_deferred()
		else:
			al_tocar()


## Entre los muebles que recibieron el clic, agarra el que se ve por encima: primero los apoyados sobre otro,
## después el que tiene la base más abajo (el de adelante).
func _elegir_agarre() -> void:
	var elegido: Mueble = null
	var mejor: float = -INF
	for candidato in _candidatos:
		if not is_instance_valid(candidato) or candidato.is_queued_for_deletion():
			continue
		var prioridad := candidato.global_position.y + (100000.0 if candidato.apoyado_en != null else 0.0)
		if prioridad > mejor:
			mejor = prioridad
			elegido = candidato
	_candidatos.clear()
	if elegido != null:
		elegido._agarrar()


func _agarrar() -> void:
	_arrastrando = true
	_desfase = global_position - get_global_mouse_position()
	_levantar()


## Al agarrarlo: pasa por encima de todo y, si estaba sobre una mesa, se baja de ella (vuelve a ser hijo de la casa).
func _levantar() -> void:
	_z_original = z_index
	_ocultar_boton()
	if apoyable:
		z_index = Z_ARRASTRE
		_objetivo = global_position
		set_process(true)
		get_tree().call_group("muebles", "fijar_guia", 1)   # marca las superficies donde se puede dejar
	if apoyado_en != null:
		var casa := apoyado_en.get_parent()
		apoyado_en = null
		reparent(casa)   # conserva su posición en pantalla
		_actualizar_bloqueo()
		_mostrar_sombras(true)


## Qué hace el mueble al tocarlo fuera del modo Decorar. Por defecto, alternar su luz si la tiene.
## Los muebles especiales (el reproductor de música) lo sobrescriben.
func al_tocar() -> void:
	if _luz != null:
		alternar_luz()


func alternar_luz() -> void:
	encendida = not encendida
	luz_alternada.emit()


func _input(event: InputEvent) -> void:
	if not _arrastrando:
		return
	if event is InputEventMouseMotion:
		_objetivo = get_global_mouse_position() + _desfase
		if apoyable:
			# Imán: cerca de una superficie, el objeto se desliza hacia ella (y se resalta) para ver cómo quedará.
			var soporte := _superficie_bajo(_objetivo)
			_resaltar_soporte(soporte)
			if soporte != null:
				_objetivo = soporte._punto_en_superficie(_objetivo)
		else:
			global_position = _objetivo
		arrastrando.emit(self)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_arrastrando = false
		z_index = _z_original
		if solo_en_pared:
			global_position = _ajustar_a_pared(global_position)
		else:
			var libre := get_global_mouse_position() + _desfase if apoyable else global_position   # dónde lo soltó el dedo
			var soporte: Mueble = null
			if apoyable:
				soporte = _superficie_bajo(libre)
				_resaltar_soporte(null)
				get_tree().call_group("muebles", "fijar_guia", 0)
				set_process(_luz != null)
			if soporte != null:
				_apoyar_en(soporte, libre)
			else:
				var punto := _ajustar_al_suelo(libre if _va_a_la_grilla() else libre.snapped(Vector2(tamano_grilla, tamano_grilla)))
				global_position = punto
		_mostrar_boton()
		soltado.emit(self)


## Tras tocar o soltar el mueble en modo Decorar aparece, unos segundos, un botón encima para darlo vuelta.
func _mostrar_boton() -> void:
	if solo_en_pared or ficha == null or not editable:
		return
	if _boton_voltear == null:
		_crear_boton_voltear()
	if _con_boton != null and _con_boton != self and is_instance_valid(_con_boton):
		_con_boton._ocultar_boton()
	_con_boton = self
	var y := -tamano.y - 84.0   # encima del dibujo; si queda fuera de la pantalla, debajo de la base
	if global_position.y + y < 110.0:
		y = 20.0
	_boton_voltear.position = Vector2(-36.0, y)
	_boton_voltear.visible = true
	_reloj_boton.start()


func _ocultar_boton() -> void:
	if _boton_voltear != null:
		_boton_voltear.visible = false
		_reloj_boton.stop()
	if _con_boton == self:
		_con_boton = null


## El botón se crea la primera vez que hace falta: un botón cuadrado con el icono de las dos flechas.
func _crear_boton_voltear() -> void:
	_boton_voltear = Button.new()
	_boton_voltear.theme = load("res://themes/zarita.tres") as Theme
	_boton_voltear.theme_type_variation = &"BotonIcono"
	_boton_voltear.custom_minimum_size = Vector2(72, 72)
	_boton_voltear.focus_mode = Control.FOCUS_NONE
	_boton_voltear.z_index = 100   # por encima de los demás muebles
	_boton_voltear.visible = false
	var icono := TextureRect.new()
	icono.texture = load("res://assets/ui/iconos/voltear.png") as Texture2D
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icono.offset_left = 12.0
	icono.offset_top = 12.0
	icono.offset_right = -12.0
	icono.offset_bottom = -12.0
	_boton_voltear.add_child(icono)
	_boton_voltear.pressed.connect(_voltear)
	add_child(_boton_voltear)
	_reloj_boton = Timer.new()
	_reloj_boton.one_shot = true
	_reloj_boton.wait_time = 3.0
	_reloj_boton.timeout.connect(_ocultar_boton)
	add_child(_reloj_boton)


func _voltear() -> void:
	volteado = not volteado
	_efecto_apoyo()
	_reloj_boton.start()   # sigue visible otros 3 segundos
	cambio_aspecto.emit()


## Mantiene la base del mueble sobre el piso: ni dentro de las paredes en diagonal ni fuera de los costados de la casa.
## Solo el cuerpo de la base cuenta para arriba (el dibujo de un mueble alto puede subir por la pared, como en la vida real).
func _ajustar_al_suelo(pos: Vector2, con_grilla: bool = true) -> Vector2:
	var fondo := huella.y if huella != Vector2.ZERO else clampf(tamano.y * 0.25, 20.0, 60.0)
	if ficha != null and ficha.en_el_suelo:
		fondo = tamano.y   # una alfombra es plana: entera sobre el piso
	if contra_pared:
		fondo = FONDO_CONTRA_PARED
	if con_grilla and _va_a_la_grilla():
		return Cuarto.a_grilla(pos, tamano.x / 2.0, fondo)
	return Cuarto.ajustar_base(pos, tamano.x / 2.0, fondo)


## Los muebles grandes se apoyan en la grilla del piso. Quedan libres los que pueden ir sobre otros muebles (radios,
## plantas), las lámparas, las alfombras y las ventanas.
func _va_a_la_grilla() -> bool:
	return not (apoyable or emite_luz or solo_en_pared or (ficha != null and ficha.en_el_suelo))


## Al cargar una partida: lo guardado con otra forma de habitación (la pared recta de antes, o una base sobre la pared)
## "cae" al piso en el punto más cercano que lo deja entero sobre él.
func acomodar_al_suelo() -> void:
	if not solo_en_pared:
		position = _ajustar_al_suelo(position, false)   # lo ya colocado no salta a la grilla: sólo lo nuevo que se suelta


## El mueble con superficie más cercano a `punto`, si está a menos de RADIO_IMAN píxeles de su cara de arriba
## (null si ninguno). Si dos están igual de cerca, el de adelante.
func _superficie_bajo(punto: Vector2) -> Mueble:
	var mejor: Mueble = null
	var mejor_distancia: float = RADIO_IMAN
	for nodo in get_tree().get_nodes_in_group("muebles"):
		var otro := nodo as Mueble
		if otro == self or otro.is_queued_for_deletion() or not otro.superficie.has_area() or otro.apoyado_en != null:
			continue
		var local := otro.to_local(punto)
		var cercano := Vector2(clampf(local.x, otro.superficie.position.x, otro.superficie.end.x),
				clampf(local.y, otro.superficie.position.y, otro.superficie.end.y))
		var distancia := local.distance_to(cercano)
		if distancia < mejor_distancia - 0.01 or (mejor != null and absf(distancia - mejor_distancia) <= 0.01 				and otro.global_position.y > mejor.global_position.y):
			mejor_distancia = distancia
			mejor = otro
	return mejor


## Resalta la superficie que está a punto de recibir el objeto (las demás quedan con la marca suave).
func _resaltar_soporte(soporte: Mueble) -> void:
	if soporte == _soporte_guia:
		return
	if _soporte_guia != null and is_instance_valid(_soporte_guia):
		_soporte_guia.fijar_guia(1)
	_soporte_guia = soporte
	if soporte != null:
		soporte.fijar_guia(2)


## Marca visual de la cara de arriba de un mueble mientras se arrastra un objeto apoyable:
## 0 = oculta, 1 = hay donde dejarlo, 2 = se va a dejar aquí.
func fijar_guia(estado: int) -> void:
	if not superficie.has_area() or apoyado_en != null:
		return
	_estado_guia = estado
	if estado == 0:
		if _guia != null:
			_guia.visible = false
		return
	if _guia == null:
		_guia = Node2D.new()
		_guia.z_index = 1
		_guia.draw.connect(_dibujar_guia)
		add_child(_guia)
	_guia.visible = true
	_guia.queue_redraw()


func _dibujar_guia() -> void:
	var activa := _estado_guia == 2
	var centro := superficie.get_center()
	var radio := superficie.size / 2.0 + Vector2(10.0, 6.0)
	var puntos := PackedVector2Array()
	for i in 25:
		var angulo := TAU * i / 24.0
		puntos.append(centro + Vector2(cos(angulo) * radio.x, sin(angulo) * radio.y))
	var color := Color(1.0, 0.95, 0.6) if activa else Color.WHITE
	_guia.draw_colored_polygon(puntos.slice(0, 24), Color(color, 0.40 if activa else 0.16))
	_guia.draw_polyline(puntos, Color(color, 0.95 if activa else 0.5), 2.0)


## Lleva un punto del mundo al punto más cercano de la cara de arriba de este mueble.
func _punto_en_superficie(punto: Vector2) -> Vector2:
	var local := to_local(punto)
	local.x = clampf(local.x, superficie.position.x, superficie.end.x)
	local.y = clampf(local.y, superficie.position.y, superficie.end.y)
	# Un poco de imán al centro: es donde mejor se ve un objeto sobre una mesa.
	var centro := superficie.get_center()
	if absf(local.x - centro.x) < IMAN_CENTRO.x:
		local.x = centro.x
	if absf(local.y - centro.y) < IMAN_CENTRO.y:
		local.y = centro.y
	return to_global(local)


## Deja este objeto sobre `soporte`: pasa a ser su hijo (se dibuja encima y se mueve con él) y deja de bloquear.
func _apoyar_en(soporte: Mueble, desde: Vector2) -> void:
	var punto := soporte._punto_en_superficie(desde)
	apoyado_en = soporte
	reparent(soporte)
	global_position = punto
	_actualizar_bloqueo()
	_mostrar_sombras(false)
	_efecto_apoyo()


## Un saltito al quedar apoyado: se aplasta un poco y recupera su forma.
func _efecto_apoyo() -> void:
	var sprite := $Sprite2D as Sprite2D
	var escala := sprite.scale
	var altura := sprite.position.y
	sprite.scale = escala * Vector2(1.10, 0.88)
	sprite.position.y = altura * 0.88   # la base no se despega de la superficie
	if _tween_apoyo != null:
		_tween_apoyo.kill()
	_tween_apoyo = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_apoyo.tween_property(sprite, "scale", escala, 0.22)
	_tween_apoyo.tween_property(sprite, "position:y", altura, 0.22)


## Un objeto sobre una mesa no ocupa suelo: no bloquea a Zarita (ya lo hace la mesa).
func _actualizar_bloqueo() -> void:
	if _forma_bloqueo != null:
		_forma_bloqueo.set_deferred("disabled", editable or apoyado_en != null)


## Las sombras del suelo no valen para algo que está sobre una mesa.
func _mostrar_sombras(valor: bool) -> void:
	if _sombra != null:
		_sombra.visible = valor
		_sombra.set_process(valor)
	if _oclusor != null:
		_oclusor.visible = valor


## Pega el mueble a la pared más cercana (izquierda o derecha de la esquina), a su altura sobre el piso, lo mantiene dentro
## de esa pared y lo separa de otros muebles de pared. Si es una ventana, la inclina al plano de la pared.
func _ajustar_a_pared(pos: Vector2) -> Vector2:
	var mitad := tamano.x / 2.0
	var izquierda := pos.x < Cuarto.esquina.x
	var x_min := X_MIN_PARED + mitad
	var x_max := Cuarto.esquina.x - mitad - SEPARACION_EN_PARED
	if not izquierda:
		x_min = Cuarto.esquina.x + mitad + SEPARACION_EN_PARED
		x_max = X_MAX_PARED - mitad
	pos.x = clampf(snappedf(pos.x, 20.0), x_min, x_max)
	for _intento in 6:
		var choca := false
		for nodo in get_tree().get_nodes_in_group("muebles"):
			var otro := nodo as Mueble
			if otro == self or not otro.solo_en_pared or otro.is_queued_for_deletion():
				continue
			var minimo := mitad + otro.tamano.x / 2.0 + SEPARACION_EN_PARED
			if absf(pos.x - otro.global_position.x) < minimo:
				choca = true
				# Se desliza al lado libre más cercano de la otra ventana.
				var a_la_izquierda := otro.global_position.x - minimo
				var a_la_derecha := otro.global_position.x + minimo
				pos.x = a_la_izquierda if absf(pos.x - a_la_izquierda) < absf(pos.x - a_la_derecha) else a_la_derecha
				pos.x = clampf(pos.x, x_min, x_max)
		if not choca:
			break
	pos.y = Cuarto.y_borde(pos.x) - ALTURA_VENTANA
	var visual := get_node_or_null("Visual")
	if visual != null and visual.has_method("orientar"):
		visual.orientar(-Cuarto.pendiente if izquierda else Cuarto.pendiente)
	return pos


## Cuerpo sólido en la base del mueble. Se crea por código porque su tamaño depende de la ficha.
func _crear_bloqueo() -> void:
	if not bloquea:
		return
	var tam := huella
	if tam == Vector2.ZERO:
		tam = Vector2(tamano.x * 0.8, clampf(tamano.y * 0.25, 20.0, 60.0))
	var forma := RectangleShape2D.new()
	forma.size = tam
	_forma_bloqueo = CollisionShape2D.new()
	_forma_bloqueo.shape = forma
	_forma_bloqueo.position = Vector2(0, -tam.y / 2.0)   # apoyada en el origen, que es la base
	_forma_bloqueo.disabled = editable or apoyado_en != null
	var cuerpo := StaticBody2D.new()
	cuerpo.add_child(_forma_bloqueo)
	add_child(cuerpo)


## Luz redonda sobre el mueble. Solo existe en el juego, y solo si la ficha dice que emite luz.
func _crear_luz() -> void:
	if not emite_luz:
		return
	_luz = PointLight2D.new()
	_luz.texture = CicloDia.textura_radial()
	_luz.texture_scale = luz_radio * 2.0 / 256.0
	_luz.color = luz_color
	_luz.energy = 0.0
	_luz.position = Vector2(0, -tamano.y * luz_altura)
	add_child(_luz)
	add_to_group("lamparas")
	set_process(true)


## Cuánta luz emite ahora, de 0 (apagada) a 1 (a plena fuerza). Las sombras de otros objetos la consultan.
func intensidad_luz() -> float:
	if _luz == null or luz_energia <= 0.0:
		return 0.0
	return clampf(_luz.energy / luz_energia, 0.0, 1.0)


## Sombras del mueble: de contacto y proyectadas por las luces. Las alfombras, las ventanas y lo plano no llevan.
func _crear_sombra() -> void:
	if solo_en_pared or contra_pared or (ficha != null and ficha.en_el_suelo):
		return
	var base := huella
	if base == Vector2.ZERO:
		base = Vector2(tamano.x * 0.8, clampf(tamano.y * 0.25, 20.0, 60.0))
	# Tapa la luz natural (LuzNatural): detrás del mueble queda su sombra real.
	_oclusor = LuzNatural.crear_oclusor(base.x, base.y)
	add_child(_oclusor)
	_sombra = Sombra.new()
	_sombra.ancho_base = base.x
	_sombra.profundidad_base = base.y
	_sombra.alto_objeto = tamano.y
	add_child(_sombra)


func _actualizar_aspecto() -> void:
	if not is_node_ready():
		return
	$Sprite2D.texture = textura
	$Sprite2D.modulate = color
	$Sprite2D.flip_h = volteado
	if textura and textura.get_size().x > 0 and textura.get_size().y > 0:
		$Sprite2D.scale = tamano / textura.get_size()
	# El origen del mueble es el centro de su base (como los pies de Zarita), para ordenar por altura.
	$Sprite2D.position = Vector2(0, -tamano.y / 2.0)
	# La colisión se ajusta solo al jugar, con una forma propia por mueble.
	if not Engine.is_editor_hint():
		var forma := RectangleShape2D.new()
		forma.size = tamano
		$CollisionShape2D.shape = forma
		$CollisionShape2D.position = Vector2(0, -tamano.y / 2.0)
