class_name MateJuego
extends CanvasLayer
## Minijuego del mate (se entra tocando la pava de la cocina). Todo pasa en UNA sola pantalla, armada con escenas en
## scenes/mate_juego.tscn (cocina, pava, mate, bolsa de yerba y barras):
## - Pava: se arrastra a la hornalla de la cocina y el agua sube hacia 80° (se enfría despacio). Fuera de la hornalla, TOCARLA sirve el agua.
## - Yerba: mantener apretada la bolsa llena el mate; si se pasa de lleno, se cae la yerba (y se pierde una de más).
## - Yuyos: cada botón pone una pizca (hasta MAX_PIZCAS); la mezcla que más pizcas tenga es la que cuenta.
## Al servir, si el agua pasa de 80° Zarita se quema; el resultado sube su energía (Mate.beber_preparado).

const ESCENA_FUNDIDO: PackedScene = preload("res://scenes/fundido.tscn")
const ESCENA_CASA: String = "res://scenes/casa.tscn"
const CARPETA_BLENDS: String = "res://data/blends/"

const TEMP_AMBIENTE: float = 20.0
const TEMP_MIN_SERVIR: float = 60.0   # por debajo, el agua está demasiado fría para servir
const TEMP_BUENA_MIN: float = 70.0
const TEMP_BUENA_MAX: float = 80.0
const CALOR_POR_S: float = 3.5
const ENFRIA_POR_S: float = 0.8
const YERBA_POR_S: float = 38.0
const YERBA_BUENA_MIN: float = 50.0
const MAX_PIZCAS: int = 3
## Hasta cuántos píxeles puede moverse el dedo para que se cuente como toque y no como arrastre.
const TOLERANCIA_TOQUE: float = 20.0
const SEGUNDOS_ENTRE_GRANOS: float = 0.04
## Dónde queda la pava al verter (encima del mate) y cuánto se inclina.
## El pico queda a esta distancia de la boca del mate (la pava se acomoda sola para que el chorro caiga adentro).
const PICO_SOBRE_MATE: Vector2 = Vector2(4.0, -55.0)
const INCLINACION: float = -0.7
const LIMITE_ARRASTRE_MIN: Vector2 = Vector2(100.0, 330.0)
const LIMITE_ARRASTRE_MAX: Vector2 = Vector2(620.0, 800.0)

@onready var _cocina: CocinaMate = $Raiz/Cocina
@onready var _pava: PavaJuego = $Raiz/Pava
@onready var _mate: MateTaza = $Raiz/Mate
@onready var _bolsa: BolsaYerba = $Raiz/Bolsa
@onready var _barra_temp: BarraMedidor = $Raiz/BarraTemperatura
@onready var _barra_yerba: BarraMedidor = $Raiz/BarraYerba
@onready var _granos: Node2D = $Raiz/Granos
@onready var _chorro: Line2D = $Raiz/Chorro
@onready var _instruccion: Label = $Raiz/Instruccion
@onready var _estado: Label = $Raiz/Estado
@onready var _aviso: Label = $Raiz/Aviso
@onready var _caja_yuyos: HBoxContainer = $Raiz/Yuyos
@onready var _boton_volver: Button = $Raiz/BotonVolver
@onready var _zarita: AnimatedSprite2D = $Raiz/Zarita
@onready var _burbuja: PanelContainer = $Raiz/Burbuja
@onready var _texto_burbuja: Label = $Raiz/Burbuja/Texto

var _fundido: CanvasLayer
var _saliendo: bool = false
var _terminado: bool = false
var _tween_aviso: Tween

var _temp: float = TEMP_AMBIENTE
var _arrastrando: bool = false
var _desfase: Vector2 = Vector2.ZERO
var _inicio_toque: Vector2 = Vector2.ZERO
var _en_cocina: bool = false
var _sirviendo: bool = false
var _temp_servida: float = 0.0

var _nivel_yerba: float = 0.0
var _echando: bool = false
var _derramo: bool = false
var _espera_grano: float = 0.0

var _yuyos: Array[BlendData] = []
var _botones_yuyo: Array[Button] = []
var _pizcas: Dictionary = {}   # BlendData -> cantidad

var _agua_nivel: float = 0.0


func _ready() -> void:
	_zarita.visible = false   # en el editor se ven abiertos para poder diseñarlos
	_burbuja.visible = false
	_aviso.modulate.a = 0.0
	_chorro.visible = false
	_boton_volver.pressed.connect(volver)
	_cargar_yuyos()
	_crear_botones_yuyo()
	_fundido = ESCENA_FUNDIDO.instantiate()
	add_child(_fundido)
	_fundido.entrar()


## Los yuyos que se pueden poner: las fichas de data/blends/ que dan energía extra (la yerba común es la base, no un yuyo).
func _cargar_yuyos() -> void:
	for archivo in ResourceLoader.list_directory(CARPETA_BLENDS):
		if archivo.ends_with("/"):
			continue
		var ficha := load(CARPETA_BLENDS + archivo) as BlendData
		if ficha != null and ficha.energia_extra > 0:
			_yuyos.append(ficha)


