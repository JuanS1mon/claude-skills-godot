extends RefCounted
## Respuesta al toque y apariciones: los "saltitos" que hacen que la interfaz se sienta viva. Solo animan, no cambian nada del juego.
## Se usa con `const Toque = preload("res://scripts/toque.gd")` (sin `class_name`, como `Ayudas`).
##
## - `enganchar(boton)`: el botón se hunde al apretarlo y rebota al soltarlo. Lo llama `Audio` para TODO botón que entra al árbol
##   (igual que el sonido del clic); para uno que no deba moverse, `set_meta(&"sin_rebote", true)` antes de agregarlo.
## - `aparecer(panel)`: un cartel entra con un pequeño "pop" (crece desde 92% y aparece) en vez de salir de golpe.
## - `entrar(pantalla)`: una pantalla entera aparece con un fundido corto y sube unos píxeles.
## - `escalonar(nodos)`: una fila o grilla de cosas aparece de a una (las cartas de una invocación x10).
## Todo usa `set_ignore_time_scale`: la mejora "velocidad de oleadas" acelera el reloj del juego y la interfaz no tiene que acelerarse.

const HUNDIDO := 0.94            ## cuánto se achica el botón mientras está apretado
const CLAVE_BASE := &"_toque_base"
const CLAVE_TWEEN := &"_toque_tween"


static func enganchar(boton: BaseButton) -> void:
	if boton.has_meta(&"sin_rebote") or boton.has_meta(CLAVE_BASE):
		return
	boton.set_meta(CLAVE_BASE, Vector2.ZERO)   # se mide en el primer toque (al entrar al árbol todavía no tiene su escala final)
	boton.button_down.connect(_apretar.bind(boton))
	boton.button_up.connect(_soltar.bind(boton))


static func _apretar(boton: BaseButton) -> void:
	# Su escala "de reposo" se mide en cada toque (otro código puede haberla cambiado), salvo que todavía esté rebotando del toque anterior.
	var viejo := _tween_de(boton)
	var rebotando: bool = viejo != null and viejo.is_running()
	if boton.get_meta(CLAVE_BASE) == Vector2.ZERO or not rebotando:
		boton.set_meta(CLAVE_BASE, boton.scale)
	boton.pivot_offset = boton.size / 2.0
	_animar(boton, boton.get_meta(CLAVE_BASE) * HUNDIDO, 0.06, Tween.TRANS_QUAD)


static func _soltar(boton: BaseButton) -> void:
	if boton.get_meta(CLAVE_BASE) == Vector2.ZERO:
		return
	_animar(boton, boton.get_meta(CLAVE_BASE), 0.24, Tween.TRANS_BACK)


static func _animar(nodo: Control, escala: Vector2, duracion: float, curva: Tween.TransitionType) -> void:
	_cortar(nodo)
	if not nodo.is_inside_tree():
		nodo.scale = escala
		return
	var t := nodo.create_tween().set_ignore_time_scale(true)
	t.tween_property(nodo, "scale", escala, duracion).set_trans(curva).set_ease(Tween.EASE_OUT)
	nodo.set_meta(CLAVE_TWEEN, t)


static func _cortar(nodo: Control) -> void:
	var viejo = _tween_de(nodo)
	if viejo != null:
		viejo.kill()


## El tween de toque/aparición que ese nodo tiene en marcha (null si no hay o ya terminó).
static func _tween_de(nodo: Control) -> Tween:
	if not nodo.has_meta(CLAVE_TWEEN):   # (`get_meta` con valor por defecto null da error si la clave no existe)
		return null
	var t = nodo.get_meta(CLAVE_TWEEN)
	return t if t is Tween and t.is_valid() else null


## Un cartel (el panel de un resultado, de la bienvenida...) entra con un "pop". `desde`: tamaño inicial (1 = sin crecer).
static func aparecer(panel: Control, desde: float = 0.92, duracion: float = 0.28) -> void:
	if panel == null or not panel.is_inside_tree():
		return
	_cortar(panel)
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2.ONE * desde
	panel.modulate.a = 0.0
	var t := panel.create_tween().set_parallel().set_ignore_time_scale(true)
	t.tween_property(panel, "modulate:a", 1.0, duracion * 0.6)
	t.tween_property(panel, "scale", Vector2.ONE, duracion).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel.set_meta(CLAVE_TWEEN, t)


## Una pantalla entera aparece: fundido corto y sube `sube` píxeles hasta su lugar. No toca su tamaño (las pantallas miden cosas con él).
static func entrar(pantalla: Control, sube: float = 14.0, duracion: float = 0.2) -> void:
	if pantalla == null or not pantalla.is_inside_tree():
		return
	_cortar(pantalla)
	pantalla.modulate.a = 0.0
	pantalla.position.y = sube
	var t := pantalla.create_tween().set_parallel().set_ignore_time_scale(true)
	t.tween_property(pantalla, "modulate:a", 1.0, duracion)
	t.tween_property(pantalla, "position:y", 0.0, duracion).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pantalla.set_meta(CLAVE_TWEEN, t)


## Deja una pantalla como si nunca se hubiera animado (por si se la esconde a mitad de la entrada).
static func asentar(pantalla: Control) -> void:
	_cortar(pantalla)
	pantalla.modulate.a = 1.0
	pantalla.position.y = 0.0


## Varias piezas (cartas, filas) aparecen de a una, cada `paso` segundos, creciendo desde chicas. `al_aparecer` (opcional) se llama
## con el índice de cada pieza justo cuando entra (para un sonido o un destello).
static func escalonar(nodos: Array, paso: float = 0.07, espera: float = 0.0, al_aparecer: Callable = Callable()) -> void:
	var i := 0
	for n in nodos:
		var nodo := n as Control
		if nodo == null or not nodo.is_inside_tree():
			continue
		_cortar(nodo)
		nodo.pivot_offset = nodo.custom_minimum_size / 2.0 if nodo.size == Vector2.ZERO else nodo.size / 2.0
		nodo.scale = Vector2(0.5, 0.5)
		nodo.modulate.a = 0.0
		var t := nodo.create_tween().set_ignore_time_scale(true)
		t.tween_interval(espera + paso * i)
		if al_aparecer.is_valid():
			t.tween_callback(al_aparecer.bind(i))
		t.tween_property(nodo, "modulate:a", 1.0, 0.1)
		t.parallel().tween_property(nodo, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		nodo.set_meta(CLAVE_TWEEN, t)
		i += 1
