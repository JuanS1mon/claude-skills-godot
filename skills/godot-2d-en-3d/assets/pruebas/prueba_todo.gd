extends SceneTree
## Recorre las mecánicas nuevas teletransportando al jugador a cada zona.

const OUT := "C:/Users/PCJuan/AppData/Local/Temp/claude/eca94567a6215624/ad0deaed-32b2-4fa7-8fd0-d7674e2e28b8/scratchpad/"
var f := 0
var m
var jug
var dummy
var esc
var hud

func _initialize() -> void:
	change_scene_to_file("res://escenas/mundo.tscn")

func _foto(n: String) -> void:
	root.get_texture().get_image().save_png(OUT + n + ".png")

func _ir(x: float, y := 0.1) -> void:
	jug.global_position = Vector3(x, y, 0)
	jug.velocity = Vector3.ZERO

func _soltar_todo() -> void:
	for a in ["mover_izq", "mover_der", "arriba", "abajo", "saltar", "disparar", "agarrar", "golpe", "dash"]:
		Input.action_release(a)

func _process(_d: float) -> bool:
	f += 1
	match f:
		5:
			m = current_scene
			jug = m.get_node("Jugador")
			dummy = m.get_node("EnemigoDummy")
			esc = m.get_node("Escarabajo")
			hud = m.get_node("HudDebug")
			print("estrellas en el mapa: ", hud._total)
		# 1) apuntar arriba y en diagonal
		30:
			_ir(4.0)
			Input.action_press("arriba"); Input.action_press("disparar")
		38:
			print("[apuntar] arriba: ", jug.apuntado)
			_foto("t1_arriba")
			Input.action_press("mover_der")
		44:
			print("[apuntar] diagonal: ", jug.apuntado)
			_foto("t1_diagonal")
			_soltar_todo()
		# 2) golpe al muñeco
		60:
			_ir(6.2)
			jug.mirando = 1.0
		62: print("[golpe] vida muñeco antes: ", dummy.vida); Input.action_press("golpe")
		64: _foto("t2_golpe")
		66: Input.action_release("golpe")
		75: print("[golpe] vida muñeco después: ", dummy.vida)
		# 3) apilar cajas: agarrar Caja4, dejarla sobre Caja5
		90:
			_ir(11.6)
			jug.mirando = 1.0
		92: Input.action_press("agarrar")
		93: Input.action_release("agarrar")
		100: print("[cajas] cargando: ", jug.objeto != null)
		101: _ir(12.6)  # ahora la Caja5 (13.6) queda adelante
		105: Input.action_press("abajo")
		106: Input.action_press("agarrar")
		107: Input.action_release("agarrar")
		108: Input.action_release("abajo")
		140:
			var c4 = m.get_node("PuzzleCajas/Caja4")
			print("[cajas] caja4 apilada en: ", c4.global_position, " (y ~1.35 = arriba de otra)")
			_foto("t3_apilada")
		# 4) pared: chimenea, empujar contra la pared izquierda
		160: _ir(-22.5, 4.0)
		161: Input.action_press("mover_izq")
		185:
			print("[pared] estado: ", jug.estado, " vy: ", jug.velocity.y)
			_foto("t4_pared")
		186: Input.action_press("saltar")
		188:
			print("[pared] salto de pared vel: ", jug.velocity)
			Input.action_release("saltar")
		196: _foto("t4_salto_pared")
		200: _soltar_todo()
		# 5) estrellas: tocar la de la chimenea
		210: _ir(-23, 8.9)
		230: print("[estrellas] juntadas: ", hud.estrellas)
		# 6) escarabajo: acercarse y esperar el disparo
		240:
			_ir(22.0)
			jug.mirando = 1.0
		241: print("[enemigo] vida jugador: ", jug.vida, "  estado escarabajo: ", esc.estado)
		300:
			print("[enemigo] estado escarabajo: ", esc.estado, "  vida jugador: ", jug.vida)
			_foto("t5_enemigo")
		330: Input.action_press("disparar")
		420:
			Input.action_release("disparar")
			print("[enemigo] vida escarabajo tras disparos: ", esc.vida, " estado: ", esc.estado, "  vida jugador: ", jug.vida)
			_foto("t6_enemigo_ko")
		440: quit()
	return false
