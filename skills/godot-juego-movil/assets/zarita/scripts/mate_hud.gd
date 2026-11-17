class_name MateHud
extends PanelContainer
## Franja del mate en la interfaz: la energía de Zarita, cuánta yerba y agua caliente le quedan, y tres botones: tomar mate,
## comprar yerba (con Destellos) y calentar agua (solo se puede en la cocina). Solo avisa con señales; la casa decide qué hacer
## (ver casa.gd). Lee el estado de la clase Mate cada cuadro, que es barato.

signal pedido_tomar
signal pedido_yerba
signal pedido_agua

@onready var _energia: ProgressBar = $Fila/Energia
@onready var _yerba: Button = $Fila/Yerba
@onready var _agua: Button = $Fila/Agua
@onready var _tomar: Button = $Fila/Tomar


func _ready() -> void:
	$Fila/Tomar.pressed.connect(pedido_tomar.emit)
	_yerba.pressed.connect(pedido_yerba.emit)
	_agua.pressed.connect(pedido_agua.emit)


func _process(_delta: float) -> void:
	_energia.value = Mate.energia
	_yerba.text = "Yerba %d" % Mate.yerba
	_agua.text = "Agua %d" % Mate.agua_caliente
	var bonus := Mate.bonus_confort()
	_tomar.text = "Mate +%d" % bonus if bonus > 0 else "Mate"
