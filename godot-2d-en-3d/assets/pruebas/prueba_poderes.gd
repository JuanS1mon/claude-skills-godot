extends SceneTree
## Prueba de: agarrar/arrojar enemigos derribados, lanzamiento y disparo cargados, caparazón
## del escarabajo (rebote de balas), absorber poderes (escarabajo, volador, slime) y los
## disparos de las estrellas. Imprime OK / FALLA por cada punto y guarda capturas.

const OUT := "C:/Users/PCJuan/AppData/Local/Temp/claude/eca94567a6215624/ad0deaed-32b2-4fa7-8fd0-d7674e2e28b8/scratchpad/"
var jug
var esc
var fallas := 0


func _initialize() -> void:
	change_scene_to_file("res://escenas/mundo.tscn")
	_correr()


func _p(a: String) -> void: Input.action_press(a)
func _r(a: String) -> void: Input.action_release(a)

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

func balas() -> Array:
	var r := []
	for n in current_scene.get_children():
		if n.get("perforante") != null:
			r.append(n)
	return r

func poner(x: float, y := 0.05) -> void:
	jug.global_position = Vector3(x, y, 0)
	jug.velocity = Vector3.ZERO

func tocar(a: String, cuadros := 3) -> void:
	_p(a)
	await esperar(cuadros)
	_r(a)
	await esperar(2)


