## Estrella para juntar: flota, gira un poco y al tocarla el jugador suma al contador del HUD.
## Cada estrella puede dar un tipo de disparo distinto (se elige en el Inspector).
extends Area3D

## Tipo de disparo que desbloquea al juntarla.
@export_enum("ninguno", "triple", "rebote", "explosivo") var disparo := "ninguno"

const COLORES := {
	"triple": Color(0.6, 1.0, 0.45),
	"rebote": Color(0.45, 0.9, 1.0),
	"explosivo": Color(1.0, 0.5, 0.4),
}

@onready var sprite: Sprite3D = $Sprite

var _y := 0.0
var _t := 0.0
var _tomada := false


func _ready() -> void:
	add_to_group("estrella")
	_y = sprite.position.y
	body_entered.connect(_al_entrar)
	if disparo != "ninguno":
		# El color y el cartel avisan qué disparo da.
		var color: Color = COLORES.get(disparo, Color.WHITE)
		sprite.modulate = color
		$Luz.light_color = color
		var cartel := Label3D.new()
		cartel.text = disparo
		cartel.font_size = 36
		cartel.outline_size = 10
		cartel.modulate = color
		cartel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cartel.no_depth_test = true
		cartel.position = Vector3(0.0, 0.75, 0.0)
		add_child(cartel)


func _process(delta: float) -> void:
	_t += delta
	sprite.position.y = _y + sin(_t * 2.5) * 0.12
	sprite.rotation.z = sin(_t * 1.7) * 0.15


func _al_entrar(cuerpo: Node3D) -> void:
	if _tomada or not cuerpo.is_in_group("jugador"):
		return
	_tomada = true
	get_tree().call_group("hud", "sumar_estrella")
	if cuerpo.has_method("desbloquear_disparo"):
		cuerpo.desbloquear_disparo(disparo)
	var t := create_tween().set_parallel()
	t.tween_property(sprite, "scale", Vector3.ONE * 1.8, 0.3)
	t.tween_property(sprite, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(queue_free)
