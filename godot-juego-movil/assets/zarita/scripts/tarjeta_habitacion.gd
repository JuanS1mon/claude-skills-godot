class_name TarjetaHabitacion
extends Button
## Una habitación en el mapa de la casa: su color o imagen, su nombre y, si está bloqueada, cuántas gemas cuesta.
## Solo avisa con `elegida`; el mapa decide qué hacer (viajar, cerrarse o pedir confirmación para desbloquear).

signal elegida(ficha: HabitacionData)

var ficha: HabitacionData

@onready var _color: ColorRect = $Vista/Color
@onready var _icono: TextureRect = $Vista/Icono
@onready var _velo: ColorRect = $Vista/Velo
@onready var _cartel: Label = $Vista/Cartel
@onready var _nombre: Label = $Nombre
@onready var _precio: HBoxContainer = $Precio
@onready var _cantidad: Label = $Precio/Cantidad
@onready var _aqui: Label = $Aqui
@onready var _confort: Label = $Vista/Confort


func _ready() -> void:
	pressed.connect(func() -> void: elegida.emit(ficha))


## Se llama justo después de añadir la tarjeta al mapa.
func configurar(hab: HabitacionData, desbloqueada: bool, es_actual: bool, confort: int = 0) -> void:
	ficha = hab
	_nombre.text = hab.nombre
	_color.color = hab.color_mapa
	_icono.texture = hab.icono
	_velo.visible = not desbloqueada
	_cartel.visible = not desbloqueada
	_precio.visible = not desbloqueada
	_cantidad.text = str(hab.precio_gemas)
	_aqui.visible = es_actual
	_confort.visible = desbloqueada
	_confort.text = "Confort %d" % confort
