@tool
class_name Ventana
extends Node2D
## Aspecto de una ventana: el cristal es transparente y deja ver un cielo con arte que cambia con la hora y con el
## clima (nubes, lluvia, nieve, hojas, viento y relámpagos), y en el suelo proyecta una mancha de luz con la forma
## exacta de sus paneles (la imagen `<diseño>_parche.png`). La mancha toma del sol y de la luna de LuzNatural la
## posición (de ahí sale su inclinación y su largo), la intensidad y el color.
## Vive dentro de un Mueble (ventana.tscn), que es quien la arrastra y la pega a la pared. El origen es el centro de
## la base (el alféizar). La variante y el alto salen de la ficha del mueble.

const ARTE: Array[String] = ["ventana_rosa", "ventana_arco", "ventana_azul"]
const CARPETA_VENTANAS: String = "res://assets/ventanas/"
const CARPETA_CIELOS: String = "res://assets/cielos/"
## Capas del cielo de abajo arriba (la noche va dos veces para cerrar el ciclo). Ver CicloDia.tabla_capas.
const CAPAS: Array[String] = ["noche", "amanecer", "dia", "atardecer", "noche"]
## Colores de reserva, por si todavía no existe la imagen del cielo: [parte alta, parte baja].
const COLORES_RESERVA: Dictionary = {
	"noche": [Color(0.03, 0.05, 0.16), Color(0.10, 0.12, 0.30)],
	"amanecer": [Color(0.45, 0.55, 0.85), Color(1.00, 0.72, 0.50)],
	"dia": [Color(0.40, 0.68, 0.95), Color(0.75, 0.88, 1.00)],
	"atardecer": [Color(0.50, 0.35, 0.60), Color(1.00, 0.62, 0.35)],
}
## El sol y la luna son UNO para toda la casa (su recorrido está en CicloDia): cada ventana solo los muestra
## si pasan por su cristal, que los recorta.
## Diámetro del sol y de la luna en píxeles de la casa, igual en todas las ventanas.
const TAMANO_ASTRO: float = 44.0
## Un mueble tapa la luz si mide al menos esto de alto, y cuenta hasta esta distancia más allá de donde empieza la mancha.
const ALTO_QUE_TAPA: float = 90.0
const ZONA_TAPADO: float = 90.0
const FONDO_PRUEBA: String = "res://assets/fondos/casa_fondo.png"
const ESCENA_LUZ_NATURAL: String = "res://scenes/luz_natural.tscn"

## Solo se usan si la escena se pone suelta; dentro de un mueble mandan los de su ficha.
@export var variante: int = 0:
	set(valor):
		variante = valor
		_rearmar_en_editor()
@export var alto_en_juego: float = 150.0:
	set(valor):
		alto_en_juego = valor
		_rearmar_en_editor()
## Qué tan fuerte se ve la mancha de luz en el piso (multiplica la energía de la luz natural).
@export_range(0.5, 6.0, 0.1) var intensidad_mancha: float = 2.6
## Distancia desde la base de la ventana hasta donde empieza la mancha de luz en el suelo.
@export var distancia_al_suelo: float = 45.0
@export_group("Prueba")
## Al ejecutar esta escena sola (F6): hora con la que arranca y qué tan lejos se ve (menor = más lejos).
@export_range(0.0, 24.0, 0.1) var hora_inicial_prueba: float = 9.0
@export_range(0.2, 1.0, 0.05) var zoom_prueba: float = 0.5

@onready var _cuerpo: Node2D = $Cuerpo
@onready var _cristal: Sprite2D = $Cuerpo/Cristal
@onready var _cielo: Node2D = $Cuerpo/Cristal/Cielo
@onready var _marco: Sprite2D = $Cuerpo/Marco

