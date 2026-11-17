class_name VistaExterior
extends Control
## El mundo de afuera visto desde el mapa de la casa: el cielo con su hora (capas, sol y luna), nubes, y el clima de
## CicloDia (lluvia, nieve, hojas, viento y relámpagos), igual que se ve por las ventanas de las habitaciones.
## Con `solo_clima` solo dibuja lo que cae del cielo y el destello: se pone en una segunda copia delante del decorado
## para que la lluvia pase por delante del árbol. Ocupa toda la pantalla; no recibe toques.

const CARPETA_CIELOS: String = "res://assets/cielos/"
## Capas del cielo de abajo arriba (la noche va dos veces para cerrar el ciclo). Ver CicloDia.tabla_capas.
const CAPAS: Array[String] = ["noche", "amanecer", "dia", "atardecer", "noche"]
const COLORES_RESERVA: Dictionary = {
	"noche": [Color(0.03, 0.05, 0.16), Color(0.10, 0.12, 0.30)],
	"amanecer": [Color(0.45, 0.55, 0.85), Color(1.00, 0.72, 0.50)],
	"dia": [Color(0.40, 0.68, 0.95), Color(0.75, 0.88, 1.00)],
	"atardecer": [Color(0.50, 0.35, 0.60), Color(1.00, 0.62, 0.35)],
}
const TAMANO_ASTRO: float = 96.0
## Cuánto del alto de la pantalla ocupa el cielo despejado donde se mueven los astros y las nubes.
const FRACCION_CIELO: float = 0.55

## true = solo partículas y destello (la copia que va delante del decorado).
@export var solo_clima: bool = false

var _capas: Array[TextureRect] = []
var _sol: Sprite2D
var _luna: Sprite2D
var _nubes: Array[Sprite2D] = []
var _nubes_velocidad: Array[float] = []
var _manto: ColorRect
var _destello: ColorRect
var _lluvia: CPUParticles2D
var _nieve: CPUParticles2D
var _hojas: CPUParticles2D
var _viento: CPUParticles2D
var _ancho: float
var _alto: float


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Engine.is_editor_hint():
		return
	var pantalla := get_viewport_rect().size
	_ancho = pantalla.x
	_alto = pantalla.y
	if not solo_clima:
		_crear_cielo()
		_crear_nubes()
	_crear_emisores()
	_destello = ColorRect.new()
	_destello.set_anchors_preset(Control.PRESET_FULL_RECT)
	_destello.color = Color(1.0, 1.0, 1.0, 0.0)
	_destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_destello)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var clima: Clima = CicloDia.clima
	if not solo_clima:
		_actualizar_cielo(clima)
		_actualizar_nubes(clima, delta)
	_actualizar_emisor(_lluvia, clima.lluvia, Vector2(0.18 + 0.5 * clima.viento, 1.0))
	_actualizar_emisor(_nieve, clima.nieve, Vector2(0.10 + 0.6 * clima.viento, 1.0))
	_actualizar_emisor(_hojas, clima.hojas, Vector2(0.35 + 0.8 * clima.viento, 1.0))
	_actualizar_emisor(_viento, clima.viento, Vector2(1.0, 0.03))
	_destello.color.a = clima.relampago * (0.35 if solo_clima else 0.6)


func _crear_cielo() -> void:
	for nombre in CAPAS:
		var capa := TextureRect.new()
		capa.texture = _textura_cielo(nombre)
		capa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		capa.stretch_mode = TextureRect.STRETCH_SCALE
		capa.set_anchors_preset(Control.PRESET_FULL_RECT)
		capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(capa)
		_capas.append(capa)
	_sol = _crear_astro("sol")
	_luna = _crear_astro("luna")
	_manto = ColorRect.new()
	_manto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_manto.color = Color(0.5, 0.52, 0.58, 0.0)
	_manto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_manto)


