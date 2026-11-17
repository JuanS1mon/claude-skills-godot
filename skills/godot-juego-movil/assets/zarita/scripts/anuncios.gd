extends Node
## Anuncios (autoload): la única puerta del juego hacia la publicidad.
## Hoy es SIMULADO (espera 2 s y da el premio). Cuando se integre el plugin de AdMob,
## solo hay que cambiar el cuerpo de _mostrar_anuncio_real(): el resto del juego no se entera.

## Se emite al terminar un anuncio con recompensa: true si el jugador lo vio entero.
signal recompensa_terminada(obtenida: bool)

## true = anuncio simulado; false = usar el plugin real (cuando exista).
const SIMULADO: bool = true
const SEGUNDOS_SIMULADOS: float = 2.0

## IDs de prueba que Google publica para desarrollar. Con tus IDs reales de AdMob se reemplazan
## ANTES de publicar (y nunca se toca un anuncio real propio: pueden cerrar la cuenta).
const ID_RECOMPENSA_PRUEBA_ANDROID: String = "ca-app-pub-3940256099942544/5224354917"

var _ocupado: bool = false


## ¿Se puede pedir un anuncio ahora? (con el plugin real: que esté cargado y no haya otro en curso)
func disponible() -> bool:
	return not _ocupado


## Muestra un anuncio con recompensa y devuelve true si el jugador ganó el premio.
## Se usa con await:   var gano: bool = await Anuncios.mostrar_recompensa()
func mostrar_recompensa() -> bool:
	if _ocupado:
		return false
	_ocupado = true
	var obtenida: bool
	if SIMULADO:
		await get_tree().create_timer(SEGUNDOS_SIMULADOS).timeout
		obtenida = true
	else:
		obtenida = await _mostrar_anuncio_real()
	_ocupado = false
	recompensa_terminada.emit(obtenida)
	return obtenida


## Aquí irá la llamada al plugin de AdMob (Android). Debe esperar a que el anuncio termine
## y devolver true solo si el plugin avisó "recompensa obtenida" (no si lo cerraron antes).
func _mostrar_anuncio_real() -> bool:
	push_warning("Anuncios: falta integrar el plugin de AdMob.")
	return false
