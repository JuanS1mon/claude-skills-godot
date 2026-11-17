class_name MuebleData
extends Resource
## Ficha de un tipo de mueble: lo que el jugador posee y lo que se vende en la tienda.
## No es un nodo; con crear_mueble() se obtiene un mueble real para poner en la casa.

## Qué fracción del precio se recupera al vender un mueble.
const PORCENTAJE_VENTA: float = 0.5

enum Moneda { COMUN, GEMAS }
## El orden de esta lista es el de las pestañas de la tienda.
enum Categoria { SALA, DORMITORIO, DECORACION, BANO, COCINA }

@export var nombre: String = ""
@export var escena: PackedScene
@export var textura: Texture2D
## Imagen para la tienda y el inventario cuando el mueble no se dibuja con `textura` (p. ej. las ventanas).
@export var icono: Texture2D
@export var color: Color = Color.WHITE
## Vector2.ZERO significa "usar el tamaño de la escena".
@export var tamano: Vector2 = Vector2.ZERO
## Luz que emite de noche (lámparas).
@export var emite_luz: bool = false
@export var luz_color: Color = Color(1.0, 0.85, 0.55)
@export var luz_radio: float = 180.0
## Altura de la luz sobre la base, como fracción del alto del mueble.
@export var luz_altura: float = 0.85
## Zona del suelo que ocupa (para que Zarita no la pise). Vector2.ZERO = automática.
@export var huella: Vector2 = Vector2.ZERO
## false para lo que se puede pisar o no ocupa suelo (alfombras, ventanas).
@export var bloquea: bool = true
## Para objetos planos (alfombras): se dibujan siempre debajo de Zarita y de los demás muebles.
@export var en_el_suelo: bool = false
## Mueble de los que van pegados a la pared (cocinas, heladeras, mesadas): sin sombra, porque en la pared parecería flotar.
@export var contra_pared: bool = false
## Para las ventanas: solo se pueden colocar sobre la pared de arriba.
@export var solo_en_pared: bool = false
## Para mesas, cómodas y otros muebles con una cara de arriba donde se pueden poner cosas: la zona donde puede quedar
## la BASE del objeto apoyado, en píxeles desde el origen del mueble (su base; hacia arriba es Y negativa).
## Rect2() vacío = no es una superficie.
@export var superficie: Rect2 = Rect2()
## Para objetos pequeños (radios, cajas musicales, plantas): se pueden dejar encima de un mueble con `superficie`.
@export var apoyable: bool = false
## Para escenas con varios aspectos (las ventanas: 0 rosa, 1 arco, 2 azul).
@export var variante: int = 0
## Cuánto confort da a la casa (la decoración sirve para algo: ver docs/universo-y-lore.md). Todavía no se suma en ningún lado.
@export var confort: int = 0
@export var precio: int = 0
@export var moneda: Moneda = Moneda.COMUN
@export var categoria: Categoria = Categoria.SALA


## Cuánto dan por venderlo (en la misma moneda): la mitad del precio, y al menos 1 si el mueble costó algo.
func precio_venta() -> int:
	if precio <= 0:
		return 0
	return maxi(1, int(precio * PORCENTAJE_VENTA))


## Imagen que representa a la ficha en la tienda y el inventario.
func imagen() -> Texture2D:
	return icono if icono != null else textura


func crear_mueble() -> Mueble:
	var mueble := escena.instantiate() as Mueble
	mueble.ficha = self
	if textura:
		mueble.textura = textura
	mueble.color = color
	if tamano != Vector2.ZERO:
		mueble.tamano = tamano
	mueble.huella = huella
	mueble.bloquea = bloquea
	mueble.solo_en_pared = solo_en_pared
	mueble.contra_pared = contra_pared
	mueble.superficie = superficie
	mueble.apoyable = apoyable
	mueble.emite_luz = emite_luz
	mueble.luz_color = luz_color
	mueble.luz_radio = luz_radio
	mueble.luz_altura = luz_altura
	if en_el_suelo:
		mueble.z_index = -5
		mueble.bloquea = false
	return mueble
