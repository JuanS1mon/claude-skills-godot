class_name BichitoData
extends Resource
## Ficha de un bichito de luz del minijuego de la noche. Atraparlo da Destellos (la moneda común) y, a veces, un ingrediente
## para el mate. Las fichas viven en data/bichitos/*.tres; ver docs/universo-y-lore.md. El minijuego en sí todavía no existe.

@export var nombre: String = ""
## Color con que brilla.
@export var color: Color = Color(1.0, 0.95, 0.5)
## Animación de aleteo (SpriteFrames con la animación "default"). Sin ella se ve la figura de color.
@export var frames: SpriteFrames
## Destellos que da al atraparlo.
@export var destellos: int = 1
## Qué tan frecuente es: al elegir un bichito al azar, cada ficha pesa lo que dice `peso` (los raros, poco).
@export var peso: float = 10.0
## Segundos que brilla antes de apagarse y volar alto (menos = más difícil).
@export var segundos_visible: float = 4.0
## Ingrediente que puede dejar (opcional) y con qué probabilidad (0 a 1).
@export var ingrediente: BlendData
@export_range(0.0, 1.0, 0.01) var probabilidad_ingrediente: float = 0.0


func id() -> String:
	return resource_path.get_file().get_basename()


## Elige una ficha de la lista según su peso.
static func elegir(lista: Array[BichitoData]) -> BichitoData:
	var total := 0.0
	for b in lista:
		total += b.peso
	var tirada := randf() * total
	for b in lista:
		tirada -= b.peso
		if tirada <= 0.0:
			return b
	return lista.back() if not lista.is_empty() else null
