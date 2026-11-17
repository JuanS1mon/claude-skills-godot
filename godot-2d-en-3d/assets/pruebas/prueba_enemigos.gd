extends SceneTree
## Enemigos vivos: el volador se tira en picada, el slime salta hacia el jugador, y un
## enemigo derribado arrojado daña a otro enemigo.
const OUT := "C:/Users/PCJuan/AppData/Local/Temp/claude/eca94567a6215624/ad0deaed-32b2-4fa7-8fd0-d7674e2e28b8/scratchpad/"
var jug

func _initialize() -> void:
	change_scene_to_file("res://escenas/mundo.tscn")
	_correr()

func esperar(n: int) -> void:
	for i in n:
		await physics_frame

func foto(nombre: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png(OUT + nombre + ".png")

func _correr() -> void:
	await esperar(20)
	jug = current_scene.get_node("Jugador")
	var vol = current_scene.get_node("Volador")
	var slime = current_scene.get_node("Slime")
	var dummy = current_scene.get_node("EnemigoDummy")
	jug.global_position = Vector3(-14.0, 0.05, 0)
	var estados := {}
	var vida0: int = jug.vida
	for i in 300:
		await physics_frame
		estados[vol.estado] = true
		if vol.estado == "picada" and not estados.has("foto"):
			estados["foto"] = true
			await esperar(8)
			await foto("v1_picada")
	print("volador estados: ", estados.keys(), "  vida jugador ", vida0, " -> ", jug.vida, "  volador en ", vol.global_position)
	jug.global_position = Vector3(38.5, 0.05, 0)
	jug.vida = 5
	var x0: float = slime.global_position.x
	var y_max := 0.0
	for i in 240:
		await physics_frame
		y_max = maxf(y_max, slime.global_position.y)
		if i == 70:
			await foto("v2_slime_salta")
	print("slime: de x ", x0, " a ", slime.global_position.x, "  salto max ", y_max, "  vida jugador ", jug.vida)
	# enemigo arrojado contra el muñeco
	slime.recibir_dano(999, slime.global_position)
	await esperar(30)
	slime.global_position = dummy.global_position + Vector3(-3.0, 0.5, 0)
	var v0: int = dummy.vida
	slime.al_soltar(Vector3(14.0, 2.0, 0))
	await esperar(40)
	print("muñeco tras recibir al slime arrojado: ", v0, " -> ", dummy.vida)
	await esperar(60 * 9)
	print("slime reapareció: ", slime.estado, " en ", slime.global_position, " vida ", slime.vida)
	quit()
