class_name ParpadeoZarita
extends AnimatedSprite2D
## Párpados cerrados de Zarita: una capa transparente que se pone sobre sus ojos unos instantes cada pocas segundos.
## Va como hijo del AnimatedSprite2D de Zarita, y copia su animación y su cuadro para que coincida con el cuerpo.
## De espaldas no se ve (no hay ojos).

const RUTA: String = "res://assets/zarita/caminata/%s/parpadeo/zarita_%s_parpadeo_%d.png"
const DIRECCIONES: Dictionary = {
	&"caminar_abajo": "abajo",
	&"caminar_derecha": "derecha",
	&"caminar_izquierda": "izquierda",
}
## Cuánto dura cada parpadeo, en segundos.
const DURACION: float = 0.13

## El sprite de Zarita al que acompaña.
var objetivo: AnimatedSprite2D
## Para pantallas donde el sprite usa otra animación (la de inicio): nombre de la animación que representa.
var animacion_fija: StringName = &""
## Si el sprite no tiene los 4 cuadros del paseo: a qué cuadro del paseo corresponde cada uno de los suyos.
var cuadros: Array[int] = []

var _restante: float = 0.0
var _espera: float = 2.0


func _ready() -> void:
	visible = false
	_espera = randf_range(1.5, 3.5)
	var cuadros_parpadeo := SpriteFrames.new()
	cuadros_parpadeo.remove_animation(&"default")
	for animacion in DIRECCIONES:
		var carpeta: String = DIRECCIONES[animacion]
		cuadros_parpadeo.add_animation(animacion)
		cuadros_parpadeo.set_animation_loop(animacion, false)
		for i in range(1, 5):
			cuadros_parpadeo.add_frame(animacion, load(RUTA % [carpeta, carpeta, i]) as Texture2D)
	sprite_frames = cuadros_parpadeo


func _process(delta: float) -> void:
	if _restante > 0.0:
		_restante -= delta
		if _restante <= 0.0:
			visible = false
	else:
		_espera -= delta
		if _espera <= 0.0:
			_restante = DURACION
			# A veces parpadea dos veces seguidas.
			_espera = 0.3 if randf() < 0.2 else randf_range(2.5, 6.0)
	if _restante > 0.0 and objetivo != null:
		var animacion_actual: StringName = animacion_fija if animacion_fija != &"" else objetivo.animation
		if DIRECCIONES.has(animacion_actual):
			animation = animacion_actual
			frame = cuadros[objetivo.frame] if not cuadros.is_empty() else objetivo.frame
			visible = true
		else:
			visible = false
