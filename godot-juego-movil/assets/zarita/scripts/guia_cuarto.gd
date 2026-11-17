@tool
extends Node2D
## Guía de los límites de la habitación en esquina isométrica. En el editor dibuja encima del suelo la línea donde las paredes
## tocan el piso (celeste) y la zona que bloquea a Zarita (rojo); mueve `esquina` y `pendiente` en el Inspector hasta que
## calcen con el dibujo. Al jugar fija esos valores en GeometriaCuarto (los usan Zarita, los muebles y las ventanas).

const Cuarto = preload("res://scripts/geometria_cuarto.gd")

## Dónde las dos paredes tocan el piso: el vértice de la "V" invertida.
@export var esquina: Vector2 = Vector2(360.0, 375.0):
	set(valor):
		esquina = valor
		_aplicar()
## Cuánto baja el borde del piso por cada píxel hacia un costado (2:1 = 0,5).
@export_range(0.2, 1.0, 0.005) var pendiente: float = 0.54:
	set(valor):
		pendiente = valor
		_aplicar()
## Cuánto se corre hacia arriba la colisión de Zarita: su caja tiene alto sobre los pies y así los pies rozan la pared.
@export_range(0.0, 60.0, 1.0) var subida_pies: float = 24.0:
	set(valor):
		subida_pies = valor
		queue_redraw()
## Cuánto avanza una casilla de la grilla del piso en horizontal (el rombo entero mide el doble de ancho).
@export_range(16.0, 120.0, 1.0) var lado_celda: float = 36.0:
	set(valor):
		lado_celda = valor
		_aplicar()
## Dibujar la guía también al jugar (para ajustar a ojo con la casa en marcha).
@export var ver_en_juego: bool = false


func _ready() -> void:
	z_index = 100
	if not Engine.is_editor_hint():
		_grilla = Node2D.new()
		_grilla.z_index = -108   # relativo a la guía (100): queda en -8, sobre el piso (-10) y bajo las alfombras (-5) y los muebles
		_grilla.visible = false
		_grilla.draw.connect(_dibujar_grilla)
		add_child(_grilla)
	_aplicar()


func _aplicar() -> void:
	Cuarto.esquina = esquina
	Cuarto.pendiente = pendiente
	Cuarto.lado = lado_celda
	queue_redraw()


## La grilla del piso se ve mientras se decora (la casa la enciende).
var grilla_visible: bool = false:
	set(valor):
		grilla_visible = valor
		if _grilla != null:
			_grilla.visible = valor
			_grilla.queue_redraw()
## Nodo aparte, justo sobre el piso y bajo los muebles (esta guía se dibuja por encima de todo).
var _grilla: Node2D


func _dibujar_grilla() -> void:
	var color := Color(1.0, 1.0, 1.0, 0.4)
	var n := 40
	for u in range(-n, n):
		for v in range(-n, n):
			var a := Cuarto.punto_grilla(u, v)
			for b in [Cuarto.punto_grilla(u + 1, v), Cuarto.punto_grilla(u, v + 1)]:
				if _en_piso(a) and _en_piso(b):
					_grilla.draw_line(a, b, color, 2.0)


func _en_piso(p: Vector2) -> bool:
	return p.x >= Cuarto.X_MIN - 1.0 and p.x <= Cuarto.X_MAX + 1.0 and p.y <= Cuarto.Y_MAX and Cuarto.es_piso(p)


func _draw() -> void:
	if not Engine.is_editor_hint() and not ver_en_juego:
		return
	var puntas := PackedVector2Array([Vector2(0.0, Cuarto.y_borde(0.0)), esquina, Vector2(Cuarto.ANCHO, Cuarto.y_borde(Cuarto.ANCHO))])
	draw_polyline(puntas, Color(0.2, 0.9, 1.0, 0.95), 3.0)
	draw_circle(esquina, 7.0, Color(0.2, 0.9, 1.0, 0.95))
	var pared := Cuarto.poligono_paredes(subida_pies)
	var zona := PackedVector2Array([pared[2], pared[3], pared[4]])
	draw_polyline(zona, Color(1.0, 0.25, 0.25, 0.9), 2.0)
	draw_line(Vector2(Cuarto.X_MIN, 0.0), Vector2(Cuarto.X_MIN, Cuarto.Y_MAX), Color(1.0, 0.85, 0.2, 0.6), 1.0)
	draw_line(Vector2(Cuarto.X_MAX, 0.0), Vector2(Cuarto.X_MAX, Cuarto.Y_MAX), Color(1.0, 0.85, 0.2, 0.6), 1.0)
	draw_line(Vector2(0.0, Cuarto.Y_MAX), Vector2(Cuarto.ANCHO, Cuarto.Y_MAX), Color(1.0, 0.85, 0.2, 0.6), 1.0)
