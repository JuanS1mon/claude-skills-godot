class_name HabitacionData
extends Resource
## Ficha de una habitación de la casa: su suelo, dónde aparece Zarita y cuánto cuesta desbloquearla.
## No es un nodo: la casa (casa.tscn) es una sola escena y se reconfigura con la ficha de la habitación en que estás.
## Las fichas viven en data/habitaciones/*.tres; el nombre del archivo es el identificador al guardar.
## Para una habitación nueva basta con crear su ficha: el mapa y el guardado la leen solos.

@export var nombre: String = ""
## Suelo (con la franja de pared de arriba): todos tienen el mismo marco, 720x1280.
@export var suelo: Texture2D
## Se multiplica por el suelo; sirve para diferenciar habitaciones mientras no hay arte propio.
@export var tinte_suelo: Color = Color.WHITE
## Color de la tarjeta en el mapa de la casa.
@export var color_mapa: Color = Color(0.85, 0.72, 0.60)
## Imagen de la tarjeta en el mapa (opcional; sin imagen se ve solo el color).
@export var icono: Texture2D
## Posición en el mapa y en las listas (menor = primero). La que tenga precio 0 y menor orden es la inicial.
@export var orden: int = 0
## Gemas que cuesta desbloquearla. 0 = viene desbloqueada.
@export var precio_gemas: int = 0
## Dónde aparece Zarita si llega a la habitación (se viaja desde el mapa).
@export var inicio_zarita: Vector2 = Vector2(360.0, 640.0)


## Identificador estable: el nombre del archivo ("cocina" para data/habitaciones/cocina.tres).
func id() -> String:
	return resource_path.get_file().get_basename()
