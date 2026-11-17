extends SceneTree
## Pelea contra el jefe: despertar al entrar, patrón completo (embestida → aturdido,
## salto → ondas, lluvia de bellotas), daño doble aturdido, furia al 15 % (más rápido),
## muerte, puerta que se abre y estrella de premio.

const OUT := "C:/Users/PCJuan/AppData/Local/Temp/claude/10d934084c8dc372/ad0deaed-32b2-4fa7-8fd0-d7674e2e28b8/scratchpad/"
var jug
var jefe
var fallas := 0


func _initialize() -> void:
	change_scene_to_file("res://escenas/mundo.tscn")
	_correr()


func esperar(n: int) -> void:
	for i in n:
		await physics_frame

func foto(nombre: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png(OUT + nombre + ".png")

func ver(nombre: String, ok: bool, dato = "") -> void:
	if not ok:
		fallas += 1
	print("[", "OK" if ok else "FALLA", "] ", nombre, "  ", dato)

func contar(tipo: String) -> int:
	var n := 0
	for h in jefe.get_parent().get_children():
		if tipo == "onda" and h is Onda:
			n += 1
		elif tipo == "bellota" and h.get("balistica") != null:
			n += 1
	return n


func _correr() -> void:
	await esperar(20)
	jug = current_scene.get_node("Jugador")
	jefe = current_scene.get_node("ArenaJefe/Jefe")
	var puerta = current_scene.get_node("ArenaJefe/Puerta/Forma")
	var estrella = current_scene.get_node("ArenaJefe/EstrellaJefe")
	jug.stats.vida_max = 99
	jug.vida = 99

	ver("jefe dormido y puerta abierta", jefe.estado == "dormido" and puerta.disabled)
	ver("estrella de premio oculta", not estrella.visible)

	# Entrar a la arena.
	jug.global_position = Vector3(57.5, 0.1, 0)
	jug.velocity = Vector3.ZERO
	await esperar(30)
	ver("el jefe despierta al entrar", jefe.estado != "dormido", jefe.estado)
	ver("la puerta se cierra", not puerta.disabled)
	await foto("j1_despierta")

	# Observar un ciclo entero del patrón.
	var vistos := {}
	var ondas_max := 0
	var bellotas_max := 0
	var t_embestida_normal := 0.0
	for i in 60 * 22:
		await physics_frame
		vistos[jefe.estado] = true
		ondas_max = maxi(ondas_max, contar("onda"))
		bellotas_max = maxi(bellotas_max, contar("bellota"))
		if jefe.estado == "embistiendo":
			t_embestida_normal = maxf(t_embestida_normal, absf(jefe.velocity.x))
		if jefe.estado == "aturdido" and not vistos.has("_foto_atur"):
			vistos["_foto_atur"] = true
			await foto("j2_aturdido")
		if ondas_max > 0 and not vistos.has("_foto_onda"):
			vistos["_foto_onda"] = true
			await foto("j3_ondas")
		if bellotas_max > 0 and not vistos.has("_foto_lluvia"):
			vistos["_foto_lluvia"] = true
			await foto("j4_lluvia")
		# El jugador se corre a una esquina para no morir pisoteado.
		jug.global_position.x = clampf(jug.global_position.x, 56.0, 58.0)
	for e in ["aviso_embestida", "embistiendo", "aturdido", "aviso_salto", "saltando", "caida", "lluvia"]:
		ver("estado visto: " + e, vistos.has(e))
	ver("hubo ondas de choque (2 a la vez)", ondas_max >= 2, ondas_max)
	ver("hubo lluvia de bellotas", bellotas_max >= 3, bellotas_max)

	# Daño normal vs daño aturdido.
	var v0: int = jefe.vida
	while jefe.estado == "aturdido":
		await physics_frame
	jefe.recibir_dano(10, jefe.global_position)
	ver("daño normal 10", v0 - jefe.vida == 10, v0 - jefe.vida)
	while jefe.estado != "aturdido":
		await physics_frame
		jug.global_position.x = clampf(jug.global_position.x, 56.0, 58.0)
	v0 = jefe.vida
	jefe.recibir_dano(10, jefe.global_position)
	ver("daño doble aturdido (20)", v0 - jefe.vida == 20, v0 - jefe.vida)

	# Bajarlo hasta la furia (fuera de la ventana de daño doble).
	while jefe.estado == "aturdido":
		await physics_frame
		jug.global_position.x = clampf(jug.global_position.x, 56.0, 58.0)
	jefe.recibir_dano(jefe.vida - int(jefe.vida_max * 0.15) - 5, jefe.global_position)
	await esperar(5)
	ver("todavía sin furia", not jefe.furia, jefe.vida)
	while jefe.estado == "aturdido":
		await physics_frame
		jug.global_position.x = clampf(jug.global_position.x, 56.0, 58.0)
	jefe.recibir_dano(10, jefe.global_position)
	await esperar(10)
	ver("furia al 15 %", jefe.furia)
	await foto("j5_furia")
	var t_embestida_furia := 0.0
	for i in 60 * 28:
		await physics_frame
		# Esquiva como un jugador real: siempre en el lado opuesto al jefe.
		jug.global_position.x = 73.5 if jefe.global_position.x < 65.0 else 56.5
		if jefe.estado == "embistiendo":
			t_embestida_furia = maxf(t_embestida_furia, absf(jefe.velocity.x))
		if t_embestida_furia > 15.0 and jefe.estado == "aturdido":
			break
	ver("en furia embiste más rápido", t_embestida_furia > t_embestida_normal * 1.3,
		"%.1f vs %.1f" % [t_embestida_furia, t_embestida_normal])

	# Rematarlo.
	jefe.recibir_dano(9999, jefe.global_position)
	await esperar(30)
	ver("jefe vencido", jefe.estado == "muerto")
	ver("la puerta se abre", puerta.disabled)
	ver("aparece la estrella de premio", estrella.visible)
	await foto("j6_vencido")
	await esperar(60 * 3)
	ver("el cuerpo desaparece", not is_instance_valid(jefe) or jefe.sprite.modulate.a < 0.1)
	await foto("j7_final")

	print("FALLAS: ", fallas)
	quit()
