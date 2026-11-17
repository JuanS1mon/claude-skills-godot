## Muñeco de prueba: no se mueve, recibe daño, muestra el número y se reinicia.
extends StaticBody3D

@export var vida_max := 100
@export var tiempo_reinicio := 1.2
@export var color_golpe := Color(1.0, 0.35, 0.3)

@onready var sprite: AnimatedSprite3D = $Sprite
@onready var etiqueta_vida: Label3D = $Vida

var vida := 0
var _base_sprite := Vector3.ZERO
var _tween_golpe: Tween


func _ready() -> void:
	_base_sprite = sprite.position
	sprite.animation_finished.connect(_al_terminar_animacion)
	_reiniciar()


func _al_terminar_animacion() -> void:
	if sprite.animation == &"golpe" and vida > 0:
		sprite.play("quieto")


func recibir_dano(cantidad: int, punto: Vector3) -> void:
	if vida <= 0:
		return
	vida = maxi(vida - cantidad, 0)
	_actualizar_etiqueta()
	_mostrar_numero(cantidad, punto)
	_golpe_visual(signf(global_position.x - punto.x))
	if vida <= 0:
		etiqueta_vida.text = "¡KO!"
		sprite.play("ko")
		await get_tree().create_timer(tiempo_reinicio).timeout
		_reiniciar()
		return
	sprite.play("golpe")
	sprite.frame = 0


func _reiniciar() -> void:
	vida = vida_max
	sprite.play("quieto")
	_actualizar_etiqueta()


func _actualizar_etiqueta() -> void:
	etiqueta_vida.text = "%d / %d" % [vida, vida_max]


func _golpe_visual(lado: float) -> void:
	if _tween_golpe:
		_tween_golpe.kill()
	sprite.modulate = color_golpe
	sprite.position = _base_sprite + Vector3(lado * 0.15, 0.0, 0.0)
	_tween_golpe = create_tween().set_parallel()
	_tween_golpe.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	_tween_golpe.tween_property(sprite, "position", _base_sprite, 0.12) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _mostrar_numero(cantidad: int, punto: Vector3) -> void:
	var n := Label3D.new()
	n.text = str(cantidad)
	n.font_size = 64
	n.outline_size = 12
	n.modulate = Color(1.0, 0.9, 0.3)
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.no_depth_test = true
	get_parent().add_child(n)
	n.global_position = Vector3(punto.x + randf_range(-0.2, 0.2), punto.y + 0.3, 0.5)
	var t := n.create_tween().set_parallel()
	t.tween_property(n, "position:y", n.position.y + 1.0, 0.6).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "modulate:a", 0.0, 0.6).set_delay(0.2)
	t.chain().tween_callback(n.queue_free)
