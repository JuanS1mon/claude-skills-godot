extends Node
## Sincroniza la partida con la nube (en el celular: Play Games "Saved Games"). Es un módulo de `Guardado`
## (`Guardado.nube`), no un autoload: así no hay que tocar `project.godot`.
##
## Todo lo que depende de "dónde" se guarda está en el `proveedor` (ver `proveedor_nube.gd`); este archivo solo
## decide CUÁNDO subir, CUÁNDO bajar y qué hacer si las dos partidas son distintas.
##
## La partida local (`user://partida.json`) sigue siendo la que manda; la nube es una copia de respaldo.
## Cada vez que las dos coinciden, el juego anota la "huella" de esa partida (`base_huella`). Con ella sabe
## quién cambió después:
##   - cambió solo este dispositivo → sube;  - cambió solo la nube (jugó en otro celular) → baja;
##   - cambiaron los dos → pregunta al jugador (cartel `conflicto_nube.tscn`).
## La huella es un resumen (SHA-256) del estado SIN la fecha, así que guardar sin cambios no cuenta como cambio.

const ProveedorNube := preload("res://scripts/nube/proveedor_nube.gd")
const ProveedorNubeSimulado := preload("res://scripts/nube/proveedor_nube_simulado.gd")
const EscenaConflicto := preload("res://scenes/conflicto_nube.tscn")

## Poner true para probar en la PC con una nube falsa (archivo `user://nube_simulada.json`).
const SIMULAR_NUBE := false
## Cuánto se espera la respuesta de la nube al abrir el juego antes de seguir con la partida local.
const TIEMPO_ESPERA := 6.0
## Cada cuántos segundos como máximo se sube (se junta lo que cambió; además se sube al pausar o cerrar).
const INTERVALO_SUBIDA := 120.0
## Saved Games acepta archivos de hasta 3 MB.
const LIMITE_BYTES := 3_000_000
## Claves de primer nivel de la partida que NO son estado del juego (no entran en la huella).
const CLAVES_NO_ESTADO := ["version", "tiempo", "nube"]
## Claves (a cualquier profundidad) que cambian solas en cada guardado: `ultimo` es la última hora vista,
## que usan Diarias y los topes diarios para detectar un reloj atrasado.
const CLAVES_RUIDO := ["ultimo"]

enum Decision { NADA, SUBIR, BAJAR, PREGUNTAR }

signal _respuesta(id: int, r: Dictionary)

var proveedor: ProveedorNube = ProveedorNube.new()
## Huella de la última partida que sabemos igual en la nube y acá ("" = nunca se sincronizó).
var base_huella: String = ""
## true tras "Nueva partida": la próxima subida pisa la nube aunque tenga datos.
var forzar: bool = false
## true cuando ya se miró la nube y se resolvió qué hacer; recién entonces se permiten las subidas.
var listo: bool = false
## Si al abrir se trajo la partida de la nube, acá queda lo ganado sin conexión (para el cartel de bienvenida).
var resumen_ausencia: Dictionary = {}

var _sincronizando: bool = false
var _subiendo: bool = false
var _subida_pendiente: bool = false
var _id_pedido: int = 0
var _temporizador: Timer


func _ready() -> void:
	if SIMULAR_NUBE:
		proveedor = ProveedorNubeSimulado.new()
	# Aquí se enchufará el proveedor de Play Games cuando se instale el plugin (ver CLAUDE.md, "Nube").
	_temporizador = Timer.new()
	_temporizador.one_shot = true
	_temporizador.timeout.connect(subir_ahora)
	add_child(_temporizador)


## ¿Hay una nube con la que hablar ahora?
func activa() -> bool:
	return proveedor.disponible()


# --- Qué se anota en el archivo local ---------------------------------------------------------

func a_dict() -> Dictionary:
	return {"base_huella": base_huella, "forzar": forzar}


func de_dict(d: Dictionary) -> void:
	base_huella = String(d.get("base_huella", ""))
	forzar = bool(d.get("forzar", false))


# --- La política: qué hacer según lo que hay en cada lado ------------------------------------

## Resumen (SHA-256) del estado del juego en un texto de partida. Pasa por `parse` para que sea igual
## tanto si el texto salió de este juego como si vino de la nube (ahí los enteros llegan como decimales).
static func huella_de_texto(texto: String) -> String:
	var datos = JSON.parse_string(texto)
	if not (datos is Dictionary):
		return ""
	for k in CLAVES_NO_ESTADO:
		datos.erase(k)
	return JSON.stringify(_sin_ruido(datos), "", true).sha256_text()


