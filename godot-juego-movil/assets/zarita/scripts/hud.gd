extends Control
## Interfaz fija de la casa, hecha con nodos en el editor (scenes/hud.tscn): arriba las monedas y gemas; abajo la barra
## de cuatro botones con icono (Decorar, Tienda, Luz, Clima), al alcance del pulgar; el joystick; y la tuerca de ajustes.
## Este script solo avisa de los toques con señales (la casa las conecta) y muestra los saldos y un aviso temporal.

signal decorar_alternado(activo: bool)
signal tienda_alternada(activa: bool)
signal luz_alternada(encendida: bool)

## Icono del botón Luz cuando está apagada (el de encendida es el que ya tiene el nodo Icono).
@export var icono_luz_apagada: Texture2D

@onready var _monedas: Label = $BarraSuperior/Monedas/Fila/Cantidad
@onready var _gemas: Label = $BarraSuperior/Gemas/Fila/Cantidad
@onready var _boton_tienda: Button = $BarraInferior/BotonTienda
@onready var _icono_luz: TextureRect = $BarraInferior/BotonLuz/Icono
@onready var _aviso: Label = $Aviso

var _icono_luz_encendida: Texture2D
var _tween_aviso: Tween


func _ready() -> void:
	# En el editor el aviso se ve de muestra; al jugar empieza escondido.
	_aviso.text = ""
	_aviso.modulate.a = 0.0
	_icono_luz_encendida = _icono_luz.texture
	$BarraInferior/BotonDecorar.toggled.connect(decorar_alternado.emit)
	_boton_tienda.toggled.connect(tienda_alternada.emit)
	$BarraInferior/BotonLuz.toggled.connect(_al_alternar_luz)
	Economia.cambio.connect(_actualizar)
	_actualizar()


func _actualizar() -> void:
	_monedas.text = str(Economia.monedas)
	_gemas.text = str(Economia.gemas)


func _al_alternar_luz(encendida: bool) -> void:
	_icono_luz.texture = _icono_luz_encendida if encendida else icono_luz_apagada
	luz_alternada.emit(encendida)


## Deja el botón Luz como está la luz de la habitación (al cambiar de habitación), sin avisar a la casa.
func fijar_luz(encendida: bool) -> void:
	$BarraInferior/BotonLuz.set_pressed_no_signal(encendida)
	_icono_luz.texture = _icono_luz_encendida if encendida else icono_luz_apagada


## La tienda se cerró por su propio botón: suelta el botón de la barra.
func desmarcar_tienda() -> void:
	_boton_tienda.button_pressed = false


## Un letrero que aparece unos instantes sobre la barra (p. ej. el clima elegido).
func avisar(texto: String) -> void:
	_aviso.text = texto
	if _tween_aviso != null:
		_tween_aviso.kill()
	_aviso.modulate.a = 1.0
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(1.4)
	_tween_aviso.tween_property(_aviso, "modulate:a", 0.0, 0.5)
