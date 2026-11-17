## Va en la raíz de un modelo importado (por ejemplo un .glb de Mojulo).
## Saca las cámaras y luces que traiga el archivo y le pone nuestro material toon a todo.
extends Node3D

@export var material: Material


func _ready() -> void:
	for n in find_children("*", "", true, false):
		if n is Camera3D or n is Light3D or n is WorldEnvironment:
			n.queue_free()
		elif n is MeshInstance3D and material:
			n.material_override = material