func _actualizar_cielo(clima: Clima) -> void:
	var tinte := clima.tinte_cielo()
	for i in _capas.size():
		_capas[i].modulate = Color(tinte.r, tinte.g, tinte.b, CicloDia.alfa_capa(i))
	var tono := lerpf(0.80, 0.38, clima.lluvia)
	_manto.color = Color(tono, tono, tono * 1.06, clampf(clima.nubes * 0.6, 0.0, 0.6))
	var h := CicloDia.hora
	var ts := (h - 6.0) / 13.0
	_poner_astro(_sol, ts, 1.0 - 1.1 * clima.nubes, 1.0 + 0.35 * clima.calor)
	var hl := h if h >= 18.0 else h + 24.0
	_poner_astro(_luna, (hl - 18.0) / 12.0, 1.0 - clima.nubes, 1.0)


## El sol o la luna cruzan el cielo en arco de izquierda a derecha; t va de 0 a 1 y fuera de ese rango no se ven.
func _poner_astro(astro: Sprite2D, t: float, opacidad: float, aumento: float) -> void:
	if astro == null:
		return
	astro.visible = t > 0.0 and t < 1.0
	if not astro.visible:
		return
	var cielo := _alto * FRACCION_CIELO
	astro.position = Vector2(lerpf(_ancho * 0.10, _ancho * 0.90, t), cielo * 0.55 - cielo * 0.45 * sin(PI * t))
	astro.modulate.a = clampf(opacidad, 0.0, 1.0)
	astro.scale = Vector2.ONE * (TAMANO_ASTRO / astro.texture.get_width()) * aumento


func _crear_astro(nombre: String) -> Sprite2D:
	var ruta := CARPETA_CIELOS + nombre + ".png"
	if not ResourceLoader.exists(ruta):
		return null
	var astro := Sprite2D.new()
	astro.texture = load(ruta) as Texture2D
	add_child(astro)
	return astro


## Nubes grises que cruzan el cielo despacio cuando está cubierto.
func _crear_nubes() -> void:
	var cielo := _alto * FRACCION_CIELO
	# [altura como fracción del cielo, posición horizontal inicial como fracción, escala, velocidad en px/s]
	var datos: Array = [
		[0.06, 0.10, 2.8, 5.0], [0.22, 0.65, 3.0, 6.0], [0.40, 0.30, 2.8, 4.0], [0.58, 0.90, 3.0, 5.0],
		[0.14, 0.45, 1.8, 11.0], [0.32, 0.85, 1.6, 14.0], [0.48, 0.05, 1.9, 9.0], [0.68, 0.55, 1.7, 12.0],
	]
	for i in datos.size():
		var d: Array = datos[i]
		var nube := Sprite2D.new()
		nube.texture = _textura_nube(104, 44, 11 + i * 7)
		nube.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		nube.scale = Vector2(float(d[2]), float(d[2]))
		nube.position = Vector2(_ancho * float(d[1]), cielo * float(d[0]))
		nube.modulate.a = 0.0
		add_child(nube)
		_nubes.append(nube)
		_nubes_velocidad.append(float(d[3]))


func _actualizar_nubes(clima: Clima, delta: float) -> void:
	var tono := lerpf(0.80, 0.38, clima.lluvia)
	for i in _nubes.size():
		var nube := _nubes[i]
		nube.modulate = Color(tono, tono, tono * 1.05, clampf(clima.nubes * 1.3, 0.0, 1.0))
		nube.position.x += _nubes_velocidad[i] * (1.0 + 4.0 * clima.viento) * delta
		var mitad := nube.texture.get_width() * nube.scale.x / 2.0
		if nube.position.x - mitad > _ancho:
			nube.position.x = -mitad


## Una nube de píxeles: varios círculos juntos con la base plana, clara arriba y más oscura abajo.
func _textura_nube(ancho: int, alto: int, semilla: int) -> Texture2D:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var circulos: Array = []
	for i in 7:
		circulos.append([azar.randf_range(0.2, 0.8) * ancho, azar.randf_range(0.42, 0.68) * alto, azar.randf_range(0.2, 0.34) * alto * 1.5])
	var imagen := Image.create_empty(ancho, alto, false, Image.FORMAT_RGBA8)
	for y in alto:
		if float(y) > alto * 0.86:
			continue   # base plana
		for x in ancho:
			for c in circulos:
				var dx: float = x - float(c[0])
				var dy: float = y - float(c[1])
				if dx * dx + dy * dy <= float(c[2]) * float(c[2]):
					var g := lerpf(1.0, 0.70, float(y) / float(alto))
					imagen.set_pixel(x, y, Color(g, g, g * 1.03, 1.0))
					break
	return ImageTexture.create_from_image(imagen)


