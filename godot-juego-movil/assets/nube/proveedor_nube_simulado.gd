extends "res://scripts/nube/proveedor_nube.gd"
## Una "nube falsa" para probar todo en la PC: guarda en `user://nube_simulada.json` en vez de ir a Internet.
## Se activa poniendo `SIMULAR_NUBE = true` en `nube.gd` (o creándolo a mano en una prueba).
## Para simular "otro celular" basta con escribir en ese archivo (o llamar a `subir()` desde una prueba).

const RUTA := "user://nube_simulada.json"

## Segundos que tarda cada pedido (como una red lenta).
var latencia: float = 0.1
## Poner true para probar qué pasa sin red: todo da error.
var sin_red: bool = false


func disponible() -> bool:
	return true


func descargar() -> Dictionary:
	await _esperar()
	if sin_red:
		return {"estado": "error", "error": "sin red (simulado)"}
	if not FileAccess.file_exists(RUTA):
		return {"estado": "vacio"}
	var caja = JSON.parse_string(FileAccess.get_file_as_string(RUTA))
	if not (caja is Dictionary) or not caja.has("texto"):
		return {"estado": "error", "error": "archivo de nube dañado"}
	return {"estado": "ok", "texto": String(caja.texto)}


func subir(texto: String, info: Dictionary) -> bool:
	await _esperar()
	if sin_red:
		return false
	var f := FileAccess.open(RUTA, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"texto": texto, "info": info}))
	f.close()   # cerrarlo antes de responder: quien espera puede leerlo en el acto
	return true


## Borra la nube falsa (para las pruebas).
func vaciar() -> void:
	if FileAccess.file_exists(RUTA):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))


func _esperar() -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(latencia).timeout
