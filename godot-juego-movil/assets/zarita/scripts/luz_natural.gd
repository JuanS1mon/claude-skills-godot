@tool
class_name LuzNatural
extends Node2D
## Sol y luna de la casa. Aquí se decide dónde están, cuánta luz dan y de qué color según la hora y el clima; cada
## ventana (ver Ventana) lee esos datos y proyecta en el suelo su mancha con la forma exacta de sus paneles. El relámpago
## es una luz propia (nodo Rayo, en luz_natural.tscn). Los muebles y Zarita tapan la luz de las manchas.
## Las sombras de luz cuestan en el celular: `activa` = false apaga las manchas y vuelve a las sombras dibujadas.
## En el editor dibuja guías (recorrido, sol, luna y rayos). Ejecutando esta escena sola (F6) se puede simular el día,
## con tres ventanas de prueba: ← y → cambian la hora, Enter pausa el tiempo, y la cámara se aleja.

@export var activa: bool = true:
	set(valor):
		activa = valor
		_aplicar_activa()

@export_group("Intensidad")
## 1 = la intensidad de las tablas de CicloDia.
@export_range(0.0, 2.0, 0.05) var fuerza_sol: float = 0.9
@export_range(0.0, 2.0, 0.05) var fuerza_luna: float = 0.6
@export_range(0.0, 2.0, 0.05) var fuerza_relampago: float = 1.0
## Tinte que se multiplica por el color del sol de cada hora (CicloDia.tabla_luz_sol). Un durazno suave combina con el piso;
## blanco deja el color puro de la tabla, que sobre un piso claro se ve amarillo chillón.
@export var tinte_sol: Color = Color(0.95, 0.88, 0.95)

@export_group("Recorrido")
## A qué altura sobre la pared está la línea por la que viajan el sol y la luna (de izquierda a derecha).
## Más alta = rayos más empinados y manchas más cortas.
@export var altura_luz: float = 800.0
## Inclinación de los rayos a la salida y a la puesta, respecto de la vertical (0 = siempre rectos).
@export_range(0.0, 80.0, 1.0) var angulo_max_grados: float = 65.0
## Centro de la casa en X: la luz está encima de él al mediodía.
@export var centro_x: float = 360.0
## Altura de la línea de la pared (unión de la pared pintada con el suelo).
@export var y_pared: float = 205.0

@export_group("Prueba")
## Hora que se muestra en las guías del editor, y con la que arranca la simulación (F6 sobre esta escena).
@export_range(0.0, 24.0, 0.1) var hora_previa: float = 9.0
## Ventanas de prueba (centro en X): en la simulación se ponen tres, de los tres diseños, y las guías salen de ahí.
@export var huecos_prueba: PackedFloat32Array = PackedFloat32Array([110.0, 360.0, 610.0])
## Ancho de cada abanico de guía en el editor.
@export var ancho_hueco_prueba: float = 110.0
## Qué tan lejos se ve al simular (menor = más lejos).
@export_range(0.1, 1.0, 0.05) var zoom_prueba: float = 0.4

const RADIO_ICONO: float = 70.0
const COLOR_LUNA: Color = Color(0.55, 0.72, 1.0)
const ESCENA_VENTANA: String = "res://scenes/ventana.tscn"   # se carga al simular, por la misma razón que Zarita
const FONDO_PRUEBA: String = "res://assets/fondos/casa_fondo.png"
const ESCENA_ZARITA: String = "res://scenes/zarita.tscn"   # se carga al simular: Zarita usa esta clase y un preload sería circular

@onready var _rayo: PointLight2D = $Rayo

## Lo que leen las ventanas para hacer su mancha en el suelo: dónde está cada luz, cuánta energía da y su color.
var posicion_sol: Vector2 = Vector2.ZERO
var energia_sol: float = 0.0
var color_sol: Color = Color.WHITE
var posicion_luna: Vector2 = Vector2.ZERO
var energia_luna: float = 0.0
var color_luna: Color = COLOR_LUNA

var _cartel: Label


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_aplicar_activa()
	if _es_prueba():
		_preparar_prueba()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	CicloDia.luz_natural_activa = false
	CicloDia.luz_natural = null
	CicloDia.set_process(true)


## true al ejecutar esta escena sola (F6), no cuando la instancia la casa.
func _es_prueba() -> bool:
	return not Engine.is_editor_hint() and get_tree().current_scene == self


func set_activa(valor: bool) -> void:
	activa = valor


