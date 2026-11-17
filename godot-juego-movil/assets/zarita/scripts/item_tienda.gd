class_name ItemTienda
extends HBoxContainer
## Una fila de la tienda: imagen o color, nombre, precio y botón de comprar.

signal comprar(ficha: MuebleData)

var ficha: MuebleData


func _ready() -> void:
	$Nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # un nombre largo baja de línea en vez de ensanchar la fila
	$BotonComprar.pressed.connect(_al_comprar)
	Economia.cambio.connect(_actualizar_boton)


func configurar(nueva: MuebleData) -> void:
	ficha = nueva
	$Nombre.text = ficha.nombre
	var unidad := "gemas" if ficha.moneda == MuebleData.Moneda.GEMAS else "monedas"
	$Precio.text = "%d %s" % [ficha.precio, unidad]
	var tiene_imagen := ficha.imagen() != null
	$Imagen.visible = tiene_imagen
	$Muestra.visible = not tiene_imagen
	$Imagen.texture = ficha.imagen()
	$Muestra.color = ficha.color
	_actualizar_boton()


## El botón se desactiva si el jugador no puede pagar el mueble.
func _actualizar_boton() -> void:
	if ficha == null:
		return
	$BotonComprar.disabled = not Economia.puede_pagar(ficha.precio, ficha.moneda)


func _al_comprar() -> void:
	comprar.emit(ficha)
