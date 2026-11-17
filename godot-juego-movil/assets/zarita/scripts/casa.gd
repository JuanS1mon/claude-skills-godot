extends Node2D
## Habitación de la casa: activa el modo decorar, saca muebles del inventario, guarda/carga la partida y lleva a Zarita
## de una habitación a otra. Una sola escena sirve para todas: al cambiar de habitación se guarda todo y la escena se
## recarga con la ficha de la nueva (data/habitaciones/*.tres). La música, el clima y la hora son de toda la casa.

const ESCENA_TIENDA: PackedScene = preload("res://scenes/tienda.tscn")
const ESCENA_LUZ_HABITACION: PackedScene = preload("res://scenes/luz_habitacion.tscn")
const ESCENA_LUZ_NATURAL: PackedScene = preload("res://scenes/luz_natural.tscn")
const ESCENA_ZONA_VENTA: PackedScene = preload("res://scenes/zona_venta.tscn")
const ESCENA_CONFIRMAR_VENTA: PackedScene = preload("res://scenes/confirmar_venta.tscn")
const ESCENA_MAPA: PackedScene = preload("res://scenes/mapa_casa.tscn")
## Geometría de la esquina isométrica (por preload: un class_name nuevo no existe hasta que el editor reescanee el proyecto).
const Cuarto = preload("res://scripts/geometria_cuarto.gd")
const ESCENA_ROPERO: PackedScene = preload("res://scenes/ropero_menu.tscn")
const ESCENA_FUNDIDO: PackedScene = preload("res://scenes/fundido.tscn")
const ESCENA_MATE_HUD: PackedScene = preload("res://scenes/mate_hud.tscn")
const ESCENA_DIALOGO: PackedScene = preload("res://scenes/dialogo_personaje.tscn")
const ESCENA_MONTE: String = "res://scenes/monte.tscn"
const ESCENA_CAZA: String = "res://scenes/caza_bichitos.tscn"
const ESCENA_MATE: String = "res://scenes/mate_juego.tscn"

@onready var _inventario_ui: PanelContainer = $CanvasLayer/InventarioUI
@onready var _zarita: Zarita = $Zarita
## La interfaz (botones, joystick, ajustes) está hecha en el editor, en scenes/hud.tscn. Sin tipo: tiene su propio script.
@onready var _hud = $CanvasLayer/Hud
@onready var _joystick: Control = $CanvasLayer/Hud/Joystick
@onready var _ajustes = $CanvasLayer/Hud/Ajustes

## Venta de muebles: la franja de arriba y la ventana de confirmación (sin tipo: tienen su propio script).
var _zona_venta
var _confirmar_venta
## El mueble que se está por vender (escondido mientras el jugador decide).
var _mueble_en_venta: Mueble

## La habitación en la que estamos (id de su ficha) y su ficha.
var _id_habitacion: String = Habitaciones.ID_INICIAL
var _ficha_habitacion: HabitacionData
var _luz: LuzHabitacion
var _mapa: MapaCasa
var _boton_mapa: Button
var _mate_hud: MateHud
var _dialogo: DialogoPersonaje
## Mini menú de ropa que se abre al tocar a Zarita (sin tipo: tiene su propio script).
var _ropero_menu
var _fundido: CanvasLayer
var _cambiando: bool = false