var _tam: Vector2
## Inclinación de su pared (ver orientar) y hacia dónde cae su luz en el piso.
var _inclinacion: float = 0.0
var _dir_luz: Vector2 = Vector2(0.0, 1.0)
var _indice_arte: int = 0
var _esc: float = 1.0
## Manchas de luz en el suelo (solo al jugar).
var _luz_sol: PointLight2D
var _luz_luna: PointLight2D
## Cuánta luz tapan los muebles altos delante del cristal (0 a 1), con cambio gradual.
var _tapado: float = 0.0
var _capas: Array[Sprite2D] = []
var _sol: Sprite2D
var _luna: Sprite2D
var _escala_sol: Vector2 = Vector2.ONE
## Clima que se ve por el cristal. Se crean en _crear_clima() y quedan recortados por el cristal.
var _lluvia: CPUParticles2D
var _nieve: CPUParticles2D
var _hojas: CPUParticles2D
var _viento: CPUParticles2D
var _destello: ColorRect
## Nubes grises que cruzan el cristal despacio cuando el cielo está cubierto.
var _nubes: Array[Sprite2D] = []
var _nubes_velocidad: Array[float] = []
var _cartel: Label
## Manto gris del cielo cubierto: su opacidad crece con las nubes y es más oscuro con lluvia.
var _manto: ColorRect


func _ready() -> void:
	var alto := _armar()
	if Engine.is_editor_hint():
		return
	# Restos de las guías de tramos de una versión anterior: no hacen falta.
	for nombre in ["Luz", "Marcos"]:
		var guia := get_node_or_null("Cuerpo/" + nombre)
		if guia != null:
			guia.queue_free()
	_crear_manchas()
	if _es_prueba():
		_preparar_prueba(alto)


## Arma el aspecto de la ventana (marco, cristal, cielo y clima) según su diseño. Devuelve el alto en píxeles.
func _armar() -> float:
	var indice := variante
	var alto := alto_en_juego
	var padre := get_parent() as Mueble
	# Con ficha (en el juego) mandan sus medidas; sin ficha (en el editor) valen los @export de esta escena.
	if padre != null and padre.ficha != null:
		alto = padre.tamano.y
		indice = padre.ficha.variante
	_indice_arte = clampi(indice, 0, ARTE.size() - 1)
	var nombre := ARTE[_indice_arte]
	var marco := load(CARPETA_VENTANAS + nombre + "_marco.png") as Texture2D
	var cristal := load(CARPETA_VENTANAS + nombre + "_cristal.png") as Texture2D
	_tam = marco.get_size()
	_esc = alto / _tam.y
	_cuerpo.scale = Vector2(_esc, _esc)
	var esquina := Vector2(-_tam.x / 2.0, -_tam.y)
	_marco.texture = marco
	_marco.position = esquina
	_cristal.texture = cristal
	_cristal.position = esquina
	if padre != null and padre.solo_en_pared:
		distancia_al_suelo = Mueble.ALTURA_VENTANA + 14.0   # la mancha cae en el piso, bajo la pared (ver GeometriaCuarto)
	_crear_cielo()
	_crear_clima()
	return alto


## Inclina el cuerpo de la ventana para que quede en el plano de su pared: `inclinacion` es cuánto baja la pared por cada
## píxel hacia la derecha (negativa en la pared izquierda, positiva en la derecha). Las verticales no cambian.
func orientar(inclinacion: float) -> void:
	_inclinacion = inclinacion
	# La luz entra de frente a su pared: en el piso viaja por el otro eje isométrico (hacia la derecha y abajo desde la
	# pared izquierda, hacia la izquierda y abajo desde la derecha).
	_dir_luz = Vector2(1.0 if inclinacion < 0.0 else -1.0, absf(inclinacion)).normalized()
	_cuerpo.transform = Transform2D(Vector2(_esc, _esc * inclinacion), Vector2(0.0, _esc), Vector2.ZERO)


## Hacia dónde cae en el piso la luz que entra por esta ventana (vector unitario): lo usan las sombras.
func direccion_luz() -> Vector2:
	return _dir_luz


## El recorrido del sol y de la luna se definió para una ventana a la altura de siempre (Y_PARED): cada ventana lo traslada
## a su propia altura, así los astros cruzan el cristal estén donde estén las ventanas.
func _punto_astro(p: Vector2) -> Vector2:
	return Vector2(p.x, global_position.y + (p.y - Mueble.Y_PARED))


## Solo en el editor: al cambiar la variante o el alto en el Inspector, se vuelve a armar la ventana.
func _rearmar_en_editor() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	for hijo in _cielo.get_children():
		hijo.free()
	_capas.clear()
	_nubes.clear()
	_nubes_velocidad.clear()
	_sol = null
	_luna = null
	_armar()


## Las dos manchas del suelo (sol y luna). Usan los nodos LuzSol y LuzLuna de la escena si existen; si no, los crean.
func _crear_manchas() -> void:
	var ruta := CARPETA_VENTANAS + ARTE[_indice_arte] + "_parche.png"
	_luz_sol = _luz_de_mancha("LuzSol", ruta)
	_luz_luna = _luz_de_mancha("LuzLuna", ruta)


