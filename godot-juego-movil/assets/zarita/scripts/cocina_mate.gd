class_name CocinaMate
extends Node2D
## La cocina del minijuego del mate (la misma imagen del mueble `cocina_horno`). Su origen es el centro de la hornalla del
## frente: la pava calienta si su posición queda a menos de `radio_contacto` del origen. `brillo` (0 a 1) enciende el
## resplandor rojo de la hornalla (nodo `Brasa`).

@export var radio_contacto: float = 90.0
@export var brasa_apagada: Color = Color(1.0, 0.3, 0.1, 0.0)
@export var brasa_encendida: Color = Color(1.0, 0.3, 0.1, 0.7)

var brillo: float = 0.0:
	set(v):
		brillo = clampf(v, 0.0, 1.0)
		if is_node_ready():
			$Brasa.color = brasa_apagada.lerp(brasa_encendida, brillo)


func contiene_pava(posicion_global: Vector2) -> bool:
	return posicion_global.distance_to(global_position) < radio_contacto