func _ready() -> void:
	# Los hijos se dibujan ordenados por su posición Y: el que tiene los pies más abajo queda delante.
	y_sort_enabled = true
	$Suelo.z_index = -10
	_crear_paredes_diagonales()
	var partida := Partida.leer()
	Habitaciones.cargar_datos(partida)
	_id_habitacion = Habitaciones.actual
	_ficha_habitacion = Habitaciones.ficha(_id_habitacion)
	_aplicar_habitacion()
	# La tienda es un panel; el botón que la abre está en el HUD.
	var tienda = ESCENA_TIENDA.instantiate()
	$CanvasLayer.add_child(tienda)
	_hud.tienda_alternada.connect(tienda.mostrar)
	tienda.cerrada.connect(_hud.desmarcar_tienda)
	# Sol y luna reales con la pared que los deja pasar por las ventanas (apagable: ver `activa` en luz_natural.tscn).
	add_child(ESCENA_LUZ_NATURAL.instantiate())
	# Luz interior de la habitación, con el botón Luz del HUD. Cada habitación recuerda si la dejaste encendida.
	_luz = ESCENA_LUZ_HABITACION.instantiate() as LuzHabitacion
	add_child(_luz)
	_luz.position = Vector2(360, 700)
	var guardadas: Dictionary = partida.get("habitaciones", {})
	var luz_encendida: bool = (guardadas.get(_id_habitacion, {}) as Dictionary).get("luz", true)
	_luz.set_encendida(luz_encendida)
	_hud.fijar_luz(luz_encendida)
	_hud.luz_alternada.connect(_al_alternar_luz)
	_hud.decorar_alternado.connect(_on_boton_decorar_toggled)
	# Mapa de la casa (botón en el HUD y panel a pantalla completa) y fundido para cambiar de habitación.
	_boton_mapa = _hud.get_node("BarraInferior/BotonMapa")   # el botón de la casa está en la barra del HUD
	_boton_mapa.pressed.connect(_abrir_mapa)
	_mate_hud = ESCENA_MATE_HUD.instantiate() as MateHud
	$CanvasLayer.add_child(_mate_hud)
	_hud.tienda_alternada.connect(func(abierta: bool) -> void: _mate_hud.visible = not abierta)   # no tapa la tienda
	_mate_hud.pedido_tomar.connect(_al_pedir_tomar)
	_mate_hud.pedido_yerba.connect(_al_pedir_yerba)
	_mate_hud.pedido_agua.connect(_al_pedir_agua)
	_mapa = ESCENA_MAPA.instantiate() as MapaCasa
	add_child(_mapa)
	_mapa.viajar.connect(_ir_a_habitacion)
	_mapa.cazar.connect(_ir_a_cazar)
	_mapa.explorar.connect(_ir_al_monte)
	_dialogo = ESCENA_DIALOGO.instantiate() as DialogoPersonaje
	add_child(_dialogo)
	_mapa.hablar.connect(func(id_personaje: String) -> void: _dialogo.abrir(Conversaciones.de(id_personaje)))
	_dialogo.accion_hecha.connect(_guardar)
	_mapa.desbloqueada.connect(func(_id: String) -> void: _guardar())
	_fundido = ESCENA_FUNDIDO.instantiate()
	add_child(_fundido)
	_ropero_menu = ESCENA_ROPERO.instantiate()
	$CanvasLayer.add_child(_ropero_menu)
	_ropero_menu.cambiada.connect(_guardar)
	# El joystick puede ir a la izquierda o a la derecha (ajuste del jugador).
	_colocar_joystick(_ajustes.joystick_derecha)
	_ajustes.joystick_lado_cambiado.connect(_colocar_joystick)
	_inventario_ui.visible = false
	_inventario_ui.ficha_elegida.connect(_colocar_desde_inventario)
	_zona_venta = ESCENA_ZONA_VENTA.instantiate()
	$CanvasLayer.add_child(_zona_venta)
	_confirmar_venta = ESCENA_CONFIRMAR_VENTA.instantiate()
	$CanvasLayer.add_child(_confirmar_venta)
	_confirmar_venta.vendido.connect(_terminar_venta.bind(true))
	_confirmar_venta.guardado.connect(_terminar_venta.bind(false))
	_cargar(partida)
	Mate.confort_actual = Habitaciones.confort_de(_id_habitacion, partida)
	Misiones.registrar_visita(_id_habitacion)
	_colocar_zarita()
	_actualizar_musica()
	Musica.cambio.connect(_guardar)   # cada toque al reproductor queda guardado
	_destrabar_zarita()
	_fundido.entrar()


## Las paredes de la esquina isométrica bloquean a Zarita con la forma de la "V" (GeometriaCuarto); reemplazan al rectángulo de arriba.
func _crear_paredes_diagonales() -> void:
	var forma := CollisionPolygon2D.new()
	var guia := get_node_or_null("GuiaCuarto")
	forma.polygon = Cuarto.poligono_paredes(guia.subida_pies if guia != null else 24.0)
	$Paredes.add_child(forma)
	$Paredes/CollisionShape2D.set_deferred("disabled", true)


