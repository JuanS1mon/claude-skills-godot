## HUD del prototipo: corazones y estrellas arriba a la derecha, datos de depuración a la izquierda.
## Nodos: Texto (Label), Arriba/Corazones (HBoxContainer), Arriba/Estrellas (Label).
extends CanvasLayer

@export var jugador: CharacterBody3D
@export var corazon_lleno: Texture2D
@export var corazon_vacio: Texture2D

@onready var texto: Label = $Texto
@onready var corazones: HBoxContainer = $Arriba/Corazones
@onready var etiqueta_estrellas: Label = $Arriba/Estrellas

var estrellas := 0
var _total := 0
var _barra_jefe: ProgressBar
var _nombre_jefe: Label


## Barra de vida del jefe abajo al centro, estilo pelea de jefe.
func mostrar_jefe(jefe: Node) -> void:
	if _barra_jefe == null:
		_nombre_jefe = Label.new()
		_nombre_jefe.text = "JABALÍ DE GUERRA"
		_nombre_jefe.add_theme_font_size_override("font_size", 22)
		_nombre_jefe.add_theme_color_override("font_outline_color", Color.BLACK)
		_nombre_jefe.add_theme_constant_override("outline_size", 6)
		_nombre_jefe.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_nombre_jefe.position = Vector2(-120, -86)
		add_child(_nombre_jefe)
		_barra_jefe = ProgressBar.new()
		_barra_jefe.show_percentage = false
		_barra_jefe.custom_minimum_size = Vector2(520, 22)
		_barra_jefe.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_barra_jefe.position = Vector2(-260, -54)
		var fondo := StyleBoxFlat.new()
		fondo.bg_color = Color(0.1, 0.08, 0.1, 0.8)
		fondo.set_corner_radius_all(6)
		var lleno := StyleBoxFlat.new()
		lleno.bg_color = Color(0.85, 0.25, 0.2)
		lleno.set_corner_radius_all(6)
		_barra_jefe.add_theme_stylebox_override("background", fondo)
		_barra_jefe.add_theme_stylebox_override("fill", lleno)
		add_child(_barra_jefe)
	_barra_jefe.max_value = jefe.vida_max
	_barra_jefe.value = jefe.vida
	_barra_jefe.visible = true
	_nombre_jefe.visible = true
	jefe.vida_cambio.connect(func(v, _m): if is_instance_valid(_barra_jefe): _barra_jefe.value = v)


func ocultar_jefe() -> void:
	if _barra_jefe:
		_barra_jefe.visible = false
		_nombre_jefe.visible = false


func _ready() -> void:
	add_to_group("hud")
	if jugador:
		jugador.vida_cambio.connect(_al_cambiar_vida)
	_contar_estrellas.call_deferred()


func _contar_estrellas() -> void:
	_total = get_tree().get_nodes_in_group("estrella").size()
	_actualizar_estrellas()


func sumar_estrella() -> void:
	estrellas += 1
	_actualizar_estrellas()
	var t := etiqueta_estrellas.create_tween()
	etiqueta_estrellas.pivot_offset = etiqueta_estrellas.size / 2.0
	t.tween_property(etiqueta_estrellas, "scale", Vector2.ONE * 1.4, 0.1)
	t.tween_property(etiqueta_estrellas, "scale", Vector2.ONE, 0.2)


func _actualizar_estrellas() -> void:
	etiqueta_estrellas.text = "★ %d / %d" % [estrellas, _total]


func _al_cambiar_vida(vida: int, vida_max: int) -> void:
	for h in corazones.get_children():
		h.queue_free()
	for i in vida_max:
		var r := TextureRect.new()
		r.texture = corazon_lleno if i < vida else corazon_vacio
		r.custom_minimum_size = Vector2(40, 36)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		corazones.add_child(r)


func _process(_delta: float) -> void:
	if not jugador:
		return
	var ayuda_poder := ""
	match jugador.poder:
		"escarabajo": ayuda_poder = "  (S + K mantenido: cubrirse)"
		"volador": ayuda_poder = "  (mantener Espacio tras el doble salto: volar %.1f s)" % maxf(jugador.t_vuelo, 0.0)
		"slime": ayuda_poder = "  (se pega a cualquier pared; S para deslizarse)"
	var carga: float = maxf(jugador.carga_disparo, jugador.carga_lanzar)
	texto.text = "FPS %d   estado: %s   vel: (%.1f, %.1f)\nsaltos extra: %d   dash: %s   carga: %s\ndisparo: %s %s   poder: %s%s\n\nA/D: mover   W/S: apuntar arriba/abajo   Espacio: saltar (x2)   Shift/L: dash\nJ/clic izq: disparar (mantener = cargar)   Q: cambiar disparo   H: golpe\nK/clic der: agarrar; con algo en las manos, soltar K lo arroja (mantener = más fuerte)\n   S + K: apoyar la caja / absorber el poder del enemigo   W + K: lanzar hacia arriba\nPared: empujá contra ella para deslizarte, Espacio para saltar   R: reiniciar" % [
		Engine.get_frames_per_second(),
		jugador.estado,
		jugador.velocity.x, jugador.velocity.y,
		jugador._saltos_restantes,
		"listo" if jugador._t_enfriamiento_dash <= 0.0 and jugador._dashes_restantes > 0 else "esperando",
		"%d %%" % int(carga * 100.0) if carga > 0.0 else "-",
		jugador.tipo_disparo,
		"(de %d)" % jugador.tipos_disparo.size(),
		jugador.poder if jugador.poder != "" else "ninguno",
		ayuda_poder,
	]
