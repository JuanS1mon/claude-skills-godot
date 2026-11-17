class_name DialogoPersonaje
extends CanvasLayer
## Cuadro de diálogo con un amigo de Zarita: su nombre, lo que dice y hasta dos botones de respuesta. Lo que dice y ofrece lo
## decide Conversaciones; aquí solo se muestra. Va en su propia capa, por encima de la interfaz y del mapa.

## Se eligió una opción (la casa guarda la partida).
signal accion_hecha

@onready var _nombre: Label = $Raiz/Panel/Caja/Nombre
@onready var _texto: Label = $Raiz/Panel/Caja/Texto
@onready var _botones: Array[Button] = [$Raiz/Panel/Caja/Opcion1, $Raiz/Panel/Caja/Opcion2]

var _opciones: Array = []


func _ready() -> void:
	for i in _botones.size():
		_botones[i].pressed.connect(_elegir.bind(i))
	$Raiz/Panel/Caja/Cerrar.pressed.connect(cerrar)
	cerrar()   # en el editor se ve abierto para poder diseñarlo


## Abre el diálogo con una conversación de Conversaciones.de(). Si está vacía, no hace nada.
func abrir(conversacion: Dictionary) -> void:
	if conversacion.is_empty():
		return
	_nombre.text = (conversacion["personaje"] as PersonajeData).nombre
	_mostrar(conversacion["texto"], conversacion["opciones"])
	visible = true


func cerrar() -> void:
	visible = false


func _mostrar(texto: String, opciones: Array) -> void:
	_texto.text = texto
	_opciones = opciones
	for i in _botones.size():
		_botones[i].visible = i < opciones.size()
		if i < opciones.size():
			_botones[i].text = opciones[i]["texto"]


func _elegir(indice: int) -> void:
	var respuesta: Variant = (_opciones[indice]["accion"] as Callable).call()
	accion_hecha.emit()
	if respuesta is String:
		_mostrar(respuesta, [])
	else:
		cerrar()
