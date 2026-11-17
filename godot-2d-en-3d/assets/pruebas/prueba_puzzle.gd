extends SceneTree
## Puzzle: con 1 caja no se debe llegar a la cornisa (arriba a 7 m); con 2 apiladas sí.
## Usa la mejor combinación medida: dash arriba desde el piso + doble salto + dash arriba.

const OUT := "C:/Users/PCJuan/AppData/Local/Temp/claude/eca94567a6215624/ad0deaed-32b2-4fa7-8fd0-d7674e2e28b8/scratchpad/"
var f := 0
var jug
var c4
var c5
var t := 0
var fase := 0
var y_max := 0.0
var llego := false

func _initialize() -> void:
	change_scene_to_file("res://escenas/mundo.tscn")

func _p(a: String) -> void: Input.action_press(a)
func _r(a: String) -> void: Input.action_release(a)

func _process(_d: float) -> bool:
	f += 1
	if f == 10:
		jug = current_scene.get_node("Jugador")
		c4 = current_scene.get_node("PuzzleCajas/Caja4")
		c5 = current_scene.get_node("PuzzleCajas/Caja5")
		# Torre debajo del borde izquierdo de la cornisa (17.5): cajas en x = 17.
		c4.global_position = Vector3(16.3, 0.45, 0)
		current_scene.get_node("PuzzleCajas/Caja6").global_position = Vector3(25, 0.45, 0)
		c5.global_position = Vector3(10, 0.45, 0)
	if f < 30:
		return false
	t += 1
	if fase < 2:
		y_max = maxf(y_max, jug.global_position.y)
		if jug.is_on_floor() and jug.global_position.y > 6.7 and not llego:
			llego = true
			root.get_texture().get_image().save_png(OUT + "p_llego.png")
	if t == 1:
		jug.global_position = Vector3(16.2, 1.0 + 0.92 * fase, 0)  # parado sobre la torre
		print("fase ", fase, " cajas en ", c4.global_position.y, " / ", c5.global_position.y)
		jug.velocity = Vector3.ZERO
	# combo desde arriba de la torre, empujando hacia la cornisa (derecha)
	if t == 20: _p("arriba"); _p("dash")
	if t == 22: _r("dash"); _r("arriba")
	if t == 34: _p("saltar")
	if t == 48 and jug.global_position.y > 7.1: _p("mover_der")
	if t == 52: _r("saltar")
	if t == 54: _p("arriba"); _p("mover_der"); _p("dash")
	if t == 56: _r("dash"); _r("arriba"); _p("mover_der")
	if t == 130:
		_r("mover_der")
		print("[", fase + 1, " caja(s)] altura max ", snappedf(y_max, 0.01), "  llegó a la cornisa: ", llego)
		llego = false
		root.get_texture().get_image().save_png(OUT + "p%d.png" % (fase + 1))
		fase += 1
		t = 0
		y_max = 0.0
		if fase == 1:
			c5.global_position = Vector3(16.3, 1.37, 0)  # segunda caja arriba
			c5.linear_velocity = Vector3.ZERO
		else:
			quit()
	return false
