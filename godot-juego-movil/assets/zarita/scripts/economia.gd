extends Node
## Economía (autoload): las dos monedas del juego, la común y las gemas.

signal cambio

## Provisionales, para probar: lo que tiene el jugador en una partida nueva.
const MONEDAS_INICIALES: int = 500
const GEMAS_INICIALES: int = 5

## SOLO PARA PROBAR: asegura un saldo enorme, también al cargar una partida guardada.
## Poner en false antes de publicar el juego.
const MODO_PRUEBAS: bool = true
const MONEDAS_PRUEBAS: int = 99999
const GEMAS_PRUEBAS: int = 999

var monedas: int = MONEDAS_INICIALES
var gemas: int = GEMAS_INICIALES


func _ready() -> void:
	_aplicar_modo_pruebas()


func saldo(moneda: MuebleData.Moneda) -> int:
	return monedas if moneda == MuebleData.Moneda.COMUN else gemas


func puede_pagar(precio: int, moneda: MuebleData.Moneda) -> bool:
	return saldo(moneda) >= precio


## Resta el precio y devuelve true, o devuelve false sin tocar nada si no alcanza.
func pagar(precio: int, moneda: MuebleData.Moneda) -> bool:
	if not puede_pagar(precio, moneda):
		return false
	_sumar(-precio, moneda)
	return true


func ganar(cantidad: int, moneda: MuebleData.Moneda) -> void:
	_sumar(cantidad, moneda)


func a_datos() -> Dictionary:
	return {"monedas": monedas, "gemas": gemas}


func cargar_datos(datos: Dictionary) -> void:
	monedas = int(datos.get("monedas", monedas))
	gemas = int(datos.get("gemas", gemas))
	_aplicar_modo_pruebas()
	cambio.emit()


func _aplicar_modo_pruebas() -> void:
	if MODO_PRUEBAS:
		monedas = maxi(monedas, MONEDAS_PRUEBAS)
		gemas = maxi(gemas, GEMAS_PRUEBAS)


func _sumar(cantidad: int, moneda: MuebleData.Moneda) -> void:
	if moneda == MuebleData.Moneda.COMUN:
		monedas += cantidad
	else:
		gemas += cantidad
	cambio.emit()