## Cada luz carga su propia copia de la imagen: compartir una textura entre dos luces da un error interno de Godot.
func _luz_de_mancha(nombre: String, ruta: String) -> PointLight2D:
	var luz := get_node_or_null(nombre) as PointLight2D
	if luz == null:
		luz = PointLight2D.new()
		luz.name = nombre
		add_child(luz)
	luz.texture = ResourceLoader.load(ruta, "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	luz.energy = 0.0
	luz.visible = false
	# Sin sombras propias: las sombras de los muebles y de Zarita las dibuja Sombra, siempre hacia el lado contrario al sol.
	luz.shadow_enabled = false
	return luz


## Cuánta de la luz de esta ventana tapan los muebles altos que están justo delante del cristal, pegados a la pared:
## 0 = nada, 1 = todo el ancho tapado. Un mueble bajo (una mesa) no tapa; uno alto (un armario o una biblioteca) sí.
func _tapado_por_muebles() -> float:
	var ancho := _tam.x * _esc
	var x0 := global_position.x - ancho / 2.0
	var x1 := global_position.x + ancho / 2.0
	var y_limite := global_position.y + distancia_al_suelo + ZONA_TAPADO
	var tapado := 0.0
	for nodo in get_tree().get_nodes_in_group("muebles"):
		var m := nodo as Mueble
		if m == null or m.solo_en_pared or m.apoyado_en != null or not m.bloquea or m.tamano.y < ALTO_QUE_TAPA:
			continue
		var base := m.huella if m.huella != Vector2.ZERO else Vector2(m.tamano.x * 0.8, clampf(m.tamano.y * 0.25, 20.0, 60.0))
		# Su huella tiene que estar delante de la pared, dentro de la franja que va del cristal hacia el suelo.
		if m.global_position.y < global_position.y or m.global_position.y - base.y > y_limite:
			continue
		var solape := minf(x1, m.global_position.x + base.x / 2.0) - maxf(x0, m.global_position.x - base.x / 2.0)
		tapado = maxf(tapado, clampf(solape / ancho, 0.0, 1.0))
	return tapado


## Cuánta mancha de luz hay en un punto del mundo, de 0 (nada) a 1 (dentro), con un borde suave. Lo usan las sombras de
## los muebles y de Zarita para aparecer solo donde cae la luz. Mide el rectángulo de la imagen, no cada panel.
func cobertura_en(punto: Vector2, es_sol: bool) -> float:
	var luz := _luz_sol if es_sol else _luz_luna
	if luz == null or not luz.visible or luz.texture == null:
		return 0.0
	var local := luz.global_transform.affine_inverse() * punto
	var mitad := luz.texture.get_size() / 2.0
	var margen := minf(1.0 - absf(local.x) / mitad.x, 1.0 - absf(local.y) / mitad.y)
	# La entrada es gradual: la sombra crece a lo largo de buena parte del borde en vez de aparecer de golpe.
	return smoothstep(0.0, 0.55, margen) * _factor_pared(es_sol)


## El sol (y la luna) sale por un lado y se pone por el otro: por la mañana alumbra la pared izquierda, al mediodía las dos
## a medias y por la tarde la derecha. Devuelve cuánta luz recibe la pared de esta ventana, de 0 a 1.
func _factor_pared(es_sol: bool) -> float:
	var h: float = CicloDia.hora
	var t := (h - 6.0) / 13.0
	if not es_sol:
		t = ((h if h >= 18.0 else h + 24.0) - 18.0) / 12.0
	if _inclinacion < 0.0:   # pared izquierda
		return clampf((0.62 - t) / 0.3, 0.0, 1.0)
	return clampf((t - 0.38) / 0.3, 0.0, 1.0)


## Pone la mancha en el suelo según el sol (o la luna) de LuzNatural: la imagen se inclina hacia el lado contrario a la
## luz y se alarga cuando el sol está bajo. Parte de la base de la ventana, a `distancia_al_suelo`.
func _actualizar_mancha(luz: PointLight2D, natural: LuzNatural, es_sol: bool) -> void:
	var energia := 0.0
	if natural != null and luz.texture != null:
		energia = natural.energia_sol if es_sol else natural.energia_luna
	energia *= (1.0 - _tapado) * _factor_pared(es_sol) * intensidad_mancha * (1.0 if es_sol else 1.8)   # la luna es más tenue: se refuerza
	luz.energy = energia
	luz.visible = energia > 0.01
	if not luz.visible:
		return
	luz.color = natural.color_sol if es_sol else natural.color_luna
	var origen_luz: Vector2 = natural.posicion_sol if es_sol else natural.posicion_luna
	var base := global_position
	var d := base - origen_luz
	var desvio := d.x / maxf(d.y, 1.0)   # cuánto se corre el rayo hacia un lado: solo decide qué tan larga es la mancha
	var apertura := clampf(absf(desvio) / 2.0, 0.0, 1.0)
	var largo := _esc * (0.8 + 1.1 * apertura * apertura)
	# La mancha tiene el ancho de la ventana a lo largo de su pared (mismo eje que la cizalla) y se alarga por el otro eje
	# isométrico, hacia adentro de la habitación; empieza bajo la ventana, donde la pared toca el piso.
	var ancho_eje := Vector2(_esc, _esc * _inclinacion)
	var largo_eje := _dir_luz * largo
	var arriba := Vector2(base.x, base.y + distancia_al_suelo)
	luz.global_transform = Transform2D(ancho_eje, largo_eje, arriba + largo_eje * (luz.texture.get_height() / 2.0))


## true al ejecutar esta escena sola (F6), no cuando la instancia la casa.
func _es_prueba() -> bool:
	return not Engine.is_editor_hint() and get_tree().current_scene == (get_parent() if get_parent() is Mueble else self)


## Simulación (F6 sobre esta escena): la ventana en la pared de la casa, con el suelo, la luz natural y los controles.
func _preparar_prueba(alto: float) -> void:
	var raiz := get_tree().current_scene as Node2D
	var padre := get_parent() as Mueble
	if padre != null:
		# Un hueco del tamaño del cristal en la pared, como al jugar.
		padre.tamano = Vector2(_tam.x * _esc, alto)
	raiz.position = Vector2(360.0, Mueble.Y_PARED)
	CicloDia.hora = hora_inicial_prueba
	var nuevos: Array[Node] = []
	if ResourceLoader.exists(FONDO_PRUEBA):
		var fondo := TextureRect.new()
		fondo.texture = load(FONDO_PRUEBA) as Texture2D
		fondo.size = Vector2(720.0, 1280.0)
		fondo.position = -raiz.position
		fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fondo.z_index = -10
		nuevos.append(fondo)
	var luz := (load(ESCENA_LUZ_NATURAL) as PackedScene).instantiate() as Node2D
	luz.position = -raiz.position
	nuevos.append(luz)
	var camara := Camera2D.new()
	camara.position = Vector2(360.0, 520.0) - raiz.position
	camara.zoom = Vector2(zoom_prueba, zoom_prueba)
	nuevos.append(camara)
	var capa := CanvasLayer.new()
	_cartel = Label.new()
	_cartel.position = Vector2(12.0, 8.0)
	_cartel.add_theme_font_size_override("font_size", 20)
	capa.add_child(_cartel)
	nuevos.append(capa)
	for nodo in nuevos:
		raiz.add_child.call_deferred(nodo)


## ← y → cambian la hora, Enter pausa el tiempo, ↑ cambia el clima y ↓ lanza un relámpago.
func _controlar_prueba(delta: float) -> void:
	var sentido := Input.get_axis("ui_left", "ui_right")
	if sentido != 0.0:
		CicloDia.hora = fposmod(CicloDia.hora + sentido * 3.0 * delta, 24.0)
	if Input.is_action_just_pressed("ui_accept"):
		CicloDia.set_process(not CicloDia.is_processing())
	if Input.is_action_just_pressed("ui_up"):
		CicloDia.clima.ciclar()
	if Input.is_action_just_pressed("ui_down"):
		CicloDia.clima.disparar_relampago()
	if _cartel != null:
		_cartel.text = "Hora %02d:%02d%s   Clima: %s\n← → hora · Enter pausa · ↑ clima · ↓ relámpago" % [
			int(CicloDia.hora), int(fmod(CicloDia.hora, 1.0) * 60.0),
			" (pausada)" if not CicloDia.is_processing() else "", CicloDia.clima.texto_modo()]


func _exit_tree() -> void:
	if _cartel != null:
		CicloDia.set_process(true)


func _process(delta: float) -> void:
	# En el editor no corre el ciclo del día (CicloDia no existe): se muestra un mediodía fijo.
	if Engine.is_editor_hint():
		_vista_previa()
		return
	if _cartel != null:
		_controlar_prueba(delta)
	var h := CicloDia.hora
	var clima: Clima = CicloDia.clima

	# Nubes: se ven con el cielo cubierto, son más oscuras con lluvia y el viento las empuja.
	var tono := lerpf(0.80, 0.38, clima.lluvia)
	for i in _nubes.size():
		var nube := _nubes[i]
		nube.modulate = Color(tono, tono, tono * 1.05, clampf(clima.nubes * 1.3, 0.0, 1.0))
		nube.position.x += _nubes_velocidad[i] * (1.0 + 4.0 * clima.viento) * delta
		var mitad := nube.texture.get_width() * nube.scale.x / 2.0
		if nube.position.x - mitad > _tam.x:
			nube.position.x = -mitad

	_manto.color = Color(tono, tono, tono * 1.06, clampf(clima.nubes * 0.6, 0.0, 0.6))

	# Cielo: sus capas por hora, teñidas por el clima (gris con nubes, azulado con nieve, cálido con calor).
	var tinte := clima.tinte_cielo()
	for i in _capas.size():
		_capas[i].modulate = Color(tinte.r, tinte.g, tinte.b, CicloDia.alfa_capa(i))

	# Sol: cruza el cristal de izquierda a derecha entre las 6 y las 19 h. Las nubes lo tapan; el calor lo agranda.
	var ts := (h - 6.0) / 13.0
	var sol_visible := ts > 0.0 and ts < 1.0
	if _sol != null:
		_sol.visible = sol_visible
		_sol.modulate.a = clampf(1.0 - 1.1 * clima.nubes, 0.0, 1.0)
		_sol.scale = _escala_sol * (1.0 + 0.35 * clima.calor)
		if sol_visible:
			_sol.position = _cielo.to_local(_punto_astro(CicloDia.posicion_astro(ts, 50.0)))

	# Luna: entre las 18 y las 6 h del día siguiente.
	var hl := h if h >= 18.0 else h + 24.0
	var tl := (hl - 18.0) / 12.0
	var luna_visible := tl > 0.0 and tl < 1.0
	if _luna != null:
		_luna.visible = luna_visible
		_luna.modulate.a = clampf(1.0 - clima.nubes, 0.0, 1.0)
		if luna_visible:
			_luna.position = _cielo.to_local(_punto_astro(CicloDia.posicion_astro(tl, 45.0)))

	# Manchas de luz en el suelo, con el sol y la luna de LuzNatural (si no está activa, no hay luz).
	var natural: LuzNatural = CicloDia.luz_natural if CicloDia.luz_natural_activa else null
	_tapado = lerpf(_tapado, _tapado_por_muebles(), 0.15)
	_actualizar_mancha(_luz_sol, natural, true)
	_actualizar_mancha(_luz_luna, natural, false)

	# Lo que cae o vuela por fuera: el viento los inclina.
	_actualizar_emisor(_lluvia, clima.lluvia, Vector2(0.18 + 0.5 * clima.viento, 1.0))
	_actualizar_emisor(_nieve, clima.nieve, Vector2(0.10 + 0.6 * clima.viento, 1.0))
	_actualizar_emisor(_hojas, clima.hojas, Vector2(0.35 + 0.8 * clima.viento, 1.0))
	_actualizar_emisor(_viento, clima.viento, Vector2(1.0, 0.03))
	# Destello del relámpago sobre todo el cristal.
	_destello.color.a = clima.relampago * 0.85


## Aspecto fijo para el editor: cielo de día con el sol en el cristal, sin luces ni clima.
func _vista_previa() -> void:
	for i in _capas.size():
		_capas[i].modulate = Color(1.0, 1.0, 1.0, 1.0 if i == 0 or i == 2 else 0.0)
	if _sol != null:
		_sol.visible = true
		_sol.position = Vector2(_tam.x * 0.5, _tam.y * 0.3)
	if _luna != null:
		_luna.visible = false


## Capas del cielo + sol y luna, recortados por el cristal (clip_children del nodo Cristal).
func _crear_cielo() -> void:
	for nombre in CAPAS:
		var textura := _textura_cielo(nombre)
		var capa := Sprite2D.new()
		capa.texture = textura
		# Cubre todo el cristal sin deformar la imagen; lo que sobra lo recorta el cristal.
		var e := maxf(_tam.x / textura.get_width(), _tam.y / textura.get_height())
		capa.scale = Vector2(e, e)
		capa.position = _tam / 2.0
		_cielo.add_child(capa)
		_capas.append(capa)
	_sol = _crear_astro("sol")
	_luna = _crear_astro("luna")
	if _sol != null:
		_escala_sol = _sol.scale


## Lluvia, nieve, hojas y viento (partículas) y el destello del relámpago. Van dentro del cielo: el cristal los recorta.
func _crear_clima() -> void:
	var ancho := _tam.x
	_crear_nubes()
	# Lluvia: rayas finas que caen rápido.
	_lluvia = _crear_emisor(_textura_rect(2, 12, Color(0.75, 0.86, 1.0, 0.85)), 90, 0.55, Vector2(ancho / 2.0, -16.0), Vector2(ancho / 2.0 + 40.0, 3.0), 650.0, 800.0, 3.0)
	# Nieve: copos pequeños que bajan despacio y se desvían.
	_nieve = _crear_emisor(_textura_rect(4, 4, Color(1.0, 1.0, 1.0, 0.95)), 70, 6.0, Vector2(ancho / 2.0, -10.0), Vector2(ancho / 2.0 + 30.0, 3.0), 25.0, 50.0, 30.0)
	_nieve.scale_amount_min = 0.6
	_nieve.scale_amount_max = 1.4
	# Hojas de otoño: caen girando, de varios tonos de naranja, rojo y amarillo.
	_hojas = _crear_emisor(_textura_rect(8, 5, Color(1.0, 1.0, 1.0, 1.0)), 24, 6.5, Vector2(ancho / 2.0, -10.0), Vector2(ancho / 2.0 + 30.0, 3.0), 28.0, 55.0, 25.0)
	_hojas.angular_velocity_min = -150.0
	_hojas.angular_velocity_max = 150.0
	var rampa := Gradient.new()
	rampa.set_color(0, Color(0.93, 0.55, 0.20))
	rampa.set_color(1, Color(0.72, 0.30, 0.15))
	rampa.add_point(0.5, Color(0.95, 0.78, 0.25))
	_hojas.color_initial_ramp = rampa
	# Viento: rayas horizontales que cruzan de izquierda a derecha.
	_viento = _crear_emisor(_textura_rect(18, 1, Color(1.0, 1.0, 1.0, 0.55)), 30, 0.7, Vector2(-20.0, _tam.y / 2.0), Vector2(4.0, _tam.y / 2.0), 520.0, 760.0, 4.0)
	# Destello del relámpago, encima de todo lo demás del cielo.
	_destello = ColorRect.new()
	_destello.size = _tam
	_destello.color = Color(1.0, 1.0, 1.0, 0.0)
	_destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cielo.add_child(_destello)


## Un manto gris que cubre el cielo y muchas nubes de distinto tamaño y velocidad, en dos capas que se solapan.
func _crear_nubes() -> void:
	_manto = ColorRect.new()
	_manto.size = _tam
	_manto.color = Color(0.5, 0.52, 0.58, 0.0)
	_manto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cielo.add_child(_manto)
	# [altura como fracción del cristal, posición horizontal inicial como fracción, escala, velocidad en px/s]
	var datos: Array = [
		# Capa del fondo: grandes y lentas, tapan casi todo el cielo.
		[0.05, 0.10, 2.6, 4.0], [0.12, 0.55, 2.8, 5.0], [0.22, 0.95, 2.5, 4.5], [0.32, 0.30, 3.0, 3.5],
		[0.42, 0.75, 2.7, 5.5], [0.52, 0.05, 2.9, 4.0], [0.62, 0.50, 2.6, 5.0], [0.72, 0.90, 2.8, 4.0],
		# Capa del frente: más chicas y rápidas, entre las grandes.
		[0.10, 0.35, 1.7, 9.0], [0.20, 0.80, 1.5, 12.0], [0.30, 0.00, 1.8, 8.0], [0.40, 0.60, 1.4, 14.0],
		[0.50, 0.25, 1.7, 10.0], [0.58, 0.85, 1.5, 13.0], [0.68, 0.40, 1.6, 9.0], [0.80, 0.15, 1.8, 7.0],
	]
	for i in datos.size():
		var d: Array = datos[i]
		var nube := Sprite2D.new()
		nube.texture = _textura_nube(104, 44, 11 + i * 7)
		nube.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		nube.scale = Vector2(float(d[2]), float(d[2]))
		nube.position = Vector2(_tam.x * float(d[1]), _tam.y * float(d[0]))
		nube.modulate.a = 0.0
		_cielo.add_child(nube)
		_nubes.append(nube)
		_nubes_velocidad.append(float(d[3]))


## Una nube de píxeles: varios círculos juntos con la base plana, clara arriba y más oscura abajo.
func _textura_nube(ancho: int, alto: int, semilla: int) -> Texture2D:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var circulos: Array = []
	for i in 7:
		circulos.append([azar.randf_range(0.2, 0.8) * ancho, azar.randf_range(0.42, 0.68) * alto, azar.randf_range(0.2, 0.34) * alto * 1.5])
	var imagen := Image.create_empty(ancho, alto, false, Image.FORMAT_RGBA8)
	for y in alto:
		if float(y) > alto * 0.86:
			continue   # base plana
		for x in ancho:
			for c in circulos:
				var dx: float = x - float(c[0])
				var dy: float = y - float(c[1])
				if dx * dx + dy * dy <= float(c[2]) * float(c[2]):
					var t := float(y) / float(alto)
					var g := lerpf(1.0, 0.70, t)
					imagen.set_pixel(x, y, Color(g, g, g * 1.03, 1.0))
					break
	return ImageTexture.create_from_image(imagen)


func _crear_emisor(textura: Texture2D, cantidad: int, vida: float, pos: Vector2, extension: Vector2, v_min: float, v_max: float, dispersion: float) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.texture = textura
	e.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	e.amount = cantidad
	e.lifetime = vida
	e.preprocess = vida   # ya viene "lleno" al empezar, sin esperar a que caiga la primera tanda
	e.local_coords = true
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.emission_rect_extents = extension
	e.position = pos
	e.direction = Vector2(0.0, 1.0)
	e.spread = dispersion
	e.gravity = Vector2.ZERO
	e.initial_velocity_min = v_min
	e.initial_velocity_max = v_max
	e.emitting = false
	_cielo.add_child(e)
	return e


## Un rectángulo liso de un color, para las partículas.
func _textura_rect(ancho: int, alto: int, color: Color) -> Texture2D:
	var imagen := Image.create_empty(ancho, alto, false, Image.FORMAT_RGBA8)
	imagen.fill(color)
	return ImageTexture.create_from_image(imagen)


## Enciende o apaga un emisor según cuánto vale su clima, con aparición suave, y lo inclina con el viento.
func _actualizar_emisor(emisor: CPUParticles2D, valor: float, direccion: Vector2) -> void:
	emisor.emitting = valor > 0.03
	emisor.modulate.a = clampf(valor, 0.0, 1.0)
	emisor.direction = direccion


## Usa la imagen del cielo si existe; si no, un degradado provisional.
func _textura_cielo(nombre: String) -> Texture2D:
	var ruta := CARPETA_CIELOS + "cielo_" + nombre + ".png"
	if ResourceLoader.exists(ruta):
		return load(ruta) as Texture2D
	var colores: Array = COLORES_RESERVA[nombre]
	var degradado := Gradient.new()
	degradado.set_color(0, colores[0])
	degradado.set_color(1, colores[1])
	var t := GradientTexture2D.new()
	t.gradient = degradado
	t.width = 8
	t.height = 64
	t.fill_from = Vector2(0.0, 0.0)
	t.fill_to = Vector2(0.0, 1.0)
	return t


## Sol o luna con arte; si todavía no existe la imagen, no se dibuja.
func _crear_astro(nombre: String) -> Sprite2D:
	var ruta := CARPETA_CIELOS + nombre + ".png"
	if not ResourceLoader.exists(ruta):
		return null
	var astro := Sprite2D.new()
	astro.texture = load(ruta) as Texture2D
	# El cuerpo de la ventana está escalado, así que se compensa para que el astro mida lo mismo en todas.
	var e := (TAMANO_ASTRO / _esc) / astro.texture.get_width()
	astro.scale = Vector2(e, e)
	_cielo.add_child(astro)
	return astro
