extends Button
## Botón Clima (con icono, en scenes/hud.tscn): cada toque pasa al siguiente modo (automático y luego cada clima fijo).
## No lleva texto: el modo elegido se anuncia con un letrero del HUD (grupo "hud").


func _ready() -> void:
	# En el editor este script no hace nada; solo al jugar.
	pressed.connect(_al_tocar)


func _al_tocar() -> void:
	CicloDia.clima.ciclar()
	get_tree().call_group("hud", "avisar", "Clima: " + CicloDia.clima.texto_modo())