## Copia del valor sin las claves que cambian solas (`CLAVES_RUIDO`), a cualquier profundidad.
static func _sin_ruido(v):
	if v is Dictionary:
		var limpio := {}
		for k in v:
			if not (k in CLAVES_RUIDO):
				limpio[k] = _sin_ruido(v[k])
		return limpio
	if v is Array:
		var lista := []
		for x in v:
			lista.append(_sin_ruido(x))
		return lista
	return v


## Decide qué hacer. `local`: {virgen, forzar, huella, base_huella} (ver `Guardado.estado_local`);
## `nube`: {existe, huella}. Es una función pura: se prueba con diccionarios, sin red.
static func decidir(local: Dictionary, nube: Dictionary) -> Decision:
	if local.forzar:
		return Decision.SUBIR                       # "Nueva partida" o "me quedo con la de este dispositivo"
	if not nube.existe:
		return Decision.NADA if local.virgen else Decision.SUBIR   # primera vez: respaldar lo que hay
	if local.virgen:
		return Decision.BAJAR                       # celular nuevo o reinstalado: recuperar
	if nube.huella == local.huella:
		return Decision.NADA                        # ya son iguales
	if nube.huella == local.base_huella:
		return Decision.SUBIR                       # la nube no cambió desde la última vez: lo nuevo es de acá
	if local.huella == local.base_huella:
		return Decision.BAJAR                       # este celular no cambió: lo nuevo está en la nube
	return Decision.PREGUNTAR                       # cambiaron los dos


# --- Al abrir el juego -------------------------------------------------------------------------

## Mira la nube y resuelve. Se llama con `await`. Devuelve true si se TRAJO la partida de la nube
## (en ese caso ya está cargada y `resumen_ausencia` dice lo ganado sin conexión).
## `al_inicio`: false cuando se reintenta con el juego ya en marcha; ahí nunca se cambia nada en silencio:
## si hay algo que traer se le pregunta al jugador y, si acepta, se reinicia la escena.
func sincronizar(al_inicio: bool = true) -> bool:
	resumen_ausencia = {}
	if _sincronizando or not proveedor.disponible():
		return false
	_sincronizando = true
	# El estado de este dispositivo se mide ANTES de esperar la red (ver `Guardado.estado_local`).
	var local: Dictionary = Guardado.estado_local(al_inicio)
	var cambio := await _sincronizar(al_inicio, local)
	_sincronizando = false
	return cambio


func _sincronizar(al_inicio: bool, local: Dictionary) -> bool:
	var r := await _descargar_con_limite()
	if r.estado == "error":
		push_warning("Nube: no se pudo bajar la partida (%s). Se sigue con la local." % r.get("error", "?"))
		return false   # sin `listo`: no se sube nada hasta ver la nube, para no pisar algo más nuevo
	var texto: String = r.get("texto", "") if r.estado == "ok" else ""
	var nube := {"existe": false, "huella": ""}
	if texto != "":
		var h := huella_de_texto(texto)
		if h != "":
			nube = {"existe": true, "huella": h}
		else:
			push_warning("Nube: la partida de la nube está dañada; se ignora.")
	var decision := decidir(local, nube)
	listo = true
	match decision:
		Decision.NADA:
			if nube.existe and base_huella != nube.huella:
				base_huella = nube.huella
				Guardado.guardar(false)
		Decision.SUBIR:
			await subir_ahora()
		Decision.BAJAR:
			if al_inicio:
				return _traer(texto, nube.huella, true)
			return await _preguntar_y_aplicar(texto, nube.huella, false)
		Decision.PREGUNTAR:
			return await _preguntar_y_aplicar(texto, nube.huella, al_inicio)
	return false


## Las dos partidas son distintas: se le pregunta al jugador. Devuelve true si se trajo la de la nube.
func _preguntar_y_aplicar(texto: String, huella: String, al_inicio: bool) -> bool:
	var usar_nube := await _preguntar(texto)
	if usar_nube:
		return _traer(texto, huella, al_inicio)
	forzar = true                    # se queda con la de este dispositivo: la nube se pisa
	await subir_ahora()
	return false


