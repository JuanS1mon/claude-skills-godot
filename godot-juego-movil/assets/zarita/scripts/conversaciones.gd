class_name Conversaciones
extends RefCounted
## Lo que dicen y ofrecen los amigos de Zarita cuando se habla con ellos desde el mapa (ver DialogoPersonaje).
## `de(id)` arma una conversación según el estado del juego: {"personaje": PersonajeData, "texto": String,
## "opciones": [{"texto": String, "accion": Callable}]}. Si una acción devuelve un String, el diálogo lo muestra como respuesta.

const CARPETA_PERSONAJES: String = "res://data/personajes/"
const CARPETA_BLENDS: String = "res://data/blends/"


static func de(id_personaje: String) -> Dictionary:
	var ruta := CARPETA_PERSONAJES + id_personaje + ".tres"
	if not ResourceLoader.exists(ruta):
		return {}
	var personaje := load(ruta) as PersonajeData
	var conversacion: Dictionary
	match id_personaje:
		"don_jacinto":
			conversacion = _jacinto()
		"teo":
			conversacion = _teo()
		_:
			return {}
	conversacion["personaje"] = personaje
	return conversacion


## Don Jacinto: un puñado de yuyos serranos por día.
static func _jacinto() -> Dictionary:
	if not Mate.puede_recibir_regalo():
		return {"texto": "Hoy ya te di yuyos, vecina. Volvé mañana: el monte no da todo junto.", "opciones": []}
	return {
		"texto": "Vecina, mirá qué yuyos serranos traje hoy. Probalos en el mate, que te van a hacer bien.",
		"opciones": [{"texto": "Aceptar los yuyos", "accion": _dar_yuyos}],
	}


static func _dar_yuyos() -> String:
	var mezclas: Array[BlendData] = []
	for archivo in ResourceLoader.list_directory(CARPETA_BLENDS):
		var mezcla := load(CARPETA_BLENDS + archivo) as BlendData
		if mezcla != null and mezcla.precio == 0:
			mezclas.append(mezcla)
	var recibida := Mate.recibir_regalo(mezclas)
	return "Te di 2 de yerba y %s. ¡Que te rinda!" % (recibida.nombre if recibida != null else "yuyos")


## Teo: propone aventuras de una en una y entrega la recompensa.
static func _teo() -> Dictionary:
	var activa := Misiones.activa
	if activa != null and Misiones.esta_completa():
		return {
			"texto": "¡Lo lograste, Zarita! Esto es para vos, como prometí.",
			"opciones": [{"texto": "Recibir mi tesoro", "accion": _entregar_recompensa}],
		}
	if activa != null:
		return {"texto": "%s\n\nLlevás %d de %d." % [activa.texto, Misiones.progreso, activa.cantidad], "opciones": []}
	var siguiente := Misiones.siguiente_de("teo")
	if siguiente == null:
		return {"texto": "Por hoy no hay más aventuras. Mirá qué lindo está el sol... me hago una siesta.", "opciones": []}
	return {"texto": siguiente.texto, "opciones": [{"texto": "¡Acepto!", "accion": _aceptar.bind(siguiente)}]}


static func _aceptar(mision: MisionData) -> String:
	Misiones.aceptar(mision)
	return "¡Dale! Avisame cuando lo tengas."


static func _entregar_recompensa() -> String:
	var mision := Misiones.reclamar()
	if mision == null:
		return "Todavía no está."
	var partes: Array[String] = []
	if mision.recompensa_destellos > 0:
		partes.append("%d Destellos" % mision.recompensa_destellos)
	if mision.recompensa_gemas > 0:
		partes.append("%d gemas" % mision.recompensa_gemas)
	if mision.recompensa_ficha != null:
		partes.append(mision.recompensa_ficha.nombre)
	return "Recibiste: %s." % ", ".join(partes)
