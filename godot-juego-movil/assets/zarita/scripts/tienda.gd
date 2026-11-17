class_name Tienda
extends Control
## Tienda: lista los muebles del catálogo, los cobra con Economia y los manda al Inventario.

const GEMAS_POR_ANUNCIO: int = 3
## Todas las fichas (.tres) de esta carpeta forman el catálogo de la tienda.
const CARPETA_CATALOGO: String = "res://data/muebles/"
## Textos de las pestañas, en el mismo orden que MuebleData.Categoria.
const NOMBRES_CATEGORIAS: Array[String] = ["Sala", "Dormitorio", "Decoración", "Baño", "Cocina"]

## Se emite cuando el panel se cierra con su propio botón.
signal cerrada

@export var escena_item: PackedScene

var catalogo: Array[MuebleData] = []

@onready var _panel: PanelContainer = $Panel
@onready var _pestanas: HBoxContainer = $Panel/Caja/Pestanas
@onready var _scroll: ScrollContainer = $Panel/Caja/Scroll
@onready var _lista: VBoxContainer = $Panel/Caja/Scroll/Lista
@onready var _aviso: Label = $Panel/Caja/Aviso
@onready var _boton_anuncio: Button = $Panel/Caja/BotonAnuncio
@onready var _boton_cerrar: Button = $Panel/Caja/BotonCerrar


func _ready() -> void:
	_cargar_catalogo()
	for ficha in catalogo:
		var item := escena_item.instantiate() as ItemTienda
		_lista.add_child(item)
		item.configurar(ficha)
		item.comprar.connect(_comprar)
	_crear_filas_ropa()
	_crear_pestanas()
	_mostrar_categoria(MuebleData.Categoria.SALA)
	_panel.visible = false   # en el editor se ve abierto para poder diseñarlo
	_boton_cerrar.pressed.connect(_cerrar)
	_boton_anuncio.pressed.connect(_ver_anuncio)


## Lee todas las fichas de la carpeta y las ordena: primero las de monedas, de baratas a caras.
func _cargar_catalogo() -> void:
	for archivo in ResourceLoader.list_directory(CARPETA_CATALOGO):
		if archivo.ends_with("/"):
			continue
		var ficha := load(CARPETA_CATALOGO + archivo) as MuebleData
		if ficha != null:
			catalogo.append(ficha)
	catalogo.sort_custom(func(a: MuebleData, b: MuebleData) -> bool:
		if a.moneda != b.moneda:
			return a.moneda < b.moneda
		if a.precio != b.precio:
			return a.precio < b.precio
		return a.nombre < b.nombre)


## Un botón por categoría (grandes, para el dedo). Solo uno queda marcado a la vez.
func _crear_pestanas() -> void:
	var grupo := ButtonGroup.new()
	for i in NOMBRES_CATEGORIAS.size():
		var boton := Button.new()
		boton.text = NOMBRES_CATEGORIAS[i]
		boton.theme_type_variation = &"Pestana"
		boton.toggle_mode = true
		boton.button_group = grupo
		boton.button_pressed = i == 0
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.custom_minimum_size = Vector2(0, 56)
		boton.pressed.connect(_mostrar_categoria.bind(i))
		_pestanas.add_child(boton)
	# Una pestaña más, después de las de muebles: la ropa de Zarita (se paga con Destellos).
	var ropa := Button.new()
	ropa.text = "Ropa"
	ropa.theme_type_variation = &"Pestana"
	ropa.toggle_mode = true
	ropa.button_group = grupo
	ropa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ropa.custom_minimum_size = Vector2(0, 56)
	ropa.pressed.connect(_mostrar_categoria.bind(NOMBRES_CATEGORIAS.size()))
	_pestanas.add_child(ropa)


## Muestra solo los muebles de la categoría elegida (o la ropa, que es la categoría que sigue a las de muebles).
func _mostrar_categoria(categoria: int) -> void:
	for hijo in _lista.get_children():
		var item := hijo as ItemTienda
		if item != null:
			item.visible = item.ficha.categoria == categoria
		else:
			hijo.visible = categoria == NOMBRES_CATEGORIAS.size()
	_scroll.scroll_vertical = 0


## Una fila por prenda del Ropero.catalogo(): muestra de color, nombre y precio, y un botón que compra, pone o saca.
func _crear_filas_ropa() -> void:
	for prenda in Ropero.catalogo():
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 12)
		var muestra := ColorRect.new()
		muestra.custom_minimum_size = Vector2(56, 56)
		muestra.color = prenda.color
		fila.add_child(muestra)
		var nombre := Label.new()
		nombre.text = "%s\n%d monedas" % [prenda.nombre, prenda.precio]
		nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(nombre)
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(150, 56)
		boton.focus_mode = Control.FOCUS_NONE
		boton.pressed.connect(_accion_ropa.bind(prenda))
		fila.add_child(boton)
		fila.set_meta("prenda", prenda)
		fila.set_meta("boton", boton)
		_lista.add_child(fila)
		fila.visible = false
	_actualizar_botones_ropa()


func _actualizar_botones_ropa() -> void:
	for hijo in _lista.get_children():
		if hijo.has_meta("prenda"):
			var prenda := hijo.get_meta("prenda") as PrendaData
			var boton := hijo.get_meta("boton") as Button
			if not Ropero.tiene(prenda):
				boton.text = "Comprar"
			else:
				boton.text = "Sacar" if Ropero.puesta == prenda.id() else "Ponerse"


## Comprar, ponerse o sacarse una prenda. Zarita la lleva puesta enseguida.
func _accion_ropa(prenda: PrendaData) -> void:
	if not Ropero.tiene(prenda):
		if not Ropero.comprar(prenda):
			_aviso.text = "No te alcanza para: %s" % prenda.nombre
			return
		_aviso.text = "Compraste: %s" % prenda.nombre
		Ropero.poner(prenda)
	elif Ropero.puesta == prenda.id():
		Ropero.quitar()
	else:
		Ropero.poner(prenda)
	get_tree().call_group("ropa_zarita", "refrescar")
	_actualizar_botones_ropa()


## Abre o cierra el panel (lo llama la casa cuando se toca el botón Tienda del HUD).
func mostrar(activa: bool) -> void:
	_panel.visible = activa


## El botón Cerrar del panel: se esconde y avisa para que el botón del HUD se suelte.
func _cerrar() -> void:
	_panel.visible = false
	cerrada.emit()


func _comprar(ficha: MuebleData) -> void:
	if Economia.pagar(ficha.precio, ficha.moneda):
		Inventario.agregar(ficha)
		_aviso.text = "Compraste: %s" % ficha.nombre
	else:
		_aviso.text = "No te alcanza para: %s" % ficha.nombre


## Pide un anuncio al autoload Anuncios (hoy simulado) y da las gemas solo si se completó.
func _ver_anuncio() -> void:
	if not Anuncios.disponible():
		return
	_boton_anuncio.disabled = true
	_aviso.text = "Mirando anuncio..."
	var obtenida: bool = await Anuncios.mostrar_recompensa()
	if obtenida:
		Economia.ganar(GEMAS_POR_ANUNCIO, MuebleData.Moneda.GEMAS)
		_aviso.text = "¡Ganaste %d gemas!" % GEMAS_POR_ANUNCIO
	else:
		_aviso.text = "No se completó el anuncio."
	_boton_anuncio.disabled = false
