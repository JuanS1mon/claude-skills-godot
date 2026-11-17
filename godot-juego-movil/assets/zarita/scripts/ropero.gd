class_name Ropero
extends RefCounted
## La ropa de Zarita: cuáles prendas tiene (se compran en la tienda con Destellos) y cuál lleva puesta. Clase con datos
## estáticos que se guardan en la partida, como Mate y Misiones. RopaZarita la dibuja.

const CARPETA: String = "res://data/prendas/"

static var poseidas: Array[String] = []
## Id de la prenda puesta ("" = ninguna).
static var puesta: String = ""

static var _catalogo: Array[PrendaData] = []


static func catalogo() -> Array[PrendaData]:
	if _catalogo.is_empty():
		var archivos := ResourceLoader.list_directory(CARPETA)
		archivos.sort()
		for archivo in archivos:
			if archivo.ends_with("/"):
				continue
			var prenda := load(CARPETA + archivo) as PrendaData
			if prenda != null:
				_catalogo.append(prenda)
	return _catalogo


static func tiene(prenda: PrendaData) -> bool:
	return poseidas.has(prenda.id())


## Paga con Destellos y la guarda en el ropero. false (sin tocar nada) si no alcanza o ya la tenía.
static func comprar(prenda: PrendaData) -> bool:
	if tiene(prenda) or not Economia.pagar(prenda.precio, MuebleData.Moneda.COMUN):
		return false
	poseidas.append(prenda.id())
	return true


static func poner(prenda: PrendaData) -> void:
	if tiene(prenda):
		puesta = prenda.id()


static func quitar() -> void:
	puesta = ""


## La ficha de la prenda puesta, o null.
static func prenda_puesta() -> PrendaData:
	for prenda in catalogo():
		if prenda.id() == puesta:
			return prenda
	return null


static func a_datos() -> Dictionary:
	return {"poseidas": poseidas, "puesta": puesta}


static func cargar_datos(datos: Dictionary) -> void:
	poseidas.clear()
	for id in datos.get("poseidas", []):
		poseidas.append(str(id))
	puesta = str(datos.get("puesta", ""))
	if not poseidas.has(puesta):
		puesta = ""