## Dónde está la luz en cada momento de su recorrido (t de 0 a 1): a la izquierda al salir, arriba al mediodía
## y a la derecha al ponerse. Sus rayos caen hacia el lado contrario.
func posicion_luz(t: float) -> Vector2:
	var angulo := deg_to_rad(lerpf(-angulo_max_grados, angulo_max_grados, clampf(t, 0.0, 1.0)))
	return Vector2(centro_x + tan(angulo) * altura_luz, y_pared - altura_luz)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()   # las guías siguen a los parámetros del Inspector
		return
	if _es_prueba():
		_controlar_hora(delta)
		queue_redraw()
	if not activa:
		return
	var h := CicloDia.hora
	var clima: Clima = CicloDia.clima

	posicion_sol = posicion_luz((h - 6.0) / 13.0)
	color_sol = CicloDia.color_en(CicloDia.tabla_luz_sol) * tinte_sol
	energia_sol = CicloDia.valor_en(CicloDia.tabla_energia_sol) * clima.factor_sol() * fuerza_sol

	var hl := h if h >= 18.0 else h + 24.0
	posicion_luna = posicion_luz((hl - 18.0) / 12.0)
	energia_luna = CicloDia.valor_en(CicloDia.tabla_energia_luna) * (1.0 - 0.7 * clima.nubes) * fuerza_luna

	# Un relámpago: golpe de luz azulada desde arriba (la posición del nodo Rayo). Solo si hay alguna ventana.
	var rayo := 0.0
	if clima.relampago > 0.01 and get_tree().get_nodes_in_group("ventanas").size() > 0:
		rayo = clima.relampago * 2.4 * fuerza_relampago
	_rayo.energy = rayo
	_rayo.visible = rayo > 0.01   # una luz con sombras que no se ve no cuesta nada


func _aplicar_activa() -> void:
	if Engine.is_editor_hint() or not is_node_ready():
		return
	CicloDia.luz_natural_activa = activa
	CicloDia.luz_natural = self if activa else null
	_rayo.visible = activa and _rayo.energy > 0.01
	_rayo.shadow_enabled = activa
	if not activa:
		energia_sol = 0.0
		energia_luna = 0.0


## Simulación (F6 sobre esta escena): fondo, Zarita para ver su sombra, cámara alejada y un cartel con la hora.
func _preparar_prueba() -> void:
	CicloDia.hora = hora_previa
	if ResourceLoader.exists(FONDO_PRUEBA):
		var fondo := TextureRect.new()
		fondo.texture = load(FONDO_PRUEBA) as Texture2D
		fondo.size = Vector2(720.0, 1280.0)
		fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fondo.z_index = -10
		add_child(fondo)
	# Una ventana de cada diseño en la pared, para ver las tres manchas.
	for i in huecos_prueba.size():
		var ventana := (load(ESCENA_VENTANA) as PackedScene).instantiate() as Node2D
		ventana.position = Vector2(huecos_prueba[i], Mueble.Y_PARED)
		(ventana.get_node("Visual") as Ventana).variante = i % 3
		add_child(ventana)
	var zarita := (load(ESCENA_ZARITA) as PackedScene).instantiate() as Node2D
	zarita.position = Vector2(360.0, 640.0)
	add_child(zarita)
	var camara := Camera2D.new()
	camara.position = Vector2(centro_x, 420.0)
	camara.zoom = Vector2(zoom_prueba, zoom_prueba)
	add_child(camara)
	var capa := CanvasLayer.new()
	_cartel = Label.new()
	_cartel.position = Vector2(12.0, 8.0)
	_cartel.add_theme_font_size_override("font_size", 22)
	capa.add_child(_cartel)
	add_child(capa)


## ← y → cambian la hora; Enter pausa o reanuda el tiempo.
func _controlar_hora(delta: float) -> void:
	var sentido := Input.get_axis("ui_left", "ui_right")
	if sentido != 0.0:
		CicloDia.hora = fposmod(CicloDia.hora + sentido * 3.0 * delta, 24.0)
	if Input.is_action_just_pressed("ui_accept"):
		CicloDia.set_process(not CicloDia.is_processing())
	if _cartel != null:
		_cartel.text = "Hora %02d:%02d %s   ← → cambian la hora · Enter pausa" % [
			int(CicloDia.hora), int(fmod(CicloDia.hora, 1.0) * 60.0),
			"(pausada)" if not CicloDia.is_processing() else ""]