## Suelo de la habitación (con un tinte provisional hasta que cada una tenga su arte).
func _aplicar_habitacion() -> void:
	if _ficha_habitacion == null:
		return
	if _ficha_habitacion.suelo != null:
		$Suelo.texture = _ficha_habitacion.suelo
	$Suelo.modulate = _ficha_habitacion.tinte_suelo


## Zarita aparece en el punto de inicio de la habitación.
func _colocar_zarita() -> void:
	if _ficha_habitacion != null:
		_zarita.position = _ficha_habitacion.inicio_zarita


## Guarda todo, oscurece la pantalla y recarga la escena con la habitación nueva (se llega desde el mapa).
func _ir_a_habitacion(id: String) -> void:
	if _cambiando or id == _id_habitacion or not Habitaciones.esta_desbloqueada(id):
		return
	_cambiando = true
	Habitaciones.actual = id
	_guardar()
	await _fundido.salir()
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	Mate.actualizar(delta)   # la energía de Zarita baja con el tiempo


## Sale al monte (el exterior de la casa): guarda, fundido y cambia de escena. Se vuelve con el botón del monte.
func _ir_al_monte() -> void:
	if _cambiando:
		return
	_cambiando = true
	_guardar()
	await _fundido.salir()
	get_tree().change_scene_to_file(ESCENA_MONTE)


## Los bichitos de luz salen de noche (en modo de pruebas, siempre). Guarda, fundido y cambia al minijuego.
func _ir_a_cazar() -> void:
	if _cambiando:
		return
	if not (Economia.MODO_PRUEBAS or CicloDia.oscuridad() > 0.6):
		_hud.avisar("Los bichitos de luz solo salen de noche.")
		return
	_cambiando = true
	_guardar()
	await _fundido.salir()
	get_tree().change_scene_to_file(ESCENA_CAZA)


## Tocar la pava abre el minijuego del mate (hace falta yerba). Guarda, fundido y cambia de escena.
func _ir_a_mate() -> void:
	if _cambiando:
		return
	if Mate.yerba <= 0:
		_hud.avisar("No tenés yerba (botón Yerba).")
		return
	_cambiando = true
	_guardar()
	await _fundido.salir()
	get_tree().change_scene_to_file(ESCENA_MATE)


## Guarda antes de abrir el mapa: el confort de cada habitación se calcula de lo guardado.
func _abrir_mapa() -> void:
	_guardar()
	_mapa.abrir(_id_habitacion)


## El ritual del mate (ver Mate): tomar uno, comprar yerba con Destellos y calentar agua (con una pava en la habitación).
func _al_pedir_tomar() -> void:
	if not Mate.puede_tomar():
		_hud.avisar("Te falta yerba o agua caliente.")
		return
	_zarita.tomar_mate()
	_guardar()


func _al_pedir_yerba() -> void:
	if Economia.pagar(Mate.PRECIO_YERBA, MuebleData.Moneda.COMUN):
		Mate.yerba += Mate.YERBA_POR_COMPRA
		_hud.avisar("Compraste %d de yerba." % Mate.YERBA_POR_COMPRA)
		_guardar()
	else:
		_hud.avisar("No te alcanzan los Destellos (%d)." % Mate.PRECIO_YERBA)


func _al_pedir_agua() -> void:
	if get_tree().get_nodes_in_group("pavas").is_empty():
		_hud.avisar("Necesitas una pava en esta habitación (tienda, Cocina).")
		return
	Mate.calentar_agua()
	_hud.avisar("Agua caliente lista.")
	_guardar()


func _al_alternar_luz(encendida: bool) -> void:
	_luz.set_encendida(encendida)
	_guardar()


## Pone el joystick en la esquina de abajo a la derecha o a la izquierda, según prefiera el jugador.
func _colocar_joystick(derecha: bool) -> void:
	var ancla := 1.0 if derecha else 0.0
	_joystick.anchor_left = ancla
	_joystick.anchor_right = ancla
	_joystick.offset_left = -270.0 if derecha else 30.0
	_joystick.offset_right = -30.0 if derecha else 270.0


