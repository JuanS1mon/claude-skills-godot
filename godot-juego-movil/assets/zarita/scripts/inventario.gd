extends Node
## Inventario (autoload): fichas de los muebles que el jugador posee y aún no están colocados.

signal cambio

## Provisional, para probar: lo que el jugador tiene al empezar.
const FICHAS_INICIALES: Array[String] = [
	"res://data/muebles/silla_madera.tres",
	"res://data/muebles/mesa_redonda.tres",
	"res://data/muebles/cama_sencilla.tres",
	"res://data/muebles/planta_maceta.tres",
]

var muebles: Array[MuebleData] = []


func _ready() -> void:
	for ruta in FICHAS_INICIALES:
		if ResourceLoader.exists(ruta):
			muebles.append(load(ruta) as MuebleData)
	print("Inventario listo con %d muebles" % muebles.size())


## Rutas de las fichas, para guardar la partida.
func rutas() -> Array[String]:
	var resultado: Array[String] = []
	for ficha in muebles:
		resultado.append(ficha.resource_path)
	return resultado


## Reemplaza el inventario por las fichas guardadas (ignora las que ya no existan).
func cargar_rutas(lista: Array) -> void:
	muebles.clear()
	for ruta in lista:
		if ResourceLoader.exists(ruta):
			muebles.append(load(ruta) as MuebleData)
	cambio.emit()


func agregar(ficha: MuebleData) -> void:
	muebles.append(ficha)
	cambio.emit()


## Devuelve false si el jugador no tenía esa ficha.
func quitar(ficha: MuebleData) -> bool:
	var indice := muebles.find(ficha)
	if indice == -1:
		return false
	muebles.remove_at(indice)
	cambio.emit()
	return true
