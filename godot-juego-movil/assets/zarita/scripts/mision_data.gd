class_name MisionData
extends Resource
## Ficha de una misión (las que propone Teo, y más adelante Don Jacinto). Solo datos: cuando haya un sistema de misiones, leerá
## de aquí. Las fichas viven en data/misiones/*.tres; ver docs/universo-y-lore.md.

enum Tipo { ATRAPAR_BICHITOS, BUSCAR_OBJETO, EXPLORAR, DECORAR }

@export var titulo: String = ""
## Lo que dice el personaje al proponerla.
@export_multiline var texto: String = ""
@export var personaje: PersonajeData
@export var tipo: Tipo = Tipo.BUSCAR_OBJETO
## Cuántos hay que atrapar, encontrar o colocar.
@export var cantidad: int = 1
## Para las de EXPLORAR: id de la habitación (data/habitaciones/) que hay que visitar.
@export var habitacion_destino: String = ""
@export var recompensa_destellos: int = 0
@export var recompensa_gemas: int = 0
## Mueble exclusivo que se entrega al terminarla (opcional).
@export var recompensa_ficha: MuebleData


func id() -> String:
	return resource_path.get_file().get_basename()