func _notification(que: int) -> void:
	if que == NOTIFICATION_WM_CLOSE_REQUEST or que == NOTIFICATION_APPLICATION_PAUSED:
		_guardar()


## Tocar a Zarita (fuera del modo Decorar) abre su ropero; tocar en otro lado lo cierra.
func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT):
		return
	if _inventario_ui.visible:
		return
	var sobre_zarita: bool = make_input_local(evento).position.distance_to(_zarita.global_position + Vector2(0.0, -50.0)) < 55.0
	if not sobre_zarita:
		_ropero_menu.visible = false
		return
	_ropero_menu.abrir()
	var en_pantalla: Vector2 = get_viewport().get_canvas_transform() * _zarita.global_position
	var arriba := en_pantalla - Vector2(_ropero_menu.size.x / 2.0, _ropero_menu.size.y + 130.0)
	var pantalla := get_viewport_rect().size
	_ropero_menu.position = Vector2(clampf(arriba.x, 12.0, pantalla.x - _ropero_menu.size.x - 12.0), maxf(arriba.y, 110.0))


func _on_boton_decorar_toggled(activo: bool) -> void:
	_ropero_menu.visible = false
	get_tree().call_group("muebles", "set_editable", activo)
	var guia := get_node_or_null("GuiaCuarto")
	if guia != null:
		guia.grilla_visible = activo
	_boton_mapa.disabled = activo   # al decorar no se puede viajar: queda apagado en su lugar (así la barra no se mueve)
	_mate_hud.visible = not activo
	_joystick.visible = not activo   # al decorar, el panel del inventario ocupa ese lugar
	_inventario_ui.visible = activo
	if not activo:
		_guardar()
		_destrabar_zarita()


## Si al volver a jugar algún mueble quedó encima de Zarita, la mueve al hueco libre más cercano.
func _destrabar_zarita() -> void:
	# Los muebles vuelven a bloquear en el siguiente cuadro de física.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not _zarita.test_move(_zarita.global_transform, Vector2.ZERO, null, 0.08, true):
		return
	for radio in range(8, 400, 8):
		for i in 8:
			var destino := _zarita.global_transform
			destino.origin += Vector2.from_angle(TAU * i / 8.0) * radio
			if not _zarita.test_move(destino, Vector2.ZERO, null, 0.08, true):
				_zarita.global_position = destino.origin
				return


## Crea el mueble de la ficha y lo deja conectado para guardarse al soltarlo. Todavía no lo pone en la casa.
func _crear_mueble(ficha: MuebleData, posicion: Vector2) -> Mueble:
	var mueble := ficha.crear_mueble()
	mueble.position = posicion
	mueble.soltado.connect(_al_soltar_mueble)
	mueble.luz_alternada.connect(_guardar)
	mueble.cambio_aspecto.connect(_guardar)
	mueble.arrastrando.connect(_al_arrastrar_mueble)
	if mueble is PavaMate:
		mueble.pedido_preparar.connect(_ir_a_mate)
	return mueble


## Crea el mueble de la ficha y lo pone en la casa.
func _poner_mueble(ficha: MuebleData, posicion: Vector2) -> Mueble:
	var mueble := _crear_mueble(ficha, posicion)
	add_child(mueble)
	_actualizar_musica()
	return mueble


## Saca el mueble de la ficha bajo el dedo y lo deja listo para arrastrar.
func _colocar_desde_inventario(ficha: MuebleData) -> void:
	if not Inventario.quitar(ficha):
		return
	var mueble := _poner_mueble(ficha, get_local_mouse_position())
	Misiones.registrar(MisionData.Tipo.DECORAR)
	mueble.position.y += mueble.tamano.y / 2.0   # el origen es la base; el centro del mueble queda bajo el dedo
	mueble.set_editable(true)
	mueble.empezar_arrastre()


## ¿El dedo (o el mouse) está sobre el panel del inventario?
func _sobre_inventario() -> bool:
	return _inventario_ui.visible and _inventario_ui.get_global_rect().has_point(get_viewport().get_mouse_position())


