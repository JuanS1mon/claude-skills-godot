extends SceneTree

const OUT := "C:/Users/PCJuan/AppData/Local/Temp/claude/eca94567a6215624/ad0deaed-32b2-4fa7-8fd0-d7674e2e28b8/scratchpad/"
var f := 0
var jug
var caja
var y_max := 0.0
var x0 := 0.0

func _initialize() -> void:
	change_scene_to_file("res://escenas/mundo.tscn")

func _foto(n: String) -> void:
	root.get_texture().get_image().save_png(OUT + n + ".png")

func _apretar(a: String) -> void:
	Input.action_press(a)

func _process(_d: float) -> bool:
	f += 1
	if jug and f > 40 and f < 140:
		y_max = maxf(y_max, jug.global_position.y)
	match f:
		10:
			jug = current_scene.get_node("Jugador")
			caja = current_scene.get_node("Caja1")
		# --- doble salto ---
		40: _apretar("saltar")
		58: Input.action_release("saltar")
		62: _apretar("saltar")
		63: print("saltos tras doble: ", jug._saltos_restantes, " vy ", jug.velocity.y)
		67: _foto("d1_vuelta")
		75: Input.action_release("saltar")
		78: _apretar("saltar")  # tercer salto: no debe pasar nada
		79:
			print("vy tras 3er toque (no debe ser 9.5): ", jug.velocity.y)
			Input.action_release("saltar")
		140: print("altura max con doble salto: ", y_max)
		# --- dash en el piso contra la caja ---
		150:
			x0 = jug.global_position.x
			print("caja antes: ", caja.global_position.x)
			_apretar("dash")
		151: Input.action_release("dash")
		153: _foto("d2_dash_piso")
		170: print("dash piso: avanzó ", jug.global_position.x - x0, "  caja después: ", caja.global_position.x)
		# --- dash en el aire hacia la izquierda ---
		200:
			_apretar("mover_izq")
			_apretar("saltar")
		215:
			x0 = jug.global_position.x
			print("y antes del dash aéreo: ", jug.global_position.y)
			_apretar("dash")
		216: Input.action_release("dash")
		219:
			print("y durante el dash aéreo: ", jug.global_position.y, " vy ", jug.velocity.y)
			_foto("d3_dash_aire")
		235:
			print("dash aire: avanzó ", jug.global_position.x - x0)
			_apretar("dash")
		236:
			Input.action_release("dash")
			print("segundo dash aéreo (debe ser false): ", jug.esta_en_dash())
		260: quit()
	return false
