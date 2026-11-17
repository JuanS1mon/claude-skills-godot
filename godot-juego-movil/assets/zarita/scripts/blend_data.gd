class_name BlendData
extends Resource
## Ficha de un yuyo o mezcla para el mate (peperina, cáscara de naranja...). Los regala o vende Don Jacinto y algunos bichitos raros
## dan ingredientes. Las fichas viven en data/blends/*.tres; ver docs/universo-y-lore.md.

@export var nombre: String = ""
@export_multiline var descripcion: String = ""
## Cuánta energía da una mateada con esta mezcla (la yerba sola da `Mate.ENERGIA_POR_MATEADA`).
@export var energia_extra: int = 0
## Color de la mezcla (para el icono mientras no haya arte).
@export var color: Color = Color(0.45, 0.6, 0.25)
## Precio en Destellos (moneda común) si se vende; 0 = solo se consigue de regalo.
@export var precio: int = 0


func id() -> String:
	return resource_path.get_file().get_basename()