## Mientras se arrastra un mueble sobre el inventario, el borde del panel se ilumina y el mueble se vuelve algo
## transparente: avisa de que al soltarlo se guarda.
func _al_arrastrar_mueble(mueble: Mueble) -> void:
	if mueble.ficha == null:
		return
	# La franja de venta aparece mientras se arrastra y se ilumina si el mueble está encima.
	var unidad := "gemas" if mueble.ficha.moneda == MuebleData.Moneda.GEMAS else "monedas"
	_zona_venta.mostrar(true, "Suelta aquí para vender  (+%d %s)" % [mueble.ficha.precio_venta(), unidad])
	var en_venta: bool = _sobre_zona_venta()
	_zona_venta.resaltar(en_venta)
	var encima := _sobre_inventario()
	_inventario_ui.resaltar(encima)
	mueble.modulate.a = 0.6 if (encima or en_venta) else 1.0


## ¿El dedo (o el mouse) está sobre la franja de venta?
func _sobre_zona_venta() -> bool:
	return _zona_venta.visible and _zona_venta.get_global_rect().has_point(get_viewport().get_mouse_position())


## Si se suelta sobre el panel del inventario, el mueble vuelve a la lista.
func _al_soltar_mueble(mueble: Mueble) -> void:
	_inventario_ui.resaltar(false)
	var en_venta: bool = mueble.ficha != null and _sobre_zona_venta()
	_zona_venta.mostrar(false)
	mueble.modulate.a = 1.0
	if en_venta:
		# Se esconde mientras el jugador decide: "Vender" lo cobra, "Guardar" lo manda al inventario.
		_mueble_en_venta = mueble
		mueble.visible = false
		_confirmar_venta.preguntar(mueble.ficha)
		return
	if mueble.ficha != null and _inventario_ui.visible:
		if _sobre_inventario():
			_devolver_al_inventario(mueble)
	_actualizar_musica()
	_guardar()


## Quita el mueble de la casa y guarda su ficha en el inventario (y la de lo que tenía encima, como una radio sobre una mesa).
func _devolver_al_inventario(mueble: Mueble) -> void:
	for hijo in mueble.get_children():
		var objeto := hijo as Mueble
		if objeto != null and objeto.ficha != null:
			objeto.queue_free()
			Inventario.agregar(objeto.ficha)
	mueble.queue_free()
	Inventario.agregar(mueble.ficha)


## Respuesta de la ventana de confirmación: vender (cobra la mitad del precio; lo que tenía encima vuelve al inventario)
## o guardar el mueble en el inventario.
func _terminar_venta(vender: bool) -> void:
	var mueble := _mueble_en_venta
	_mueble_en_venta = null
	if mueble == null or not is_instance_valid(mueble):
		return
	var ficha := mueble.ficha
	if vender:
		var unidad := "gemas" if ficha.moneda == MuebleData.Moneda.GEMAS else "monedas"
		for hijo in mueble.get_children():
			var objeto := hijo as Mueble
			if objeto != null and objeto.ficha != null:
				objeto.queue_free()
				Inventario.agregar(objeto.ficha)
		mueble.queue_free()
		Economia.ganar(ficha.precio_venta(), ficha.moneda)
		_hud.avisar("Vendido: +%d %s" % [ficha.precio_venta(), unidad])
	else:
		_devolver_al_inventario(mueble)
	_actualizar_musica()
	_guardar()