func _correr() -> void:
	await esperar(20)
	jug = current_scene.get_node("Jugador")
	esc = current_scene.get_node("Escarabajo")
	var slime = current_scene.get_node("Slime")
	var volador = current_scene.get_node("Volador")
	jug.stats.vida_max = 99
	jug.vida = 99

	# --- 1. Derribar al escarabajo, agarrarlo y arrojarlo (toque corto y cargado) ---
	esc.radio_patrulla = 0.0
	esc.rango_vision = 0.0
	poner(esc.global_position.x - 1.3)
	await esperar(10)
	esc.recibir_dano(999, esc.global_position)
	await esperar(40)
	ver("escarabajo derribado", esc.estado == "derrotado", esc.estado)
	poner(esc.global_position.x - 1.0)
	_p("mover_der"); await esperar(2); _r("mover_der"); await esperar(5)
	await foto("e1_derribado")
	await tocar("agarrar")
	ver("agarra al enemigo derribado", jug.objeto == esc)
	await esperar(15)
	await foto("e2_cargando_enemigo")
	await tocar("agarrar", 3)
	await esperar(2)
	var v_toque: float = esc.velocity.length()
	ver("toque corto lo arroja", jug.objeto == null and v_toque > 5.0, v_toque)
	await esperar(8)
	await foto("e3_enemigo_volando")
	await esperar(90)
	poner(esc.global_position.x - 1.0)
	_p("mover_der"); await esperar(2); _r("mover_der"); await esperar(5)
	await tocar("agarrar")
	ver("lo vuelve a agarrar", jug.objeto == esc)
	_p("agarrar"); await esperar(50)
	ver("carga del lanzamiento al máximo", jug.carga_lanzar >= 1.0, jug.carga_lanzar)
	await foto("e4_cargando_lanzamiento")
	_r("agarrar"); await esperar(3)
	var v_carga: float = esc.velocity.length()
	ver("lanzamiento cargado más fuerte", v_carga > v_toque * 1.6, "%.1f vs %.1f" % [v_carga, v_toque])
	await esperar(100)

	# --- 2. Con un objeto en las manos no dispara ---
	poner(esc.global_position.x - 1.0)
	_p("mover_der"); await esperar(2); _r("mover_der"); await esperar(5)
	await tocar("agarrar")
	await tocar("disparar")
	ver("no dispara con algo en las manos", balas().size() == 0 and jug.objeto == esc, balas().size())

	# --- 3. Absorber el poder y cubrirse ---
	_p("abajo"); await esperar(2)
	await tocar("agarrar")
	ver("absorbe el poder del escarabajo", jug.poder == "escarabajo" and jug.objeto == null, jug.poder)
	await esperar(20)
	_p("agarrar"); await esperar(20)
	ver("abajo + acción: se cubre", jug.en_caparazon)
	await foto("e5_caparazon_jugador")
	var vida_antes: int = jug.vida
	jug.recibir_dano(1, jug.global_position + Vector3.RIGHT)
	ver("cubierto no recibe daño", jug.vida == vida_antes)
	# proyectil enemigo contra el jugador cubierto: rebota
	var p = load("res://escenas/proyectil_enemigo.tscn").instantiate()
	p.direccion = Vector3.LEFT
	current_scene.add_child(p)
	p.global_position = jug.global_position + Vector3(2.5, 0.9, 0)
	await esperar(25)
	ver("el proyectil enemigo rebota", is_instance_valid(p) and p.reflejado and p.direccion.x > 0.0)
	_r("agarrar"); _r("abajo"); await esperar(5)
	ver("al soltar sale del caparazón", not jug.en_caparazon)

	# --- 4. Disparo cargado ---
	poner(0.0)
	await esperar(10)
	await tocar("disparar", 2)
	var b1 := balas()
	ver("un toque = un disparo común", b1.size() == 1 and b1[0].escala == 1.0, b1.size())
	await esperar(100)
	_p("disparar"); await esperar(60)
	ver("carga completa", jug.carga_disparo >= 1.0, jug.carga_disparo)
	await foto("e6_cargando_disparo")
	_r("disparar"); await esperar(3)
	var b2 := balas()
	ver("disparo cargado grande y perforante", b2.size() == 1 and b2[0].escala > 2.0 and b2[0].perforante,
		b2[0].dano if b2.size() else -1)
	await foto("e7_disparo_cargado")
	await esperar(100)

	# --- 5. Escarabajo escondido: las balas comunes rebotan, la cargada no ---
	esc._reaparecer()
	await esperar(10)
	poner(esc.global_position.x - 4.0)
	jug.mirando = 1.0
	esc.recibir_dano(5, esc.global_position)
	await esperar(25)
	ver("tras el golpe se esconde", esc.estado == "escondido" and esc.rebota_balas(), esc.estado)
	var vida_e: int = esc.vida
	await tocar("disparar", 2)
	await esperar(8)
	await foto("e8_escondido")
	await esperar(12)
	ver("la bala común rebota (sin daño)", esc.vida == vida_e, esc.vida)
	_p("disparar"); await esperar(55); _r("disparar")
	await esperar(25)
	ver("la bala cargada rompe la defensa", esc.vida < vida_e, esc.vida)

	# --- 6. Tipos de disparo de las estrellas ---
	poner(0.0)
	await esperar(100)
	jug.mirando = 1.0
	jug.desbloquear_disparo("triple")
	await tocar("disparar", 2)
	ver("triple: 3 balas", balas().size() == 3, balas().size())
	await esperar(4)
	await foto("e9_triple")
	await esperar(100)
	jug.desbloquear_disparo("rebote")
	poner(21.5)
	await esperar(10)
	_p("abajo")  # en el piso no apunta abajo: saltar y disparar en diagonal hacia abajo
	_p("saltar"); await esperar(12); _r("saltar")
	_p("mover_der"); await esperar(2)
	await tocar("disparar", 2)
	_r("mover_der"); _r("abajo")
	var rebotadora = balas()[0] if balas().size() else null
	print("rebotadora: ", rebotadora.direccion if rebotadora else null, " jug y ", jug.global_position.y, " apuntado ", jug.apuntado)
	await esperar(25)
	ver("rebote: la bala rebotó en el piso", is_instance_valid(rebotadora) and rebotadora.rebotes < 3 and rebotadora.direccion.y > 0.0)
	await foto("e10_rebote")
	await esperar(160)
	jug.desbloquear_disparo("explosivo")
	var dummy = current_scene.get_node("EnemigoDummy")
	poner(dummy.global_position.x - 3.5)
	jug.mirando = 1.0
	await esperar(10)
	var vida_d: int = dummy.vida
	await tocar("disparar", 2)
	await esperar(14)
	await foto("e11_explosion")
	await esperar(10)
	ver("explosivo daña al muñeco", dummy.vida < vida_d, "%d -> %d" % [vida_d, dummy.vida])
	ver("3 disparos + normal desbloqueados", jug.tipos_disparo.size() == 4)
	jug.cambiar_disparo()
	ver("Q cambia de disparo", jug.tipo_disparo == "normal", jug.tipo_disparo)

	# --- 7. Poder del volador ---
	volador.rango_vision = 0.0
	poner(-15.0)
	await esperar(10)
	await foto("e12_volador")
	volador.recibir_dano(999, volador.global_position)
	await esperar(70)
	ver("volador derribado cae al piso", volador.estado == "derrotado" and volador.global_position.y < 0.6, volador.global_position.y)
	poner(volador.global_position.x - 1.0)
	_p("mover_der"); await esperar(2); _r("mover_der"); await esperar(5)
	await tocar("agarrar")
	await esperar(10)
	await foto("e13_cargando_volador")
	_p("abajo"); await esperar(2); await tocar("agarrar"); _r("abajo")
	ver("absorbe el poder del volador", jug.poder == "volador", jug.poder)
	poner(-12.0)
	await esperar(10)
	_p("saltar"); await esperar(20); _r("saltar"); await esperar(2)
	_p("saltar")
	var y_max := 0.0
	for i in 200:
		await physics_frame
		y_max = maxf(y_max, jug.global_position.y)
		if i == 60:
			await foto("e14_volando")
		if i == 100:
			_p("arriba"); _p("dash")
		if i == 102:
			_r("dash"); _r("arriba")
	_r("saltar")
	ver("volando sube mucho más (sin vuelo: 5,7 m)", y_max > 10.0, y_max)
	await esperar(120)

	# --- 8. Poder del slime ---
	slime.rango_vision = 0.0
	poner(slime.global_position.x - 4.0)
	await esperar(30)
	await foto("e15_slime")
	slime.recibir_dano(999, slime.global_position)
	await esperar(60)
	poner(slime.global_position.x - 1.0)
	_p("mover_der"); await esperar(2); _r("mover_der"); await esperar(5)
	await tocar("agarrar")
	await esperar(10)
	await foto("e16_cargando_slime")
	_p("abajo"); await esperar(2); await tocar("agarrar"); _r("abajo")
	ver("absorbe el poder del slime", jug.poder == "slime", jug.poder)
	poner(45.6, 3.0)
	_p("mover_der"); await esperar(25); _r("mover_der")
	var y_pegado: float = jug.global_position.y
	await esperar(60)
	ver("queda pegado a la pared sin empujar", jug._en_pared and absf(jug.global_position.y - y_pegado) < 0.1,
		"%.2f -> %.2f" % [y_pegado, jug.global_position.y])
	_p("abajo"); await esperar(40); _r("abajo")
	ver("con abajo se desliza", jug.global_position.y < y_pegado - 0.8, jug.global_position.y)
	await foto("e17_pegado_baba")
	await tocar("saltar", 6)
	await esperar(10)
	ver("salta desde la pared", jug.velocity.x < -1.0 or jug.global_position.x < 45.0, jug.global_position.x)

	print("FALLAS: ", fallas)
	quit()
