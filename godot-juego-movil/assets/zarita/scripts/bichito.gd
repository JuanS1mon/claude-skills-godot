class_name Bichito
extends Node2D
## Un bichito de luz del minijuego (ver CazaBichitos). Vaga despacio brillando; si nadie lo atrapa antes de `segundos_visible`,
## se apaga y vuela alto. Su aspecto sale de su ficha BichitoData (color); el brillo se dibuja con círculos suaves.

signal atrapado(bichito: Bichito)
signal escapado(bichito: Bichito)

## Radio de toque: generoso para el dedo.
const RADIO: float = 52.0
const VELOCIDAD_ESCAPE: float = 240.0
## Color cuando la escena corre suelta, sin ficha.
const COLOR_POR_DEFECTO: Color = Color(1.0, 0.95, 0.5)

var ficha: BichitoData

var _vida: float = 0.0
var _fase: float = 0.0
var _velocidad: Vector2 = Vector2.ZERO
var _limites: Rect2
var _escapando: bool = false

@onready var halo: Polygon2D = $Halo
@onready var resplandor: Polygon2D = $Resplandor
@onready var nucleo: Polygon2D = $Nucleo
@onready var imagen: AnimatedSprite2D = $Imagen


## Lo coloca al azar dentro de `limites` y lo hace vagar.
func iniciar(datos: BichitoData, limites: Rect2) -> void:
	ficha = datos
	_limites = limites
	if datos.frames != null:   # si la ficha no trae animación, queda la de la escena
		imagen.sprite_frames = datos.frames
	position = Vector2(randf_range(limites.position.x, limites.end.x), randf_range(limites.position.y, limites.end.y))
	_velocidad = Vector2.from_angle(randf() * TAU) * randf_range(30.0, 70.0)
	_fase = randf() * TAU
	_actualizar_aspecto()


func _process(delta: float) -> void:
	if ficha == null:   # escena ejecutada suelta (F6): se ve y late con los valores por defecto, sin vagar
		_fase += delta * 6.0
		_actualizar_aspecto()
		return
	_vida += delta
	_fase += delta * 6.0
	if _escapando:
		position.y -= VELOCIDAD_ESCAPE * delta
		modulate.a -= delta * 1.4
		if modulate.a <= 0.0:
			escapado.emit(self)
			queue_free()
		return
	position += _velocidad * delta
	if position.x < _limites.position.x or position.x > _limites.end.x:
		_velocidad.x = -_velocidad.x
	if position.y < _limites.position.y or position.y > _limites.end.y:
		_velocidad.y = -_velocidad.y
	position = position.clamp(_limites.position, _limites.end)
	if _vida >= ficha.segundos_visible:
		_escapando = true
	_actualizar_aspecto()


## ¿El toque en `punto` (coordenadas de pantalla) lo alcanza?
func contiene(punto: Vector2) -> bool:
	return not _escapando and punto.distance_to(global_position) <= RADIO


func capturar() -> void:
	if _escapando:
		return
	atrapado.emit(self)
	queue_free()


## Aplica el color de la ficha y el pulso de brillo a los nodos de la escena.
## Con `frames` en la ficha, `Imagen` reproduce el aleteo y reemplaza al núcleo; el halo y el resplandor siguen latiendo.
func _actualizar_aspecto() -> void:
	var color := ficha.color if ficha != null else COLOR_POR_DEFECTO
	var pulso := 0.65 + 0.35 * sin(_fase)
	if imagen.sprite_frames != null:
		nucleo.visible = false   # el cuerpo es la imagen; el halo y el resplandor siguen latiendo detrás
		if not imagen.is_playing():
			imagen.play("default")
	else:
		nucleo.visible = true
	halo.color = Color(color, 0.10 * pulso)
	resplandor.color = Color(color, 0.22 * pulso)
	nucleo.color = color.lightened(0.5)
