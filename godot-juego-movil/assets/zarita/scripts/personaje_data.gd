class_name PersonajeData
extends Resource
## Ficha de un personaje del mundo de Zarita (ella, Don Jacinto, Teo...). Es solo datos: cuando haya diálogos, misiones
## o visitas, las escenas leerán de aquí. Las fichas viven en data/personajes/*.tres; ver docs/universo-y-lore.md.

@export var nombre: String = ""
@export var especie: String = ""
## Qué hace en el juego (en una frase).
@export var rol: String = ""
@export_multiline var personalidad: String = ""
## Dónde vive o se lo encuentra: id de una habitación (data/habitaciones/) o "exterior".
@export var vive_en: String = ""
## Imagen para diálogos y para el mapa (opcional hasta que haya arte).
@export var retrato: Texture2D


## Identificador estable: el nombre del archivo ("don_jacinto" para data/personajes/don_jacinto.tres).
func id() -> String:
	return resource_path.get_file().get_basename()
