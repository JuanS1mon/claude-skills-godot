extends SceneTree

const OUT := "C:/Users/PCJuan/AppData/Local/Temp/claude/eca94567a6215624/ad0deaed-32b2-4fa7-8fd0-d7674e2e28b8/scratchpad/"
var f := 0
var jug
var enem

func _initialize() -> void:
	change_scene_to_file("res://escenas/mundo.tscn")

func _foto(n: String) -> void:
	root.get_texture().get_image().save_png(OUT + n + ".png")

func _process(_d: float) -> bool:
	f += 1
	if f == 5:
		jug = current_scene.get_node("Jugador")
		enem = current_scene.get_node("EnemigoDummy")
	match f:
		40: _foto("1_inicio")
		# agarrar caja1 (x=2) caminando hacia ella
		41: Input.action_press("mover_der")
		52: _foto("1b_corriendo")
		60: Input.action_release("mover_der")
		65: Input.action_press("agarrar")
		67: Input.action_release("agarrar")
		80:
			print("cargando: ", jug.objeto != null, " estado ", jug.estado)
			_foto("2_cargando")
		81: Input.action_press("mover_der")
		95: Input.action_press("saltar")
		104: _foto("2b_saltando_cargando")
		110: Input.action_release("saltar")
		150: Input.action_release("mover_der")
		155:
			print("pos tras salto ", jug.global_position)
			Input.action_press("agarrar")
		157: Input.action_release("agarrar")
		162: _foto("3_arrojada")
		230:
			print("vida enemigo tras caja ", enem.vida)
			Input.action_press("disparar")
		236: _foto("4_disparo")
		290: _foto("5_ko")
		300:
			Input.action_release("disparar")
			print("vida enemigo tras balas ", enem.vida, " pos jug ", jug.global_position)
		320: quit()
	return false
