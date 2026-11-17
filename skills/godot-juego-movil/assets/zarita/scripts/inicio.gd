extends CanvasLayer
## Pantalla de inicio: título, Zarita, botón Jugar y un fundido al entrar a la casa.
## Va en un CanvasLayer para que el tinte del día y la noche (CicloDia) no la oscurezca.

const ESCENA_CASA: String = "res://scenes/casa.tscn"

## Ilustración de fondo y logo del título. Si faltan, se ven un color liso y el título en texto.
@export var fondo: Texture2D
@export var titulo: Texture2D

@onready var _fondo: TextureRect = $Fondo
@onready var _titulo_imagen: TextureRect = $Titulo
@onready var _titulo_texto: Label = get_node_or_null("TituloTexto")   # opcional: solo si no hay logo
@onready var _boton: Button = $BotonJugar
@onready var _fundido: ColorRect = $Fundido
@onready var _zarita: AnimatedSprite2D = $AnclaZarita/Zarita


func _ready() -> void:
	# La imagen puede venir del export o estar puesta directamente en el nodo; sin imagen se ve el color liso / el texto.
	if fondo != null:
		_fondo.texture = fondo
	_fondo.visible = _fondo.texture != null
	if titulo != null:
		_titulo_imagen.texture = titulo
	_titulo_imagen.visible = _titulo_imagen.texture != null
	if _titulo_texto != null:
		_titulo_texto.visible = _titulo_imagen.texture == null
	_boton.pressed.connect(_jugar)
	_zarita.play(&"default")   # alterna sus dos cuadros en reposo; no se mueve de sitio
	# Vida: la cola se mueve suavemente y de vez en cuando parpadea (de frente, como en la animación "abajo").
	var material := ColaZarita.crear_material()
	_zarita.material = material
	ColaZarita.configurar(material, &"caminar_abajo")
	var parpadeo := ParpadeoZarita.new()
	parpadeo.objetivo = _zarita
	parpadeo.animacion_fija = &"caminar_abajo"
	parpadeo.cuadros = [1, 3]   # sus dos cuadros en reposo son el 2.º y el 4.º del paseo
	_zarita.add_child(parpadeo)
	# Entra desde negro (en el editor el fundido es transparente para poder ver la escena).
	_fundido.color.a = 1.0
	create_tween().tween_property(_fundido, "color:a", 0.0, 0.6)
	_animar_boton()


## El botón "respira" suavemente para invitar a tocarlo.
func _animar_boton() -> void:
	await get_tree().process_frame   # espera a que el botón tenga su tamaño definitivo
	_boton.pivot_offset = _boton.size / 2.0
	var respiracion := create_tween().set_loops()
	respiracion.tween_property(_boton, "scale", Vector2(1.05, 1.05), 0.9).set_trans(Tween.TRANS_SINE)
	respiracion.tween_property(_boton, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)


func _jugar() -> void:
	_boton.disabled = true
	var salida := create_tween()
	salida.tween_property(_fundido, "color:a", 1.0, 0.4)
	await salida.finished
	get_tree().change_scene_to_file(ESCENA_CASA)