## Guías: línea de la pared, ventanas de prueba, recorrido, sol, luna y los rayos que pasan por las ventanas.
func _draw() -> void:
	if not Engine.is_editor_hint() and not _es_prueba():
		return
	var h := hora_previa if Engine.is_editor_hint() else CicloDia.hora
	draw_line(Vector2(-1500.0, y_pared), Vector2(2200.0, y_pared), Color(1.0, 1.0, 1.0, 0.5), 2.0)
	for gx in huecos_prueba:
		draw_rect(Rect2(gx - ancho_hueco_prueba / 2.0, y_pared - 6.0, ancho_hueco_prueba, 14.0), Color(0.3, 1.0, 0.4, 0.8), false, 3.0)
	var camino := PackedVector2Array()
	for i in 25:
		camino.append(posicion_luz(i / 24.0))
	draw_polyline(camino, Color(1.0, 0.9, 0.4, 0.35), 3.0)
	# Sol: de 6 a 19 h. Luna: de 18 a 6 h. Fuera de su horario se ven atenuados.
	var ts := (h - 6.0) / 13.0
	var hl := h if h >= 18.0 else h + 24.0
	var tl := (hl - 18.0) / 12.0
	var sol_arriba := ts > 0.0 and ts < 1.0
	var luna_arriba := tl > 0.0 and tl < 1.0
	var pos_sol := posicion_luz(ts)
	var pos_luna := posicion_luz(tl)
	_dibujar_sol(pos_sol, 1.0 if sol_arriba else 0.25)
	_dibujar_luna(pos_luna, 1.0 if luna_arriba else 0.25)
	if sol_arriba:
		_dibujar_rayos(pos_sol, Color(1.0, 0.85, 0.70, 0.55))
	if luna_arriba:
		_dibujar_rayos(pos_luna, Color(0.6, 0.75, 1.0, 0.55))


## Los rayos de la guía son un abanico suave por cada ventana de prueba: intenso en la pared y desvaneciéndose al alejarse,
## con un par de capas más anchas y tenues para difuminar los bordes.
func _dibujar_rayos(origen: Vector2, color: Color) -> void:
	for gx in huecos_prueba:
		for capa in [[0.0, 0.30], [0.12, 0.16], [0.30, 0.08]]:
			var extra: float = float(capa[0]) * ancho_hueco_prueba
			var izq := Vector2(gx - ancho_hueco_prueba / 2.0 - extra, y_pared)
			var der := Vector2(gx + ancho_hueco_prueba / 2.0 + extra, y_pared)
			var lejos_izq := izq + (izq - origen).normalized() * 1400.0
			var lejos_der := der + (der - origen).normalized() * 1400.0
			var cerca := Color(color.r, color.g, color.b, float(capa[1]))
			var fin := Color(color.r, color.g, color.b, 0.0)
			draw_polygon(PackedVector2Array([izq, der, lejos_der, lejos_izq]), PackedColorArray([cerca, cerca, fin, fin]))


func _dibujar_sol(pos: Vector2, alfa: float) -> void:
	var color := Color(1.0, 0.85, 0.2, alfa)
	draw_circle(pos, RADIO_ICONO, color)
	for i in 8:
		var d := Vector2.from_angle(TAU * i / 8.0)
		draw_line(pos + d * RADIO_ICONO * 1.3, pos + d * RADIO_ICONO * 1.8, color, 8.0)


func _dibujar_luna(pos: Vector2, alfa: float) -> void:
	draw_circle(pos, RADIO_ICONO, Color(0.80, 0.88, 1.0, alfa))
	for crater in [Vector2(-22.0, -14.0), Vector2(18.0, 8.0), Vector2(-6.0, 26.0)]:
		draw_circle(pos + crater, 11.0, Color(0.55, 0.65, 0.85, alfa))


## Oclusor con la huella de un objeto (origen = centro de su base): tapa la luz natural y deja su sombra detrás.
## Solo afecta a las luces con sombras, o sea al sol, la luna y el relámpago de esta clase.
static func crear_oclusor(ancho: float, profundidad: float) -> LightOccluder2D:
	var forma := OccluderPolygon2D.new()
	forma.polygon = PackedVector2Array([
		Vector2(-ancho / 2.0, -profundidad), Vector2(ancho / 2.0, -profundidad),
		Vector2(ancho / 2.0, 0.0), Vector2(-ancho / 2.0, 0.0),
	])
	var oclusor := LightOccluder2D.new()
	oclusor.occluder = forma
	return oclusor
