extends Node2D
## El monte: el exterior de la casa. Zarita lo recorre con el joystick, con la hora y el clima reales de toda la casa (la
## tinta del día es la del mundo y la lluvia cae por delante), y se encuentra con sus amigos Teo y Don Jacinto: tocarlos abre su
## diálogo (ver Conversaciones). El botón «Volver a casa» regresa a la casa. Se entra desde el botón Explorar del mapa.

const ESCENA_CASA: String = "res://scenes/casa.tscn"
## Id con el que cuenta para las misiones de explorar (como una habitación más).
const ID_LUGAR: String = "monte"

@onready var _dialogo: DialogoPersonaje = $DialogoPersonaje
@onready var _fundido: CanvasLayer = $Fundido

var _saliendo: bool = false


func _ready() -> void:
	y_sort_enabled = true
	_cargar_progreso()
	Misiones.registrar_visita(ID_LUGAR)
	$Interfaz/Raiz/BotonVolver.pressed.connect(volver)
	for amigo in get_tree().get_nodes_in_group("amigos"):
		amigo.hablar.connect(func(id_personaje: String) -> void: _dialogo.abrir(Conversaciones.de(id_personaje)))
	_dialogo.accion_hecha.connect(Partida.guardar_progreso)
	_fundido.entrar()


func _process(delta: float) -> void:
	Mate.actualizar(delta)   # la energía de Zarita baja también afuera


## Si se abre esta escena sola (F6) hay que leer la partida; viniendo de la casa ya está todo en memoria, y esto no cambia nada.
func _cargar_progreso() -> void:
	var datos := Partida.leer()
	if datos.has("economia"):
		Economia.cargar_datos(datos["economia"])
	if datos.has("mate"):
		Mate.cargar_datos(datos["mate"])
	if datos.has("misiones"):
		Misiones.cargar_datos(datos["misiones"])
	if datos.has("ropero"):
		Ropero.cargar_datos(datos["ropero"])
	Habitaciones.cargar_datos(datos)


## Guarda y vuelve a la casa (a la habitación en que estaba).
func volver() -> void:
	if _saliendo:
		return
	_saliendo = true
	Partida.guardar_progreso()
	await _fundido.salir()
	get_tree().change_scene_to_file(ESCENA_CASA)
