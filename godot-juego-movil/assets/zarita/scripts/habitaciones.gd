class_name Habitaciones
extends RefCounted
## Las habitaciones de la casa: catálogo (data/habitaciones/*.tres), cuál es la actual y cuáles están desbloqueadas.
## Es una clase con datos estáticos, no un autoload: el estado sobrevive al recargar la escena de la casa y no hace
## falta tocar project.godot. Lo que hay que recordar entre partidas se guarda con Partida.

const CARPETA: String = "res://data/habitaciones/"
const ID_INICIAL: String = "sala"

## Habitación en la que está Zarita ("" = todavía no se leyó la partida; se usa la inicial).
static var actual: String = ""
static var desbloqueadas: Array[String] = [ID_INICIAL]
## {id de habitación: true si tiene un reproductor de música}. La música suena en toda la casa si hay uno en cualquiera.
static var con_reproductor: Dictionary = {}

static var _catalogo: Array[HabitacionData] = []


## Todas las fichas, ordenadas por `orden`.
static func catalogo() -> Array[HabitacionData]:
	if _catalogo.is_empty():
		for archivo in ResourceLoader.list_directory(CARPETA):
			if archivo.ends_with("/"):
				continue
			var ficha := load(CARPETA + archivo) as HabitacionData
			if ficha != null:
				_catalogo.append(ficha)
		_catalogo.sort_custom(func(a: HabitacionData, b: HabitacionData) -> bool: return a.orden < b.orden)
	return _catalogo


## La ficha de una habitación, o null si ya no existe.
static func ficha(id: String) -> HabitacionData:
	for hab in catalogo():
		if hab.id() == id:
			return hab
	return null


static func esta_desbloqueada(id: String) -> bool:
	return desbloqueadas.has(id)


## Paga con gemas y desbloquea. Devuelve false sin tocar nada si no alcanzan (o si no existe o ya estaba abierta).
static func desbloquear(id: String) -> bool:
	var hab := ficha(id)
	if hab == null or esta_desbloqueada(id):
		return false
	if not Economia.pagar(hab.precio_gemas, MuebleData.Moneda.GEMAS):
		return false
	desbloqueadas.append(id)
	return true


## Confort de una habitación: la suma del `confort` de las fichas de sus muebles, según la partida guardada.
static func confort_de(id: String, partida: Dictionary) -> int:
	var guardadas: Dictionary = partida.get("habitaciones", {})
	var total := 0
	for entrada in (guardadas.get(id, {}) as Dictionary).get("muebles", []):
		var ruta: String = entrada.get("ficha", "")
		if ResourceLoader.exists(ruta):
			var ficha := load(ruta) as MuebleData
			if ficha != null:
				total += ficha.confort
	return total


## ¿Hay un reproductor de música en alguna habitación distinta de `excepto`?
static func hay_reproductor_fuera_de(excepto: String) -> bool:
	for id in con_reproductor:
		if id != excepto and con_reproductor[id]:
			return true
	return false


## Lee de la partida guardada cuál es la habitación actual, cuáles están abiertas y dónde hay reproductores.
static func cargar_datos(partida: Dictionary) -> void:
	desbloqueadas.clear()
	desbloqueadas.append(ID_INICIAL)
	for id in partida.get("desbloqueadas", []):
		if not desbloqueadas.has(id) and ficha(id) != null:
			desbloqueadas.append(id)
	# Lo que no cuesta nada viene abierto.
	for hab in catalogo():
		if hab.precio_gemas <= 0 and not desbloqueadas.has(hab.id()):
			desbloqueadas.append(hab.id())
	con_reproductor.clear()
	var guardadas: Dictionary = partida.get("habitaciones", {})
	for id in guardadas:
		con_reproductor[id] = bool((guardadas[id] as Dictionary).get("reproductor", false))
	if actual == "" or ficha(actual) == null or not esta_desbloqueada(actual):
		var guardada: String = partida.get("habitacion_actual", ID_INICIAL)
		actual = guardada if ficha(guardada) != null and esta_desbloqueada(guardada) else ID_INICIAL