## Un botón por yuyo dentro de la caja `Yuyos` de la escena (se crean aquí porque dependen de las fichas que haya).
func _crear_botones_yuyo() -> void:
	for ficha in _yuyos:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 24)
		b.modulate = ficha.color.lightened(0.5)
		b.pressed.connect(_poner_pizca.bind(ficha))
		_caja_yuyos.add_child(b)
		_botones_yuyo.append(b)
	_actualizar_botones_yuyo()


func _process(delta: float) -> void:
	if not _terminado and not _sirviendo:
		_en_cocina = _cocina.contiene_pava(_pava.global_position)
		if _en_cocina:
			_temp = minf(_temp + CALOR_POR_S * delta, 100.0)
		else:
			_temp = maxf(_temp - ENFRIA_POR_S * delta, TEMP_AMBIENTE)
		if _echando:
			_nivel_yerba += YERBA_POR_S * delta
			if _nivel_yerba > 100.0:
				_nivel_yerba = 100.0
				_derramo = true
			_espera_grano -= delta
			if _espera_grano <= 0.0:
				_espera_grano = SEGUNDOS_ENTRE_GRANOS
				_lanzar_grano(_nivel_yerba >= 100.0)
		_estado.text = _texto_estado()
	_actualizar_objetos()


## Pasa el estado del juego a las escenas (barras, cocina, vapor, mate y chorro de agua).
func _actualizar_objetos() -> void:
	_barra_temp.fijar(_temp)
	_barra_temp.fijar_color(Color(0.9, 0.25, 0.2, 0.8) if _temp > TEMP_BUENA_MAX else Color(0.95, 0.85, 0.4, 0.8))
	_barra_yerba.fijar(_nivel_yerba)
	_cocina.brillo = clampf((_temp - TEMP_AMBIENTE) / 60.0, 0.0, 1.0) if _en_cocina else 0.0
	_pava.vapor = _temp > 50.0 and not _terminado
	_mate.poner_yerba(_nivel_yerba / 100.0)
	_mate.poner_agua(_agua_nivel)
	_chorro.visible = _sirviendo and _agua_nivel < 1.0 and _pava.rotation < INCLINACION + 0.05
	if _chorro.visible:
		var punta := _pava.punta_global()
		_chorro.points = PackedVector2Array([punta, Vector2(punta.x - 6.0, _mate.boca_global().y - 5.0)])


func _texto_estado() -> String:
	var texto := "Agua: %d°" % int(_temp)
	if _temp > TEMP_BUENA_MAX:
		texto += "  ¡Se pasó!"
	elif _temp >= TEMP_BUENA_MIN:
		texto += "  ¡Justo!"
	if not _en_cocina and _temp >= TEMP_MIN_SERVIR:
		texto += "  ¡Tocala para cebar!"
	return texto


func _input(evento: InputEvent) -> void:
	if _terminado or _sirviendo:
		return
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		if evento.pressed:
			_al_apretar(evento.position)
		else:
			_al_soltar(evento.position)
	elif evento is InputEventMouseMotion and _arrastrando:
		_pava.position = (evento.position + _desfase).clamp(LIMITE_ARRASTRE_MIN, LIMITE_ARRASTRE_MAX)


func _al_apretar(punto: Vector2) -> void:
	if _pava.contiene(punto):
		_arrastrando = true
		_desfase = _pava.position - punto
		_inicio_toque = punto
	elif _bolsa.contiene(punto):
		_echando = true
		_bolsa.verter(true, _mate.boca_global())
		_espera_grano = 0.3


## Soltar la pava sin haberla movido es un toque: fuera de la hornalla, sirve el agua.
func _al_soltar(punto: Vector2) -> void:
	if _echando:
		_bolsa.verter(false, Vector2.ZERO)
	_echando = false
	if not _arrastrando:
		return
	_arrastrando = false
	if punto.distance_to(_inicio_toque) <= TOLERANCIA_TOQUE:
		_tocar_pava()


func _tocar_pava() -> void:
	if _en_cocina:
		_mostrar_aviso("Sacá la pava de la hornalla y tocala para cebar.")
	elif _temp < TEMP_MIN_SERVIR:
		_mostrar_aviso("Todavía está muy fría…")
	elif _nivel_yerba <= 0.0:
		_mostrar_aviso("Primero llená el mate de yerba.")
	else:
		_servir()


func _mostrar_aviso(texto: String) -> void:
	_aviso.text = texto
	if _tween_aviso:
		_tween_aviso.kill()
	_aviso.modulate.a = 1.0
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(2.0)
	_tween_aviso.tween_property(_aviso, "modulate:a", 0.0, 0.5)


