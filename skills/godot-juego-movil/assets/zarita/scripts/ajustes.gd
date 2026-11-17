extends Control
## Ajustes: botón con una tuerca (arriba a la derecha) que abre un panel con el sonido (activado y volumen)
## y el lado de la pantalla donde va el joystick. Se guardan en user://ajustes.cfg.

## Se emite al elegir el lado del joystick (true = a la derecha).
signal joystick_lado_cambiado(derecha: bool)

const RUTA_GUARDADO: String = "user://ajustes.cfg"

var joystick_derecha: bool = false
var sonido_activo: bool = true
var volumen: float = 0.8

@onready var _boton: Button = $BotonAjustes
@onready var _panel: PanelContainer = $Panel
@onready var _boton_sonido: Button = $Panel/Caja/BotonSonido
@onready var _volumen: HSlider = $Panel/Caja/Volumen
@onready var _izquierda: Button = $Panel/Caja/LadoJoystick/BotonIzquierda
@onready var _derecha: Button = $Panel/Caja/LadoJoystick/BotonDerecha


func _ready() -> void:
	_cargar()
	_panel.visible = false   # en el editor se ve abierto para poder diseñarlo
	# Los dos botones del joystick son pestañas de un mismo grupo: solo uno queda marcado.
	var grupo := ButtonGroup.new()
	for boton in [_izquierda, _derecha]:
		boton.theme_type_variation = &"Pestana"
		boton.button_group = grupo
	_boton_sonido.theme_type_variation = &"Pestana"
	_boton.toggled.connect(_panel.set_visible)
	$Panel/Caja/BotonCerrar.pressed.connect(func() -> void: _boton.button_pressed = false)
	_boton_sonido.toggled.connect(_al_alternar_sonido)
	_volumen.value_changed.connect(_al_cambiar_volumen)
	_izquierda.pressed.connect(_elegir_lado.bind(false))
	_derecha.pressed.connect(_elegir_lado.bind(true))
	_mostrar_valores()
	_aplicar_sonido()


## Lo que se ve en el panel según los valores actuales (sin disparar las señales).
func _mostrar_valores() -> void:
	_boton_sonido.set_pressed_no_signal(sonido_activo)
	_boton_sonido.text = "Activado" if sonido_activo else "Silenciado"
	_volumen.set_value_no_signal(volumen)
	_volumen.editable = sonido_activo
	_izquierda.set_pressed_no_signal(not joystick_derecha)
	_derecha.set_pressed_no_signal(joystick_derecha)


func _al_alternar_sonido(activo: bool) -> void:
	sonido_activo = activo
	_mostrar_valores()
	_aplicar_sonido()
	_guardar()


func _al_cambiar_volumen(valor: float) -> void:
	volumen = valor
	_aplicar_sonido()
	_guardar()


func _elegir_lado(derecha: bool) -> void:
	joystick_derecha = derecha
	joystick_lado_cambiado.emit(derecha)
	_guardar()


## Todo el sonido del juego pasa por el bus Master: se silencia o se baja ahí.
func _aplicar_sonido() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, not sonido_activo or volumen <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volumen, 0.001)))


func _guardar() -> void:
	var archivo := ConfigFile.new()
	archivo.set_value("ajustes", "joystick_derecha", joystick_derecha)
	archivo.set_value("ajustes", "sonido_activo", sonido_activo)
	archivo.set_value("ajustes", "volumen", volumen)
	archivo.save(RUTA_GUARDADO)


func _cargar() -> void:
	var archivo := ConfigFile.new()
	if archivo.load(RUTA_GUARDADO) != OK:
		return
	joystick_derecha = archivo.get_value("ajustes", "joystick_derecha", joystick_derecha)
	sonido_activo = archivo.get_value("ajustes", "sonido_activo", sonido_activo)
	volumen = archivo.get_value("ajustes", "volumen", volumen)
