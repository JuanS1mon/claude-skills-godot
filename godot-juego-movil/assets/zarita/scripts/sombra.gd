class_name Sombra
extends Node2D
## Sombras de un objeto apoyado en el suelo. Se ponen como hijo del objeto, cuyo origen es el centro de su base.
##  - Una sombra de contacto, siempre, para que no parezca flotar.
##  - Una sombra proyectada por cada luz que llega al objeto, apuntando al lado contrario de la luz:
##    el sol y la luna que entran por las ventanas, las lámparas encendidas y la luz de la habitación.
## Son elipses suaves dibujadas en el suelo; se recalculan solo cuando cambia algo.

## Medidas del objeto, en píxeles: su huella en el suelo y su altura (da el largo de las sombras).
@export var ancho_base: float = 60.0
@export var profundidad_base: float = 24.0
@export var alto_objeto: float = 100.0
## Para objetos que se mueven solos (Zarita): recalcular en cada cuadro.
@export var cada_cuadro: bool = false
## Orden de dibujo: -4 va sobre el piso y bajo todo lo demás. En pantallas con una imagen de fondo hay que usar 0.
@export var capa_z: int = -4
## Sombra proyectada fija, para pantallas sin luces (la de inicio): dirección, largo en píxeles y opacidad.
@export var direccion_fija: Vector2 = Vector2.ZERO
@export var largo_fijo: float = 0.0
@export var alfa_fijo: float = 0.0

const COLOR: Color = Color(0.10, 0.06, 0.16)
const ALFA_CONTACTO: float = 0.4
const ALFA_SOL: float = 0.34
const ALFA_LUNA: float = 0.24
const ALFA_LAMPARA: float = 0.50
const ALFA_HABITACION: float = 0.35
## Las sombras se ven en el suelo desde arriba: se aplastan en vertical para dar sensación de perspectiva.
const APLASTAMIENTO: float = 0.65
## Capas de cada elipse, de la más grande a la más chica: [escala, multiplicador de opacidad]. Dan el borde suave.
const CAPAS: Array = [[1.0, 0.14], [0.90, 0.16], [0.80, 0.18], [0.70, 0.20], [0.58, 0.24], [0.44, 0.30], [0.30, 0.38]]
const PUNTOS_ELIPSE: int = 20
const PASO: float = 0.1

var _tiempo: float = 0.0
var _ultima_posicion: Vector2 = Vector2(INF, INF)
## Cada sombra: {"dir": Vector2, "largo": float, "alfa": float}
var _sombras: Array = []


func _ready() -> void:
	z_index = capa_z   # por defecto, sobre el piso y las alfombras y bajo los muebles y Zarita


func _process(delta: float) -> void:
	_tiempo += delta
	var se_movio := global_position != _ultima_posicion
	if cada_cuadro or se_movio or _tiempo >= PASO:
		_tiempo = 0.0
		_ultima_posicion = global_position
		_recalcular()
		queue_redraw()


