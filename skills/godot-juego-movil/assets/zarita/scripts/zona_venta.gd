extends PanelContainer
## Zona de venta: una franja arriba que aparece mientras se arrastra un mueble en modo Decorar.
## Si se suelta encima, la casa pregunta si se vende. El borde se ilumina cuando el mueble está encima.

@onready var _texto: Label = $Fila/Texto
@onready var _resplandor: Panel = $Resplandor

var _tween: Tween


func _ready() -> void:
	# En el editor se ve encendida para poder diseñarla; al jugar empieza escondida.
	visible = false
	_resplandor.visible = false


## Muestra u oculta la franja; con `texto` cambia lo que dice (p. ej. cuánto dan por el mueble).
func mostrar(activa: bool, texto: String = "") -> void:
	if texto != "":
		_texto.text = texto
	visible = activa
	if not activa:
		resaltar(false)


## Enciende (o apaga) el resplandor del borde: avisa de que soltar aquí vende el mueble.
func resaltar(activo: bool) -> void:
	if activo == _resplandor.visible:
		return
	if _tween != null:
		_tween.kill()
	_resplandor.visible = activo
	if not activo:
		return
	_resplandor.modulate.a = 1.0
	_tween = create_tween().set_loops()
	_tween.tween_property(_resplandor, "modulate:a", 0.45, 0.4).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_resplandor, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
