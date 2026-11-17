class_name MateTaza
extends Node2D
## El mate del minijuego (la imagen `mate_grande`, con yerba y bombilla). Su origen es el centro de la imagen. Para que se
## pueda llenar, `Vacio` es una mancha oscura que tapa la yerba de la imagen y se vuelve transparente a medida que sube el
## nivel; `Agua` es otra mancha que crece al cebar; los yuyos son motitas de color sobre la yerba.

const MOTAS_POR_PIZCA: int = 6
const RADIO_MOTA: float = 4.0

@onready var _vacio: Polygon2D = $Vacio
@onready var _agua: Polygon2D = $Agua
@onready var _flecos: Node2D = $Flecos


func _ready() -> void:
	poner_yerba(0.0)
	poner_agua(0.0)


## Nivel de yerba de 0 a 1: el mate vacío se va llenando.
func poner_yerba(nivel: float) -> void:
	_vacio.modulate.a = 1.0 - clampf(nivel, 0.0, 1.0)


## Nivel de agua de 0 a 1: una mancha oscura que se extiende por la yerba.
func poner_agua(nivel: float) -> void:
	_agua.visible = nivel > 0.05
	_agua.scale = Vector2(nivel, nivel)


func agregar_pizca(color: Color) -> void:
	for i in MOTAS_POR_PIZCA:
		var mota := Polygon2D.new()
		var puntos := PackedVector2Array()
		for k in 8:
			puntos.append(Vector2.from_angle(TAU * k / 8.0) * RADIO_MOTA)
		mota.polygon = puntos
		mota.color = color
		mota.position = $Boca.position + Vector2(randf_range(-34.0, 34.0), randf_range(-9.0, 9.0))
		_flecos.add_child(mota)


func boca_global() -> Vector2:
	return $Boca.global_position