## Reemplaza la partida local por la de la nube. Al inicio se vuelve a cargar acá mismo; con el juego en
## marcha se reinicia la escena principal (que carga la partida al abrirse).
func _traer(texto: String, huella: String, al_inicio: bool) -> bool:
	var datos = JSON.parse_string(texto)
	if not (datos is Dictionary):
		return false
	base_huella = huella
	forzar = false
	datos["nube"] = a_dict()
	var f := FileAccess.open(Guardado.RUTA, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(datos))
	f.close()   # cerrarlo ya: se lee enseguida
	if al_inicio:
		resumen_ausencia = Guardado.cargar()
	else:
		get_tree().reload_current_scene()
	return true


## Cuando se vuelve al juego y al abrir no hubo red: lo intenta de nuevo (una sola vez a la vez).
func reintentar() -> void:
	if not listo and not _sincronizando and proveedor.disponible():
		sincronizar(false)


# --- Subir -------------------------------------------------------------------------------------

## "Nueva partida" también reemplaza la copia de la nube (si no, al volver a abrir el juego la traería de vuelta).
func reemplazar_nube() -> void:
	forzar = true
	base_huella = ""
	Guardado.guardar(false)
	listo = true
	subir_ahora()


## `Guardado.guardar()` lo avisa; la subida real espera un rato para juntar los cambios seguidos.
func pedir_subida() -> void:
	if listo and _temporizador != null and _temporizador.is_stopped() and proveedor.disponible():
		_temporizador.start(INTERVALO_SUBIDA)


## Sube la partida ya mismo si cambió desde la última sincronización. Se llama sola al vencer el temporizador
## y desde `Guardado` al pausar o cerrar. Devuelve true si se subió.
func subir_ahora() -> bool:
	if not listo or not proveedor.disponible():
		return false
	if _subiendo:
		_subida_pendiente = true
		return false
	var texto := JSON.stringify(Guardado.armar_partida(true))
	var huella := huella_de_texto(texto)
	if huella == base_huella and not forzar:
		return false                 # igual a lo último sincronizado: nada que subir
	if texto.to_utf8_buffer().size() > LIMITE_BYTES:
		push_error("Nube: la partida pesa más de 3 MB y Saved Games no la acepta.")
		return false
	_subiendo = true
	var ok: bool = await proveedor.subir(texto, _info(Guardado.resumen_de(JSON.parse_string(texto))))
	_subiendo = false
	if ok:
		base_huella = huella
		forzar = false
		Guardado.guardar(false)      # deja anotada la base en el archivo local
	else:
		push_warning("Nube: no se pudo subir la partida; se reintenta en la próxima.")
		_temporizador.start(INTERVALO_SUBIDA)
	if _subida_pendiente:
		_subida_pendiente = false
		pedir_subida()
	return ok


## Lo que Saved Games muestra en su lista de partidas guardadas.
func _info(resumen: Dictionary) -> Dictionary:
	return {
		"descripcion": "Ola %d · %d tripulantes" % [resumen.ola, resumen.tripulantes],
		"ola": resumen.ola,
		"tiempo": resumen.tiempo,
	}


# --- Auxiliares --------------------------------------------------------------------------------

## Baja la partida pero no espera para siempre: si la nube tarda más de `TIEMPO_ESPERA`, devuelve error.
func _descargar_con_limite() -> Dictionary:
	_id_pedido += 1
	var mi_id := _id_pedido
	get_tree().create_timer(TIEMPO_ESPERA).timeout.connect(
		func(): _respuesta.emit(mi_id, {"estado": "error", "error": "tiempo agotado"}))
	_descargar_y_avisar(mi_id)
	while true:
		var r: Array = await _respuesta
		if r[0] == mi_id:
			return r[1]
	return {}


func _descargar_y_avisar(id: int) -> void:
	var r: Dictionary = await proveedor.descargar()
	_respuesta.emit(id, r)


## Muestra el cartel y devuelve true si el jugador elige la partida de la nube.
func _preguntar(texto_nube: String) -> bool:
	var cartel := EscenaConflicto.instantiate()
	get_tree().root.add_child.call_deferred(cartel)
	await cartel.ready
	var de_este := Guardado.resumen_de(Guardado.armar_partida(true))
	var de_nube := Guardado.resumen_de(JSON.parse_string(texto_nube))
	cartel.mostrar(de_este, de_nube)
	var usar_nube: bool = await cartel.elegido
	cartel.queue_free()
	return usar_nube
