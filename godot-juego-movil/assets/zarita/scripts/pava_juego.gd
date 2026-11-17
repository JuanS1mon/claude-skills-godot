class_name PavaJuego
extends Node2D
## La pava del minijuego del mate. Su origen es el centro del cuerpo; `Punta` marca el pico por donde sale el agua.
## Se arrastra con el dedo (lo decide MateJuego) y echa vapor cuando el agua está caliente.

## Perspectiva: arriba (la cocina, más lejos) la pava se ve más chica; abajo, junto al mate, a tamaño completo.
const Y_LEJOS := 460.0
const Y_CERCA := 740.0
const ESCALA_LEJOS := 0.6
const OFFSET_SOMBRA := Vector2(0.0, 68.0)

@export var radio_toque: float = 110.0

var vapor: bool = false:
	set(v):
		vapor = v
		if is_node_ready():
			$Vapor.emitting = v


## La sombra no gira ni se inclina con la pava: se queda plana en el suelo bajo su base.
func _process(_delta: float) -> void:
	var k := clampf(inverse_lerp(Y_LEJOS, Y_CERCA, global_position.y), 0.0, 1.0)
	scale = Vector2.ONE * lerpf(ESCALA_LEJOS, 1.0, k)
	$Sombra.global_rotation = 0.0
	$Sombra.global_position = global_position + OFFSET_SOMBRA * scale.x


func contiene(punto_global: Vector2) -> bool:
	return punto_global.distance_to(global_position) < radio_toque


func punta_global() -> Vector2:
	return $Punta.global_position
