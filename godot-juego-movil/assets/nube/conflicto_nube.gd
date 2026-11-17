extends CanvasLayer
## Cartel que aparece si la partida de este dispositivo y la de la nube son distintas (jugó en dos celulares,
## o instaló el juego en uno nuevo con avance en los dos lados). Nunca se elige solo: decide el jugador.
## Corre sola con F6 mostrando un ejemplo.

## `usar_nube` es true si el jugador elige la partida de la nube; false si se queda con la de este dispositivo.
signal elegido(usar_nube: bool)

@onready var raiz: Control = $Raiz
@onready var etiqueta_local: Label = $Raiz/Panel/Caja/TarjetaLocal/Etiqueta
@onready var datos_local: Label = $Raiz/Panel/Caja/TarjetaLocal/Datos
@onready var boton_local: Button = $Raiz/Panel/Caja/TarjetaLocal/Boton
@onready var etiqueta_nube: Label = $Raiz/Panel/Caja/TarjetaNube/Etiqueta
@onready var datos_nube: Label = $Raiz/Panel/Caja/TarjetaNube/Datos
@onready var boton_nube: Button = $Raiz/Panel/Caja/TarjetaNube/Boton


func _ready() -> void:
	boton_local.pressed.connect(func(): elegido.emit(false))
	boton_nube.pressed.connect(func(): elegido.emit(true))
	if get_tree().current_scene == self:   # F6: un ejemplo para verlo
		var ahora := Time.get_unix_time_from_system()
		mostrar({"ola": 18, "misiones": 31, "cristales": 420, "tripulantes": 4, "tiempo": ahora - 7200.0},
			{"ola": 42, "misiones": 55, "cristales": 1250, "tripulantes": 6, "tiempo": ahora - 3.0 * 86400.0})
		elegido.connect(func(usar_nube: bool): print("Elegida la partida ", "de la nube" if usar_nube else "de este dispositivo"))


## `local` y `nube`: lo que arma `Guardado.resumen_de` (ola, misiones, cristales, tripulantes, tiempo).
func mostrar(local: Dictionary, nube: Dictionary) -> void:
	var marca_local := ""
	var marca_nube := ""
	if int(nube.ola) != int(local.ola):
		if int(nube.ola) > int(local.ola):
			marca_nube = "  ★ más avance"
		else:
			marca_local = "  ★ más avance"
	elif float(nube.tiempo) != float(local.tiempo):
		if float(nube.tiempo) > float(local.tiempo):
			marca_nube = "  ★ más reciente"
		else:
			marca_local = "  ★ más reciente"
	etiqueta_local.text = "ESTE DISPOSITIVO" + marca_local
	etiqueta_nube.text = "LA NUBE" + marca_nube
	datos_local.text = _texto(local)
	datos_nube.text = _texto(nube)
	raiz.visible = true


func _texto(r: Dictionary) -> String:
	return "Ola máxima %d · %d misiones\n%d tripulantes · %d cristales\nGuardada %s" % [
		int(r.ola), int(r.misiones), int(r.tripulantes), int(r.cristales), _hace(float(r.tiempo))]


static func _hace(t: float) -> String:
	if t <= 0.0:
		return "(fecha desconocida)"
	var s := int(Time.get_unix_time_from_system() - t)
	if s < 90:
		return "hace un momento"
	if s < 3600:
		return "hace %d min" % roundi(s / 60.0)
	if s < 86400:
		return "hace %d h" % roundi(s / 3600.0)
	return "hace %d días" % roundi(s / 86400.0)
