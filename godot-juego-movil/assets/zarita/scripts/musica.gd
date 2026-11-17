extends Node
## Música (autoload): lleva el estado de la música del juego y la reproduce con fundidos.
## Estado: 0 = apagado; 1, 2, ... = suena esa pista (se repite sola).
## Los reproductores (muebles) solo piden pasar al siguiente estado; la casa avisa si hay alguno puesto.

## Para saber qué suena (el letrero del reproductor lo muestra).
signal cambio

## Pistas, en orden. La primera es la de la pantalla de inicio. Lo que se arrastre aquí va primero;
## las demás canciones de la carpeta se añaden solas al final (ver _agregar_pistas_de_la_carpeta).
@export var pistas: Array[AudioStream] = []
## Volumen de reproducción en decibelios (0 = volumen original, negativo = más bajo).
@export var volumen_db: float = -8.0

## Carpeta donde se dejan las canciones (MP3, OGG o WAV).
const CARPETA_PISTAS: String = "res://assets/musica/"
const SEGUNDOS_FUNDIDO: float = 3.0
## Fundido corto para cortar o cambiar de pista sin golpes.
const SEGUNDOS_FUNDIDO_RAPIDO: float = 0.6
const VOLUMEN_MUDO_DB: float = -60.0

## 0 = apagado, 1..n = número de pista. Empieza en la primera, para la pantalla de inicio.
var estado: int = 1
## false cuando en la casa no hay ningún reproductor: entonces no suena aunque el estado diga que sí.
var permitido: bool = true

var _sonando: int = 0   # la pista que suena de verdad (0 = ninguna)
var _tween: Tween

@onready var _reproductor: AudioStreamPlayer = $Reproductor


func _ready() -> void:
	_agregar_pistas_de_la_carpeta()
	# Cuando una pista termina sola, el reproductor avisa con "finished" y se repite.
	_reproductor.finished.connect(_al_terminar_pista)
	_aplicar()


## Suma al final las canciones de la carpeta que aún no estén en `pistas`:
## para tener una canción nueva basta con copiar su archivo a assets/musica/.
func _agregar_pistas_de_la_carpeta() -> void:
	while pistas.has(null):   # una casilla vacía del Inspector no debe romper nada
		pistas.erase(null)
	var conocidas: Array[String] = []
	for pista in pistas:
		conocidas.append(pista.resource_path)
	var archivos := ResourceLoader.list_directory(CARPETA_PISTAS)
	archivos.sort()   # orden alfabético: así el orden de las pistas nuevas es siempre el mismo
	for archivo in archivos:
		if archivo.ends_with("/") or (CARPETA_PISTAS + archivo) in conocidas:
			continue
		var nueva := load(CARPETA_PISTAS + archivo) as AudioStream
		if nueva != null:
			pistas.append(nueva)


## Pasa a apagado -> pista 1 -> pista 2 -> ... -> apagado.
func siguiente_estado() -> void:
	estado = (estado + 1) % (pistas.size() + 1)
	cambio.emit()
	_aplicar()


## La casa lo llama según haya o no un reproductor puesto.
func fijar_permitido(valor: bool) -> void:
	if permitido == valor:
		return
	permitido = valor
	_aplicar()


func nombre_estado() -> String:
	if estado == 0 or estado > pistas.size():
		return "Apagado"
	return pistas[estado - 1].resource_path.get_file().get_basename().replace("_", " ").capitalize()


func a_datos() -> Dictionary:
	return {"estado": estado}


func cargar_datos(datos: Dictionary) -> void:
	estado = clampi(int(datos.get("estado", estado)), 0, pistas.size())
	cambio.emit()
	_aplicar()


## Compara lo que debería sonar con lo que suena y hace solo lo necesario.
func _aplicar() -> void:
	var deseada := estado if (permitido and not pistas.is_empty()) else 0
	if deseada == _sonando:
		return
	_sonando = deseada
	if _tween:
		_tween.kill()
	if _reproductor.playing:
		# Primero se baja el volumen de lo que suena y luego se arranca (o se calla) lo nuevo.
		_tween = create_tween()
		_tween.tween_property(_reproductor, "volume_db", VOLUMEN_MUDO_DB, SEGUNDOS_FUNDIDO_RAPIDO)
		_tween.tween_callback(_arrancar)
	else:
		_arrancar()


func _arrancar() -> void:
	_reproductor.stop()
	if _sonando == 0:
		return
	var pista := pistas[_sonando - 1]
	_reproductor.stream = pista
	_reproductor.volume_db = VOLUMEN_MUDO_DB
	_reproductor.play()
	_programar_fundidos(pista.get_length())


func _al_terminar_pista() -> void:
	if _sonando > 0:
		_arrancar()


## Sube el volumen al empezar, lo mantiene, y lo baja justo antes de que termine la pista.
func _programar_fundidos(duracion: float) -> void:
	_tween = create_tween()
	_tween.tween_property(_reproductor, "volume_db", volumen_db, SEGUNDOS_FUNDIDO)
	_tween.tween_interval(maxf(duracion - 2.0 * SEGUNDOS_FUNDIDO, 0.0))
	_tween.tween_property(_reproductor, "volume_db", VOLUMEN_MUDO_DB, SEGUNDOS_FUNDIDO)
