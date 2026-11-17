class_name Zarita
extends CharacterBody2D
## Zarita la zarigüeya: se mueve en 8 direcciones (vista cenital) y camina con animación.

@export var velocidad: float = 300.0
## Cuántos píxeles sube el cuerpo en los cuadros en reposo, para disimular el paso repetido.
@export var rebote: float = 3.0

@onready var _sprite: AnimatedSprite2D = $Sprite

## Índice del cuadro en reposo dentro de cada animación (el segundo).
const CUADRO_REPOSO: int = 1

var _y_base: float
## Verdadero mientras hace una animación que no se interrumpe (tomar mate): no se mueve ni rebota.
var _ocupada: bool = false
var _material_cola: ShaderMaterial
## Joystick virtual de la pantalla (grupo "joystick"); null si la escena no tiene uno (p. ej. al probar zarita.tscn sola).
var _joystick: Control


func _ready() -> void:
	_y_base = _sprite.position.y
	_sprite.frame_changed.connect(_al_cambiar_cuadro)
	# Sombra de contacto y sombras proyectadas por las luces; se actualiza en cada cuadro porque ella se mueve.
	var sombra := Sombra.new()
	sombra.ancho_base = 56.0
	sombra.profundidad_base = 22.0
	sombra.alto_objeto = 110.0
	sombra.cada_cuadro = true
	add_child(sombra)
	add_child(LuzNatural.crear_oclusor(36.0, 14.0))   # su sombra real contra el sol y la luna
	add_child(RopaZarita.new())   # la prenda que lleva puesta (ver Ropero)
	# Vida: la cola se mueve suavemente y de vez en cuando parpadea.
	_material_cola = ColaZarita.crear_material()
	_sprite.material = _material_cola
	ColaZarita.configurar(_material_cola, _sprite.animation)
	var parpadeo := ParpadeoZarita.new()
	parpadeo.objetivo = _sprite
	_sprite.add_child(parpadeo)


## Prueba: Enter o Espacio (ui_accept) hacen que tome mate. Más adelante se llamará desde un botón.
func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_accept"):
		tomar_mate()


## Reproduce la animación "tomar_mate" una vez, quieta, y vuelve al reposo de frente.
func tomar_mate() -> void:
	if _ocupada or not Mate.beber():   # sin yerba o sin agua caliente no hay mateada (ver Mate)
		return
	_ocupada = true
	velocity = Vector2.ZERO
	_sprite.position.y = _y_base
	ColaZarita.configurar(_material_cola, &"tomar_mate")
	_sprite.play(&"tomar_mate")
	await _sprite.animation_finished
	_ocupada = false
	_sprite.play(&"caminar_abajo")
	_sprite.pause()
	_sprite.frame = CUADRO_REPOSO


func _physics_process(_delta: float) -> void:
	if _ocupada:
		return
	var direccion := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direccion == Vector2.ZERO:
		if _joystick == null:
			_joystick = get_tree().get_first_node_in_group("joystick") as Control
		if _joystick != null:
			direccion = _joystick.get("direccion")   # el teclado manda; si no hay, el joystick táctil
	velocity = direccion * velocidad * Mate.factor_velocidad()   # con poca energía camina más despacio
	move_and_slide()
	_animar(direccion)


func _animar(direccion: Vector2) -> void:
	if direccion == Vector2.ZERO:
		_sprite.pause()
		_sprite.frame = CUADRO_REPOSO
		_sprite.position.y = _y_base
		return
	if absf(direccion.x) > absf(direccion.y):
		_sprite.play(&"caminar_derecha" if direccion.x > 0 else &"caminar_izquierda")
	else:
		_sprite.play(&"caminar_abajo" if direccion.y > 0 else &"caminar_arriba")
	ColaZarita.configurar(_material_cola, _sprite.animation)   # la cola está en otro sitio según hacia dónde mira


## Los cuadros en reposo (1 y 3) suben un poco; los de paso (0 y 2) se quedan en su sitio.
func _al_cambiar_cuadro() -> void:
	if _ocupada:
		return
	var en_reposo := _sprite.frame % 2 == 1
	_sprite.position.y = _y_base - (rebote if en_reposo else 0.0)