func _poner_pizca(ficha: BlendData) -> void:
	if _total_pizcas() >= MAX_PIZCAS or _terminado or _sirviendo:
		return
	_pizcas[ficha] = int(_pizcas.get(ficha, 0)) + 1
	_mate.agregar_pizca(ficha.color)
	_actualizar_botones_yuyo()


func _total_pizcas() -> int:
	var total := 0
	for cantidad in _pizcas.values():
		total += int(cantidad)
	return total


func _actualizar_botones_yuyo() -> void:
	for i in _yuyos.size():
		var cantidad := int(_pizcas.get(_yuyos[i], 0))
		_botones_yuyo[i].text = "%s\n%d" % [_yuyos[i].nombre.replace("Mate con ", "").capitalize(), cantidad]
		_botones_yuyo[i].disabled = _total_pizcas() >= MAX_PIZCAS or _terminado or _sirviendo


## El yuyo con más pizcas es la mezcla del mate (null si no puso ninguno).
func _yuyo_elegido() -> BlendData:
	var mejor: BlendData
	var max_cantidad := 0
	for ficha in _yuyos:
		var cantidad := int(_pizcas.get(ficha, 0))
		if cantidad > max_cantidad:
			max_cantidad = cantidad
			mejor = ficha
	return mejor


## La pava viaja sobre el mate, se inclina y vierte el agua; después Zarita lo prueba.
func _servir() -> void:
	_sirviendo = true
	_arrastrando = false
	_echando = false
	_temp_servida = _temp
	_actualizar_botones_yuyo()
	var t := create_tween().set_parallel()
	# A tamaño completo (la pava ya está cerca del mate), girada INCLINACION, su pico debe quedar sobre la boca del mate.
	var pico := ($Raiz/Pava/Punta as Marker2D).position.rotated(INCLINACION)
	t.tween_property(_pava, "position", _mate.boca_global() + PICO_SOBRE_MATE - pico, 0.6)
	t.tween_property(_pava, "rotation", INCLINACION, 0.6)
	t.chain().tween_property(self, "_agua_nivel", 1.0, 1.4)
	t.chain().tween_callback(_terminar)


## Un grano de yerba: sale de la bolsa y cae al mate; si el mate ya está lleno, cae por los costados (se desperdicia).
func _lanzar_grano(afuera: bool) -> void:
	var grano := Polygon2D.new()
	var puntos := PackedVector2Array()
	for k in 8:
		puntos.append(Vector2.from_angle(TAU * k / 8.0) * 5.0)
	grano.polygon = puntos
	grano.color = Color(0.5, 0.55, 0.2)
	var boca := _mate.boca_global()
	var inicio := _bolsa.salida_global() + Vector2(0.0, randf_range(-10.0, 10.0))
	var destino := boca + Vector2(randf_range(-50.0, 50.0), 10.0)
	if afuera:
		var lado := 1.0 if randf() < 0.5 else -1.0
		inicio = boca + Vector2(lado * randf_range(60.0, 100.0), -20.0)
		destino = inicio + Vector2(lado * randf_range(40.0, 120.0), 300.0)
	grano.position = inicio
	_granos.add_child(grano)
	var t := create_tween().set_parallel()
	t.tween_property(grano, "position:x", destino.x, 0.7)
	t.tween_property(grano, "position:y", destino.y, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(grano, "modulate:a", 0.0, 0.3).set_delay(0.4)
	t.chain().tween_callback(grano.queue_free)


## Resultado: mezcla la calidad del agua y de la yerba, aplica la energía y deja que Zarita reaccione.
func _terminar() -> void:
	_terminado = true
	_sirviendo = false
	var temp_q := 1.0
	var frase := "¡Ahhh, qué mate más rico!"
	if _temp_servida > TEMP_BUENA_MAX:
		temp_q = 0.4
		frase = "¡Ay, me quemé!"
	elif _temp_servida < TEMP_BUENA_MIN:
		temp_q = 0.7
		frase = "Está un poco tibio… pero igual me gusta."
	var yerba_q := 1.0 if _nivel_yerba >= YERBA_BUENA_MIN else 0.7
	var antes := Mate.energia
	var extra := 1 if _derramo else 0
	Mate.beber_preparado(temp_q * yerba_q, extra, _yuyo_elegido())
	Partida.guardar_progreso()
	if _derramo:
		frase += "\n(Se te cayó yerba, perdiste una de más.)"
	_texto_burbuja.text = frase + "\n+%d energía" % int(round(Mate.energia - antes))
	_zarita.visible = true
	_zarita.play("beber")
	_pava.visible = false
	_barra_temp.visible = false
	_barra_yerba.visible = false
	_burbuja.visible = true
	_instruccion.text = ""
	_estado.text = ""
	_aviso.modulate.a = 0.0
	_actualizar_botones_yuyo()


## Vuelve a la casa (a la cocina en que estabas).
func volver() -> void:
	if _saliendo:
		return
	_saliendo = true
	await _fundido.salir()
	get_tree().change_scene_to_file(ESCENA_CASA)
