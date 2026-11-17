class_name NpcAmigo
extends Area2D
## Un amigo de Zarita en persona (Roberto, Martita, Homero) dentro del monte. Se toca para hablar: avisa con `hablar` y la escena
## del monte abre el diálogo (lo que dice lo decide Conversaciones). Cada amigo tiene su escena heredada de npc_amigo.tscn
## (roberto.tscn, martita.tscn, homero.tscn). El origen es la base (los pies).
##
## Tres formas de dibujarlo:
##  1. Sin arte: una figura de color con su nombre.
##  2. Una sola imagen (`imagen`): se anima sola con respiración, un balanceo suave, parpadeo, cola que ondula (opcional) y un
##     rebote al hablar. Hace falta decir dónde están los ojos y la cola (ver tools/detectar_ojos.py).
##  3. Animaciones dibujadas (`frames`): un SpriteFrames con "reposo" y, opcional, "hablar".

signal hablar(id_personaje: String)

## Id de la ficha en data/personajes/ ("roberto", "martita", "homero").
@export var id_personaje: String = ""
@export var nombre: String = ""
## Color de la figura provisional.
@export var color: Color = Color(0.5, 0.7, 0.4)
## Tamaño del arte en el juego respecto de la imagen original (Zarita usa 0,25).
@export var escala: float = 0.25
## Cuánto dura la animación de hablar al tocarlo.
@export var segundos_hablando: float = 2.5

@export_group("Animaciones dibujadas")
## Animaciones "reposo" (en bucle) y "hablar" (se ve unos segundos al tocarlo).
@export var frames: SpriteFrames

@export_group("Una sola imagen animada por código")
## La imagen del personaje de frente (con fondo transparente y los pies en el borde de abajo).
@export var imagen: Texture2D
## Centro de cada ojo, en píxeles de la imagen (los da tools/detectar_ojos.py). Vacío = no parpadea.
@export var ojos: PackedVector2Array = PackedVector2Array()
## Medio ancho y medio alto de cada párpado, en píxeles de la imagen.
@export var ojo_tamano: Vector2 = Vector2(14.0, 9.0)
## Color del párpado cerrado. Transparente = se toma de la piel que rodea cada ojo.
@export var color_parpado: Color = Color(0.0, 0.0, 0.0, 0.0)
## Zona de la cola en la imagen, de 0 a 1: izquierda, arriba, derecha, abajo. Todo ceros = sin cola que se mueva.
@export var cola_zona: Vector4 = Vector4.ZERO
## true si la punta de la cola queda a la izquierda de su zona (y la base a la derecha).
@export var cola_punta_izquierda: bool = false
## Hacia dónde se mece la cola: (0, 1) arriba y abajo, (1, 0) de lado a lado.
@export var cola_eje: Vector2 = Vector2(0.0, 1.0)
## Cuánto se mueve la punta de la cola, como fracción de la imagen (Zarita: 0,02).
@export var cola_amplitud: float = 0.02
## Cuánto sube y baja el pecho al respirar (fracción del alto).
@export var respiracion: float = 0.018

const SHADER_COLA: Shader = preload("res://shaders/cola.gdshader")
const DURACION_PARPADEO: float = 0.13
const COLOR_LINEA_PARPADO: Color = Color(0.3, 0.17, 0.17)

@onready var _cuerpo: Polygon2D = $Cuerpo
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _zona: CollisionShape2D = $Zona
@onready var _letrero: Label = $Letrero

var _por_codigo: bool = false
var _hablando: float = 0.0
var _parpados: Node2D
var _espera_parpadeo: float = 2.0
var _parpadeando: float = 0.0
var _color_parpados: Array[Color] = []


func _ready() -> void:
	add_to_group("amigos")
	input_pickable = true
	_letrero.text = nombre
	_cuerpo.color = color
	if frames == null and imagen != null:
		frames = _frames_de_una_imagen()
		_por_codigo = true
	if frames != null:
		_usar_arte()
	set_process(_por_codigo)
	input_event.connect(_al_tocar)
	if get_parent() == get_tree().root:   # escena suelta (F6): los pies son el origen, se centra para que se vea entera
		position = get_viewport_rect().size / 2.0 + Vector2(0.0, -_zona.position.y)


## Una animación "reposo" de un solo cuadro con la imagen: el movimiento lo pone el código.
func _frames_de_una_imagen() -> SpriteFrames:
	var f := SpriteFrames.new()
	f.remove_animation(&"default")
	f.add_animation(&"reposo")
	f.add_frame(&"reposo", imagen)
	return f


