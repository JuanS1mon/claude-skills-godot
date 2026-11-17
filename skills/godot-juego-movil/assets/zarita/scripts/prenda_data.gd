class_name PrendaData
extends Resource
## Ficha de una prenda de ropa para Zarita (un ponchito, una bufanda tejida...), igual que MuebleData: una escena (scenes/prenda.tscn
## o una variante de scenes/prendas/) más los datos que la distinguen. Se compra en la pestaña Ropa de la tienda con Destellos y se
## pone o se saca. Añadir ropa nueva es crear su .tres en data/prendas/ (el nombre del archivo es su id); con `textura` o `frames`
## se ve la imagen y, mientras no haya, las formas de color de la escena. Con crear_prenda() se obtiene la prenda para ponerla.

@export var nombre: String = ""
@export var escena: PackedScene
## Una sola imagen de la prenda (de frente, con los pies de Zarita como origen) ...
@export var textura: Texture2D
## ... o una animación "default" de varios cuadros (tiene prioridad sobre `textura`).
@export var frames: SpriteFrames
## Imagen para la tienda y el menú (si falta, una muestra del color).
@export var icono: Texture2D
@export var color: Color = Color(0.9, 0.4, 0.45)
## Color de los flecos y el borde.
@export var color_borde: Color = Color(0.99, 0.93, 0.8)
## Dónde queda respecto de los pies de Zarita (píxeles) y qué tan grande se dibuja.
@export var posicion: Vector2 = Vector2.ZERO
@export var escala: float = 1.0
## Precio en Destellos (moneda común).
@export var precio: int = 100


func id() -> String:
	return resource_path.get_file().get_basename()


## La animación de la prenda: `frames`, o un solo cuadro con `textura`. null si no hay arte.
func frames_prenda() -> SpriteFrames:
	if frames != null:
		return frames
	if textura == null:
		return null
	var f := SpriteFrames.new()
	f.add_frame(&"default", textura)
	return f


## La prenda lista para ponerla como hija de Zarita.
func crear_prenda() -> Node2D:
	var prenda := escena.instantiate() as Node2D
	prenda.set("ficha", self)
	return prenda
