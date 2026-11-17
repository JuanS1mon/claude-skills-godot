extends RefCounted
## Contrato de un proveedor de nube: lo único que `Nube` sabe pedirle a "donde se guarda en la nube".
## Esta versión base es la "sin nube" (PC, o celular sin sesión de Play Games): `disponible()` es false y el juego
## sigue guardando solo en el dispositivo, como siempre.
##
## Para conectar un servicio real (Play Games "Saved Games") se hace UNA clase nueva que herede de esta y cambie
## estas tres funciones; el resto del juego no se entera. Las funciones de red son corrutinas (se esperan con `await`).


## ¿Hay nube a la que hablarle ahora? (plugin instalado, sesión iniciada...). Si es false, `Nube` no hace nada.
func disponible() -> bool:
	return false


## Baja la partida guardada en la nube. Devuelve un diccionario:
##   {"estado": "ok",    "texto": <el JSON de la partida>}   hay partida en la nube
##   {"estado": "vacio"}                                      la nube está vacía (primera vez)
##   {"estado": "error", "error": "<qué pasó>"}              sin red, sin sesión, etc.
func descargar() -> Dictionary:
	await Engine.get_main_loop().process_frame
	return {"estado": "error", "error": "sin nube"}


## Sube la partida (`texto`: el JSON completo). `info` trae datos para mostrar en la lista de partidas guardadas:
##   {"descripcion": "Ola 42 · 5 tripulantes", "ola": 42, "tiempo": <segundos unix>}
## Devuelve true si salió bien. Saved Games admite hasta 3 MB por archivo (la partida pesa unos pocos KB).
func subir(_texto: String, _info: Dictionary) -> bool:
	await Engine.get_main_loop().process_frame
	return false
