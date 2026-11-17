class_name MapaCasa
extends CanvasLayer
## Mapa de la casa: el ceibo de Zarita visto desde afuera, con el clima y la hora reales, y una tarjeta por habitación
## (las fichas de data/habitaciones/). Tocar una abierta lleva allí; tocar una bloqueada pide confirmación y la
## desbloquea con gemas. Va en su propia capa, por encima del HUD. La casa lo abre con el botón Mapa.

## Se pidió ir a esta habitación (id de la ficha).
signal viajar(id: String)
## Se pagó y se abrió esta habitación (la casa guarda la partida).
signal desbloqueada(id: String)
## Se pidió ir a cazar bichitos de luz (la casa decide si es de noche).
signal cazar
## Se pidió salir a explorar el monte.
signal explorar
## Se tocó a un amigo (id de su ficha en data/personajes/): la casa abre el diálogo.
signal hablar(id_personaje: String)

const ESCENA_TARJETA: PackedScene = preload("res://scenes/tarjeta_habitacion.tscn")
const SEGUNDOS_AVISO: float = 2.6

@onready var _raiz: Control = $Raiz
@onready var _decorado: Control = $Raiz/Decorado
@onready var _grilla: GridContainer = $Raiz/Grilla
@onready var _gemas: Label = $Raiz/PastillaGemas/Fila/Cantidad
@onready var _aviso: Label = $Raiz/Aviso
@onready var _titulo: Label = $Raiz/Titulo
@onready var _confirmar: PanelContainer = $Raiz/Confirmar
@onready var _pregunta: Label = $Raiz/Confirmar/Caja/Pregunta
@onready var _boton_aceptar: Button = $Raiz/Confirmar/Caja/Botones/Aceptar
@onready var _boton_cancelar: Button = $Raiz/Confirmar/Caja/Botones/Cancelar

var _id_actual: String = ""
var _pendiente: HabitacionData
var _tween_aviso: Tween


func _ready() -> void:
	$Raiz/BotonCerrar.pressed.connect(cerrar)
	$Raiz/BotonJacinto.pressed.connect(func() -> void:
		cerrar()
		hablar.emit("don_jacinto"))
	$Raiz/BotonTeo.pressed.connect(func() -> void:
		cerrar()
		hablar.emit("teo"))
	$Raiz/BotonMonte.pressed.connect(func() -> void:
		cerrar()
		explorar.emit())
	$Raiz/BotonCaza.pressed.connect(func() -> void:
		cerrar()
		cazar.emit())
	_boton_aceptar.pressed.connect(_aceptar_desbloqueo)
	_boton_cancelar.pressed.connect(func() -> void: _confirmar.visible = false)
	Economia.cambio.connect(_actualizar_gemas)
	_actualizar_gemas()
	cerrar()   # en el editor se ve abierto para poder diseñarlo


func _process(_delta: float) -> void:
	# El mundo se tiñe con la hora y el clima igual que la casa (CicloDia solo tiñe la capa del mundo, no esta).
	_decorado.modulate = CicloDia.color_en(CicloDia.tabla_ambiente) * CicloDia.clima.mult_ambiente()


## Abre el mapa. `id_actual` es la habitación en que está Zarita.
func abrir(id_actual: String) -> void:
	_id_actual = id_actual
	_construir_tarjetas()
	_confirmar.visible = false
	_aviso.modulate.a = 0.0
	_actualizar_gemas()
	_raiz.process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	visible = true


func cerrar() -> void:
	visible = false
	set_process(false)
	_raiz.process_mode = Node.PROCESS_MODE_DISABLED   # la lluvia y las nubes no gastan nada con el mapa cerrado


func _construir_tarjetas() -> void:
	for hijo in _grilla.get_children():
		hijo.queue_free()
	var partida := Partida.leer()
	var total := 0
	for hab in Habitaciones.catalogo():
		var tarjeta := ESCENA_TARJETA.instantiate() as TarjetaHabitacion
		_grilla.add_child(tarjeta)
		var confort := Habitaciones.confort_de(hab.id(), partida)
		total += confort
		tarjeta.configurar(hab, Habitaciones.esta_desbloqueada(hab.id()), hab.id() == _id_actual, confort)
		tarjeta.elegida.connect(_al_elegir)
	_titulo.text = "Casa de Zarita\nConfort %d" % total


func _al_elegir(hab: HabitacionData) -> void:
	var id := hab.id()
	if id == _id_actual:
		cerrar()
	elif Habitaciones.esta_desbloqueada(id):
		cerrar()
		viajar.emit(id)
	else:
		_pendiente = hab
		_pregunta.text = "¿Desbloquear %s por %d gemas?" % [hab.nombre, hab.precio_gemas]
		_confirmar.visible = true


func _aceptar_desbloqueo() -> void:
	_confirmar.visible = false
	if _pendiente == null:
		return
	var hab := _pendiente
	_pendiente = null
	if Habitaciones.desbloquear(hab.id()):
		_avisar("¡%s desbloqueada!" % hab.nombre)
		desbloqueada.emit(hab.id())
		_construir_tarjetas()
	else:
		_avisar("Te faltan %d gemas. Las consigues en la tienda." % (hab.precio_gemas - Economia.gemas))


func _actualizar_gemas() -> void:
	_gemas.text = str(Economia.gemas)


func _avisar(texto: String) -> void:
	_aviso.text = texto
	if _tween_aviso != null:
		_tween_aviso.kill()
	_aviso.modulate.a = 1.0
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(SEGUNDOS_AVISO)
	_tween_aviso.tween_property(_aviso, "modulate:a", 0.0, 0.5)