func _recalcular() -> void:
	_sombras.clear()
	if direccion_fija != Vector2.ZERO:
		_agregar(direccion_fija, largo_fijo, alfa_fijo)
	var origen := global_position
	var arbol := get_tree()

	# Sol y luna: solo entran si hay alguna ventana en la casa.
	var natural: LuzNatural = CicloDia.luz_natural if CicloDia.luz_natural_activa else null
	if natural != null:
		# Con LuzNatural, la sombra solo aparece donde cae la mancha de una ventana, y siempre apunta al mismo lado
		# (el contrario al sol), sin importar en qué parte de la mancha esté el objeto.
		for es_sol in [true, false]:
			var energia: float = natural.energia_sol if es_sol else natural.energia_luna
			if energia < 0.02:
				continue
			var cobertura := 0.0
			var dir_ventana := Vector2.ZERO
			for nodo in arbol.get_nodes_in_group("ventanas"):
				var ventana := (nodo as Node).get_node_or_null("Visual") as Ventana
				if ventana != null:
					var c := ventana.cobertura_en(origen, es_sol)
					if c > cobertura:
						cobertura = c
						dir_ventana = ventana.direccion_luz()   # la sombra cae hacia donde viaja la luz de esa ventana
			if cobertura < 0.01:
				continue
			var pos_luz: Vector2 = natural.posicion_sol if es_sol else natural.posicion_luna
			var rayo := Vector2(natural.centro_x, natural.y_pared) - pos_luz   # igual para todos los objetos
			var apertura := clampf(absf(rayo.x / maxf(rayo.y, 1.0)) / 2.0, 0.0, 1.0)
			var fuerza := clampf(energia / (0.6 if es_sol else 0.3), 0.0, 1.0)
			_agregar(dir_ventana, alto_objeto * (0.25 + 0.9 * apertura), fuerza * cobertura * (ALFA_SOL if es_sol else ALFA_LUNA))
	elif arbol.get_nodes_in_group("ventanas").size() > 0:
		for fuente in CicloDia.fuentes_naturales():
			var alfa := float(fuente["intensidad"]) * (ALFA_SOL if fuente["es_sol"] else ALFA_LUNA)
			_agregar(origen - (fuente["pos"] as Vector2), alto_objeto * float(fuente["k"]), alfa)

	# Lámparas encendidas: sombras que se alejan de cada una, más largas cuanto más lejos.
	for nodo in arbol.get_nodes_in_group("lamparas"):
		var lampara := nodo as Mueble
		if lampara == null or lampara == get_parent():
			continue
		var d := origen - lampara.global_position
		var distancia := d.length()
		if distancia < 8.0 or distancia > lampara.luz_radio:
			continue
		var fuerza: float = lampara.intensidad_luz() * (1.0 - distancia / lampara.luz_radio)
		if fuerza > 0.04:
			_agregar(origen - lampara.global_position, alto_objeto * (0.25 + 0.6 * distancia / lampara.luz_radio), fuerza * ALFA_LAMPARA)

	# Luz de la habitación.
	for nodo in arbol.get_nodes_in_group("luz_habitacion"):
		var luz := nodo as LuzHabitacion
		if luz == null:
			continue
		var d2 := origen - luz.global_position
		var distancia2 := d2.length()
		if distancia2 < 20.0 or distancia2 > luz.radio:
			continue
		var fuerza2: float = luz.intensidad() * (1.0 - distancia2 / luz.radio)
		if fuerza2 > 0.04:
			_agregar(d2, alto_objeto * 0.3, fuerza2 * ALFA_HABITACION)


## `desde_la_luz` es el vector que va de la luz al objeto: la sombra cae en esa misma dirección.
func _agregar(desde_la_luz: Vector2, largo: float, alfa: float) -> void:
	if desde_la_luz.length() < 1.0 or alfa < 0.01:
		return
	_sombras.append({"dir": desde_la_luz.normalized(), "largo": largo, "alfa": alfa})


func _draw() -> void:
	# Sombra de contacto: justo bajo la base.
	_elipse(Vector2(0.0, -profundidad_base * 0.35), Vector2.RIGHT, ancho_base * 0.62, profundidad_base * 0.7, ALFA_CONTACTO, false)
	for s in _sombras:
		var dir: Vector2 = s["dir"]
		var largo: float = s["largo"]
		# Nace en la base del objeto y se alarga hacia el lado contrario a la luz.
		_elipse(dir * (largo * 0.5), dir, largo * 0.5 + profundidad_base * 0.5, ancho_base * 0.5, float(s["alfa"]), true)


func _elipse(centro: Vector2, eje: Vector2, semi_largo: float, semi_ancho: float, alfa: float, aplastar: bool) -> void:
	var perpendicular := Vector2(-eje.y, eje.x)
	for capa in CAPAS:
		var escala: float = capa[0]
		var puntos := PackedVector2Array()
		for i in PUNTOS_ELIPSE:
			var angulo := TAU * i / float(PUNTOS_ELIPSE)
			var p := centro + eje * (cos(angulo) * semi_largo * escala) + perpendicular * (sin(angulo) * semi_ancho * escala)
			if aplastar:
				p.y *= APLASTAMIENTO
			puntos.append(p)
		draw_colored_polygon(puntos, Color(COLOR.r, COLOR.g, COLOR.b, clampf(alfa * float(capa[1]), 0.0, 1.0)))