## Lluvia, nieve, hojas y viento: partículas que caen por toda la pantalla.
func _crear_emisores() -> void:
	_lluvia = _crear_emisor(_textura_rect(3, 16, Color(0.75, 0.86, 1.0, 0.85)), 160, 1.1, Vector2(_ancho / 2.0, -20.0), Vector2(_ancho / 2.0 + 60.0, 3.0), 900.0, 1100.0, 3.0)
	_nieve = _crear_emisor(_textura_rect(6, 6, Color(1.0, 1.0, 1.0, 0.95)), 110, 9.0, Vector2(_ancho / 2.0, -10.0), Vector2(_ancho / 2.0 + 40.0, 3.0), 35.0, 70.0, 30.0)
	_nieve.scale_amount_min = 0.6
	_nieve.scale_amount_max = 1.5
	_hojas = _crear_emisor(_textura_rect(12, 8, Color(1.0, 1.0, 1.0, 1.0)), 30, 9.0, Vector2(_ancho / 2.0, -10.0), Vector2(_ancho / 2.0 + 40.0, 3.0), 40.0, 80.0, 25.0)
	_hojas.angular_velocity_min = -150.0
	_hojas.angular_velocity_max = 150.0
	var rampa := Gradient.new()
	rampa.set_color(0, Color(0.93, 0.55, 0.20))
	rampa.set_color(1, Color(0.72, 0.30, 0.15))
	rampa.add_point(0.5, Color(0.95, 0.78, 0.25))
	_hojas.color_initial_ramp = rampa
	_viento = _crear_emisor(_textura_rect(30, 2, Color(1.0, 1.0, 1.0, 0.55)), 36, 1.2, Vector2(-30.0, _alto * 0.35), Vector2(6.0, _alto * 0.35), 600.0, 900.0, 4.0)


func _crear_emisor(textura: Texture2D, cantidad: int, vida: float, pos: Vector2, extension: Vector2, v_min: float, v_max: float, dispersion: float) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.texture = textura
	e.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	e.amount = cantidad
	e.lifetime = vida
	e.preprocess = vida   # ya viene "lleno" al empezar, sin esperar a que caiga la primera tanda
	e.local_coords = true
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.emission_rect_extents = extension
	e.position = pos
	e.direction = Vector2(0.0, 1.0)
	e.spread = dispersion
	e.gravity = Vector2.ZERO
	e.initial_velocity_min = v_min
	e.initial_velocity_max = v_max
	e.emitting = false
	add_child(e)
	return e


func _textura_rect(ancho: int, alto: int, color: Color) -> Texture2D:
	var imagen := Image.create_empty(ancho, alto, false, Image.FORMAT_RGBA8)
	imagen.fill(color)
	return ImageTexture.create_from_image(imagen)


## Enciende o apaga un emisor según cuánto vale su clima, con aparición suave, y lo inclina con el viento.
func _actualizar_emisor(emisor: CPUParticles2D, valor: float, direccion: Vector2) -> void:
	emisor.emitting = valor > 0.03
	emisor.modulate.a = clampf(valor, 0.0, 1.0)
	emisor.direction = direccion


## Usa la imagen del cielo si existe; si no, un degradado provisional.
func _textura_cielo(nombre: String) -> Texture2D:
	var ruta := CARPETA_CIELOS + "cielo_" + nombre + ".png"
	if ResourceLoader.exists(ruta):
		return load(ruta) as Texture2D
	var colores: Array = COLORES_RESERVA[nombre]
	var degradado := Gradient.new()
	degradado.set_color(0, colores[0])
	degradado.set_color(1, colores[1])
	var t := GradientTexture2D.new()
	t.gradient = degradado
	t.width = 8
	t.height = 64
	t.fill_from = Vector2(0.0, 0.0)
	t.fill_to = Vector2(0.0, 1.0)
	return t
