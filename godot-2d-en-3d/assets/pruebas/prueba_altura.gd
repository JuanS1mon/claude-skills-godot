extends SceneTree
## Mide la altura máxima de los pies con distintas combinaciones de salto y dash hacia arriba.

var f := 0
var jug
var y_max := 0.0
var combo := 0
var t := 0
const COMBOS := ["salto + doble", "salto + doble + dash arriba", "dash arriba en piso + doble + dash arriba", "salto + dash arriba + doble"]

func _initialize() -> void:
	change_scene_to_file("res://escenas/mundo.tscn")

func _p(a: String) -> void: Input.action_press(a)
func _r(a: String) -> void: Input.action_release(a)

func _process(_d: float) -> bool:
	f += 1
	if f == 10:
		jug = current_scene.get_node("Jugador")
	if f < 20 or combo >= COMBOS.size():
		if combo >= COMBOS.size():
			quit()
		return false
	t += 1
	y_max = maxf(y_max, jug.global_position.y)
	if t == 1:
		jug.global_position = Vector3(-14, 0.1, 0)
		jug.velocity = Vector3.ZERO
	match combo:
		0:
			if t == 10: _p("saltar")
			if t == 30: _r("saltar")
			if t == 33: _p("saltar")
			if t == 50: _r("saltar")
		1:
			if t == 10: _p("saltar")
			if t == 30: _r("saltar")
			if t == 33: _p("saltar")
			if t == 50: _r("saltar"); _p("arriba"); _p("dash")
			if t == 52: _r("dash"); _r("arriba")
		2:
			if t == 10: _p("arriba"); _p("dash")
			if t == 12: _r("dash"); _r("arriba")
			if t == 22: _p("saltar")
			if t == 40: _r("saltar")
			if t == 42: _p("arriba"); _p("dash")
			if t == 44: _r("dash"); _r("arriba")
		3:
			if t == 10: _p("saltar")
			if t == 28: _r("saltar"); _p("arriba"); _p("dash")
			if t == 30: _r("dash"); _r("arriba")
			if t == 40: _p("saltar")
			if t == 58: _r("saltar")
	if t == 150:
		print(COMBOS[combo], ": ", snappedf(y_max, 0.01), " m")
		combo += 1
		t = 0
		y_max = 0.0
	return false
