class_name Misiones
extends RefCounted
## Misiones de los amigos de Zarita (fichas MisionData en data/misiones/). Una a la vez: se acepta hablando con el
## personaje (ver Conversaciones), avanza sola con lo que haces (atrapar bichitos, decorar, visitar una habitación) y se
## reclama hablando de nuevo. Es una clase con datos estáticos que se guardan en la partida, como Mate y Habitaciones.

const CARPETA: String = "res://data/misiones/"

## La misión que se está haciendo (null = ninguna) y cuánto lleva.
static var activa: MisionData
static var progreso: int = 0
## Ids (nombre del archivo) de las que ya se cumplieron.
static var completadas: Array[String] = []

static var _catalogo: Array[MisionData] = []


## Todas las fichas, en orden alfabético de archivo.
static func catalogo() -> Array[MisionData]:
	if _catalogo.is_empty():
		var archivos := ResourceLoader.list_directory(CARPETA)
		archivos.sort()
		for archivo in archivos:
			if archivo.ends_with("/"):
				continue
			var ficha := load(CARPETA + archivo) as MisionData
			if ficha != null:
				_catalogo.append(ficha)
	return _catalogo


## La primera misión de ese personaje que todavía no se cumplió (null si ya no tiene más).
static func siguiente_de(id_personaje: String) -> MisionData:
	for m in catalogo():
		if m.personaje != null and m.personaje.id() == id_personaje and not completadas.has(m.id()):
			return m
	return null


static func aceptar(mision: MisionData) -> void:
	activa = mision
	progreso = 0


## Algo pasó en el juego (se atrapó un bichito, se colocó un mueble...): suma si la misión activa es de ese tipo.
static func registrar(tipo: MisionData.Tipo, cantidad: int = 1) -> void:
	if activa != null and activa.tipo == tipo:
		progreso = mini(progreso + cantidad, activa.cantidad)


## Zarita entró a una habitación: cuenta para las misiones de explorar que piden esa.
static func registrar_visita(id_habitacion: String) -> void:
	if activa != null and activa.tipo == MisionData.Tipo.EXPLORAR and activa.habitacion_destino == id_habitacion:
		progreso = activa.cantidad


static func esta_completa() -> bool:
	return activa != null and progreso >= activa.cantidad


## Entrega la recompensa y cierra la misión. Devuelve la misión cumplida (o null si todavía no estaba completa).
static func reclamar() -> MisionData:
	if not esta_completa():
		return null
	var mision := activa
	if mision.recompensa_destellos > 0:
		Economia.ganar(mision.recompensa_destellos, MuebleData.Moneda.COMUN)
	if mision.recompensa_gemas > 0:
		Economia.ganar(mision.recompensa_gemas, MuebleData.Moneda.GEMAS)
	if mision.recompensa_ficha != null:
		Inventario.agregar(mision.recompensa_ficha)
	completadas.append(mision.id())
	activa = null
	progreso = 0
	return mision


static func a_datos() -> Dictionary:
	return {"activa": activa.id() if activa != null else "", "progreso": progreso, "completadas": completadas}


static func cargar_datos(datos: Dictionary) -> void:
	completadas.clear()
	for id in datos.get("completadas", []):
		completadas.append(str(id))
	activa = null
	var id_activa: String = datos.get("activa", "")
	for m in catalogo():
		if m.id() == id_activa and id_activa != "":
			activa = m
	progreso = int(datos.get("progreso", 0)) if activa != null else 0