## Cambia la figura de color por el arte: base en los pies, zona de toque y letrero según su altura, y una sombra suave.
func _usar_arte() -> void:
	_sprite.sprite_frames = frames
	_sprite.scale = Vector2.ONE * escala
	var textura := frames.get_frame_texture(&"reposo", 0)
	var tam := textura.get_size()
	_sprite.centered = false
	_sprite.offset = Vector2(-tam.x / 2.0, -tam.y)
	_sprite.visible = true
	for nodo in [_cuerpo, $Ojos, $Ojo2]:
		nodo.visible = false
	var alto := tam.y * escala
	_letrero.position.y = -alto - 42.0
	_zona.position.y = -alto / 2.0
	_zona.shape = _zona.shape.duplicate()   # la forma es compartida con las demás escenas heredadas: cada amigo usa la suya
	(_zona.shape as CircleShape2D).radius = maxf(52.0, alto * 0.6)
	var sombra := Sombra.new()
	sombra.ancho_base = tam.x * escala * 0.6
	sombra.profundidad_base = 22.0
	sombra.alto_objeto = alto
	add_child(sombra)
	_sprite.play(&"reposo")
	if _por_codigo:
		_preparar_cola()
		_preparar_parpados()


## La cola ondula con el mismo shader que la de Zarita.
func _preparar_cola() -> void:
	if cola_zona == Vector4.ZERO or cola_amplitud <= 0.0:
		return
	var material := ShaderMaterial.new()
	material.shader = SHADER_COLA
	material.set_shader_parameter("zona", cola_zona)
	material.set_shader_parameter("punta_a_la_izquierda", cola_punta_izquierda)
	material.set_shader_parameter("eje", cola_eje)
	material.set_shader_parameter("amplitud", cola_amplitud)
	_sprite.material = material


## Párpados cerrados: un rectángulo del color de la piel con una línea encima, dibujado sobre cada ojo unos instantes.
func _preparar_parpados() -> void:
	if ojos.is_empty():
		return
	for centro in ojos:
		_color_parpados.append(color_parpado if color_parpado.a > 0.0 else _color_de_piel(centro))
	_parpados = Node2D.new()
	_parpados.visible = false
	_parpados.draw.connect(_dibujar_parpados)
	_sprite.add_child(_parpados)
	_espera_parpadeo = randf_range(1.5, 3.5)


## Promedio del color de la piel en un anillo alrededor del ojo (sin contar lo muy oscuro ni lo transparente).
func _color_de_piel(centro: Vector2) -> Color:
	var img := imagen.get_image()
	var suma := Color(0.0, 0.0, 0.0, 0.0)
	var cuantos := 0
	var radio := ojo_tamano.length() + 5.0
	for i in 16:
		var p := centro + Vector2.from_angle(TAU * i / 16.0) * radio
		var x := clampi(int(p.x), 0, img.get_width() - 1)
		var y := clampi(int(p.y), 0, img.get_height() - 1)
		var c := img.get_pixel(x, y)
		if c.a > 0.5 and c.get_luminance() > 0.22:
			suma += c
			cuantos += 1
	if cuantos == 0:
		return Color(0.75, 0.7, 0.55)
	return Color(suma.r / cuantos, suma.g / cuantos, suma.b / cuantos, 1.0)


func _dibujar_parpados() -> void:
	for i in ojos.size():
		var centro := ojos[i] + _sprite.offset   # de píxeles de la imagen a coordenadas del sprite
		_parpados.draw_rect(Rect2(centro - ojo_tamano, ojo_tamano * 2.0), _color_parpados[i])
		_parpados.draw_line(centro + Vector2(-ojo_tamano.x, 0.0), centro + Vector2(ojo_tamano.x, 0.0), COLOR_LINEA_PARPADO, 3.0)


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# Respiración: el cuerpo se estira un poquito hacia arriba (y se ensancha un poco al revés), con los pies fijos.
	var aire := sin(t * TAU / 2.6) * respiracion
	var charla := 0.0
	if _hablando > 0.0:
		_hablando -= delta
		charla = absf(sin(t * TAU * 3.0)) * 0.07   # rebotito al ritmo de la charla
	_sprite.scale = Vector2(1.0 - (aire + charla) * 0.4, 1.0 + aire + charla) * escala
	_sprite.rotation = sin(t * TAU / 7.0) * 0.012   # se mece apenas, como quien espera tranquilo
	# Parpadeo cada 2,5-6 s (a veces doble).
	if _parpados != null:
		if _parpadeando > 0.0:
			_parpadeando -= delta
			if _parpadeando <= 0.0:
				_parpados.visible = false
		else:
			_espera_parpadeo -= delta
			if _espera_parpadeo <= 0.0:
				_parpadeando = DURACION_PARPADEO
				_parpados.visible = true
				_espera_parpadeo = 0.3 if randf() < 0.2 else randf_range(2.5, 6.0)


func _al_tocar(_viewport: Node, evento: InputEvent, _forma: int) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		_animar_hablar()
		hablar.emit(id_personaje)


## Con animación dibujada "hablar", la muestra unos segundos; con una sola imagen, rebota al ritmo de la charla.
func _animar_hablar() -> void:
	if _por_codigo:
		_hablando = segundos_hablando
		return
	if frames == null or not frames.has_animation(&"hablar"):
		return
	_sprite.play(&"hablar")
	await get_tree().create_timer(segundos_hablando).timeout
	if is_instance_valid(_sprite):
		_sprite.play(&"reposo")
