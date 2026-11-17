class_name Partida
extends RefCounted
## Archivo de guardado (user://partida.json), compartido por todas las habitaciones.
## Como la casa recarga su escena al cambiar de habitación, el archivo es la única fuente de verdad: cada habitación
## guarda lo suyo dentro de "habitaciones" y deja intacto lo de las demás.
##
## Formato:
## {
##   "version": 2,
##   "inventario": [rutas de fichas],
##   "economia": {...}, "musica": {...},
##   "habitacion_actual": "sala",
##   "desbloqueadas": ["sala", ...],
##   "habitaciones": {"sala": {"muebles": [...], "luz": true, "reproductor": false}, ...}
## }

const RUTA: String = "user://partida.json"
const VERSION: int = 2


## Lee la partida. Devuelve {} si no hay archivo. Si es del formato viejo (una sola lista "muebles"), todo pasa a la sala.
static func leer() -> Dictionary:
	if not FileAccess.file_exists(RUTA):
		return {}
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA))
	if typeof(datos) != TYPE_DICTIONARY:
		return {}
	var partida: Dictionary = datos
	if not partida.has("habitaciones"):
		partida["habitaciones"] = {Habitaciones.ID_INICIAL: {"muebles": partida.get("muebles", [])}}
		partida.erase("muebles")
	return partida


## Escribe la partida. Devuelve false (y avisa) si no se pudo.
static func escribir(datos: Dictionary) -> bool:
	datos["version"] = VERSION
	var archivo := FileAccess.open(RUTA, FileAccess.WRITE)
	if archivo == null:
		push_warning("No se pudo guardar la partida: %s" % error_string(FileAccess.get_open_error()))
		return false
	archivo.store_string(JSON.stringify(datos))
	return true


## Guarda solo lo que cambia fuera de la casa (monedas y mate), sin tocar las habitaciones. Lo usa el minijuego de bichitos.
static func guardar_progreso() -> void:
	var datos := leer()
	datos["economia"] = Economia.a_datos()
	datos["mate"] = Mate.a_datos()
	datos["misiones"] = Misiones.a_datos()
	datos["ropero"] = Ropero.a_datos()
	escribir(datos)