func _guardar() -> void:
	var con_ficha: Array[Mueble] = []
	for nodo in get_tree().get_nodes_in_group("muebles"):
		var mueble := nodo as Mueble
		if mueble.ficha != null and not mueble.is_queued_for_deletion():
			con_ficha.append(mueble)
	var validos: Array[Mueble] = []
	for mueble in con_ficha:
		if mueble.apoyado_en == null or con_ficha.has(mueble.apoyado_en):
			validos.append(mueble)
	# Un objeto sobre una mesa se guarda con la posición dentro de la mesa y el número de la mesa en esta lista.
	var colocados: Array = []
	for mueble in validos:
		var entrada := {
			"ficha": mueble.ficha.resource_path,
			"x": mueble.position.x,
			"y": mueble.position.y,
			"encendida": mueble.encendida,
			"volteado": mueble.volteado,
		}
		if mueble.apoyado_en != null:
			entrada["sobre"] = validos.find(mueble.apoyado_en)
		colocados.append(entrada)
	# Lo de esta habitación va en su entrada; lo de las otras habitaciones se deja como estaba en el archivo.
	var datos := Partida.leer()
	var habitaciones: Dictionary = datos.get("habitaciones", {})
	var con_reproductor := _hay_reproductor_aqui()
	habitaciones[_id_habitacion] = {"muebles": colocados, "luz": _luz.encendida, "reproductor": con_reproductor}
	Habitaciones.con_reproductor[_id_habitacion] = con_reproductor
	datos["habitaciones"] = habitaciones
	datos["habitacion_actual"] = Habitaciones.actual
	datos["desbloqueadas"] = Habitaciones.desbloqueadas
	datos["inventario"] = Inventario.rutas()
	datos["economia"] = Economia.a_datos()
	datos["musica"] = Musica.a_datos()
	datos["mate"] = Mate.a_datos()
	datos["misiones"] = Misiones.a_datos()
	datos["ropero"] = Ropero.a_datos()
	Partida.escribir(datos)
	Mate.confort_actual = Habitaciones.confort_de(_id_habitacion, datos)   # decorar mejora las mateadas


## Carga lo de toda la casa (monedas, música, inventario) y los muebles de ESTA habitación.
func _cargar(datos: Dictionary) -> void:
	if datos.is_empty():
		return
	if datos.has("economia"):
		Economia.cargar_datos(datos["economia"])
	if datos.has("musica"):
		Musica.cargar_datos(datos["musica"])
	if datos.has("inventario"):
		Inventario.cargar_rutas(datos["inventario"])
	if datos.has("mate"):
		Mate.cargar_datos(datos["mate"])
	if datos.has("misiones"):
		Misiones.cargar_datos(datos["misiones"])
	if datos.has("ropero"):
		Ropero.cargar_datos(datos["ropero"])
	var guardadas: Dictionary = datos.get("habitaciones", {})
	var entradas: Array = (guardadas.get(_id_habitacion, {}) as Dictionary).get("muebles", [])
	var creados: Array[Mueble] = []   # en el mismo orden que las entradas (null si la ficha ya no existe)
	for entrada in entradas:
		if not ResourceLoader.exists(entrada["ficha"]):
			creados.append(null)
			continue
		var ficha := load(entrada["ficha"]) as MuebleData
		var mueble := _crear_mueble(ficha, Vector2(entrada["x"], entrada["y"]))
		mueble.encendida = entrada.get("encendida", true)
		mueble.volteado = entrada.get("volteado", false)
		creados.append(mueble)
	# Los de la casa van a la casa; los que estaban sobre una mesa, a esa mesa (su posición es la de dentro de la mesa).
	for i in entradas.size():
		var mueble := creados[i]
		if mueble == null:
			continue
		var sobre: int = int(entradas[i].get("sobre", -1))
		if sobre < 0:
			mueble.acomodar_al_suelo()
			add_child(mueble)
		elif sobre < creados.size() and creados[sobre] != null:
			mueble.apoyado_en = creados[sobre]
			creados[sobre].add_child(mueble)
		else:
			mueble.free()


## ¿Hay un reproductor de música puesto en esta habitación?
func _hay_reproductor_aqui() -> bool:
	for nodo in get_tree().get_nodes_in_group("reproductores"):
		if not nodo.is_queued_for_deletion():
			return true
	return false


## La música es de toda la casa: suena si hay un reproductor puesto en cualquier habitación, aunque el estado guardado
## diga que sí.
func _actualizar_musica() -> void:
	var aqui := _hay_reproductor_aqui()
	Habitaciones.con_reproductor[_id_habitacion] = aqui
	Musica.fijar_permitido(aqui or Habitaciones.hay_reproductor_fuera_de(_id_habitacion))
