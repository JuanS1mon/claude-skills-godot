class_name CazaBichitos
extends CanvasLayer
## Minijuego de la noche: bichitos de luz parpadean entre los helechos y hay que tocarlos (la red de Zarita) antes de que se
## apaguen. Va en un CanvasLayer para que el tinte de la noche (CicloDia) no lo apague. Cada uno da Destellos (la moneda común) y los raros pueden dejar un ingrediente para el mate. Dura
## SEGUNDOS_PARTIDA y vuelve a la casa. Los bichitos son fichas BichitoData en data/bichitos/.

const ESCENA_BICHITO: PackedScene = preload("res://scenes/bichito.tscn")
const ESCENA_FUNDIDO: PackedScene = preload("res://scenes/fundido.tscn")
const ESCENA_CASA: String = "res://scenes/casa.tscn"
const CARPETA_BICHITOS: String = "res://data/bichitos/"
const SEGUNDOS_PARTIDA: float = 30.0
const MAX_A_LA_VEZ: int = 6
const ESPERA_ENTRE_BICHITOS: float = 0.7
## Zona donde aparecen (deja libres la parte de arriba y los botones de abajo).
const ZONA: Rect2 = Rect2(80.0, 260.0, 560.0, 700.0)

@onready var _bichitos: Node2D = $Raiz/Bichitos
@onready var _marcador: Label = $Raiz/Marcador
@onready var _tiempo: Label = $Raiz/Tiempo
@onready var _resultado: PanelContainer = $Raiz/Resultado
@onready var _texto_resultado: Label = $Raiz/Resultado/Texto
@onready var _boton_volver: Button = $Raiz/BotonVolver

var _fichas: Array[BichitoData] = []
var _restante: float = SEGUNDOS_PARTIDA
var _espera: float = 0.0
var _jugando: bool = true
var _destellos: int = 0
var _atrapados: int = 0
var _ingredientes: Array[BlendData] = []
var _fundido: CanvasLayer
var _saliendo: bool = false


func _ready() -> void:
	for archivo in ResourceLoader.list_directory(CARPETA_BICHITOS):
		if archivo.ends_with("/"):
			continue
		var ficha := load(CARPETA_BICHITOS + archivo) as BichitoData
		if ficha != null:
			_fichas.append(ficha)
	_resultado.visible = false   # en el editor se ve abierto para poder diseñarlo
	_boton_volver.pressed.connect(volver)
	_fundido = ESCENA_FUNDIDO.instantiate()
	add_child(_fundido)
	_fundido.entrar()
	_actualizar_marcador()


func _process(delta: float) -> void:
	if not _jugando:
		return
	_restante -= delta
	_tiempo.text = "%d s" % ceili(maxf(_restante, 0.0))
	if _restante <= 0.0:
		_terminar()
		return
	_espera -= delta
	if _espera <= 0.0 and _bichitos.get_child_count() < MAX_A_LA_VEZ and not _fichas.is_empty():
		_espera = ESPERA_ENTRE_BICHITOS
		_crear_bichito()


func _input(evento: InputEvent) -> void:
	if not _jugando:
		return
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		atrapar_en(evento.position)


## Atrapa el bichito más cercano al punto tocado (si alguno lo alcanza). Devuelve true si atrapó.
func atrapar_en(punto: Vector2) -> bool:
	var elegido: Bichito
	var mejor := INF
	for nodo in _bichitos.get_children():
		var b := nodo as Bichito
		if b != null and b.contiene(punto) and punto.distance_to(b.global_position) < mejor:
			mejor = punto.distance_to(b.global_position)
			elegido = b
	if elegido == null:
		return false
	elegido.capturar()
	return true


func _crear_bichito() -> void:
	var b := ESCENA_BICHITO.instantiate() as Bichito
	_bichitos.add_child(b)
	b.iniciar(BichitoData.elegir(_fichas), ZONA)
	b.atrapado.connect(_al_atrapar)


func _al_atrapar(b: Bichito) -> void:
	_atrapados += 1
	Misiones.registrar(MisionData.Tipo.ATRAPAR_BICHITOS)
	_destellos += b.ficha.destellos
	Economia.ganar(b.ficha.destellos, MuebleData.Moneda.COMUN)
	var texto := "+%d" % b.ficha.destellos
	if b.ficha.ingrediente != null and randf() < b.ficha.probabilidad_ingrediente:
		_ingredientes.append(b.ficha.ingrediente)
		Mate.blend = b.ficha.ingrediente   # la mezcla que usará en su próxima mateada
		texto += "  ¡%s!" % b.ficha.ingrediente.nombre
	_flotar_texto(texto, b.global_position, b.ficha.color)
	_actualizar_marcador()


## Un letrero que sube y se desvanece donde estaba el bichito.
func _flotar_texto(texto: String, donde: Vector2, color: Color) -> void:
	var letrero := Label.new()
	letrero.text = texto
	letrero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letrero.position = donde - Vector2(60.0, 30.0)
	letrero.add_theme_font_size_override("font_size", 30)
	letrero.add_theme_color_override("font_color", color.lightened(0.3))
	letrero.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	letrero.add_theme_constant_override("outline_size", 8)
	$Raiz.add_child(letrero)
	var tween := create_tween().set_parallel()
	tween.tween_property(letrero, "position:y", letrero.position.y - 90.0, 0.9)
	tween.tween_property(letrero, "modulate:a", 0.0, 0.9)
	tween.chain().tween_callback(letrero.queue_free)


func _actualizar_marcador() -> void:
	_marcador.text = "Destellos: %d" % _destellos


func _terminar() -> void:
	_jugando = false
	_tiempo.text = "0 s"
	for hijo in _bichitos.get_children():
		hijo.queue_free()
	var texto := "Atrapaste %d bichitos\n+%d Destellos" % [_atrapados, _destellos]
	if not _ingredientes.is_empty():
		texto += "\nIngrediente: %s" % _ingredientes.back().nombre
	_texto_resultado.text = texto
	_resultado.visible = true
	Partida.guardar_progreso()   # los Destellos y la mezcla quedan guardados


## Vuelve a la casa (a la habitación en que estabas).
func volver() -> void:
	if _saliendo:
		return
	_saliendo = true
	if _jugando:
		_jugando = false
		Partida.guardar_progreso()
	await _fundido.salir()
	get_tree().change_scene_to_file(ESCENA_CASA)
