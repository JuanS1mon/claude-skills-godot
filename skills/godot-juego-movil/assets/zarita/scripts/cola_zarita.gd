class_name ColaZarita
extends RefCounted
## Ayudante para mover la cola de Zarita con el shader cola.gdshader. La zona de la cola cambia según hacia dónde mira.

const SHADER: Shader = preload("res://shaders/cola.gdshader")

## Zona de la cola en cada animación: [izquierda, arriba, derecha, abajo] de la imagen, hacia dónde queda la punta,
## dirección del vaivén y amplitud.
const ZONAS: Dictionary = {
	&"caminar_abajo": {"zona": Vector4(0.74, 0.30, 0.97, 0.90), "punta_izquierda": false, "eje": Vector2(1.0, 0.0), "amplitud": 0.022},
	&"caminar_derecha": {"zona": Vector4(0.02, 0.50, 0.38, 0.95), "punta_izquierda": true, "eje": Vector2(0.0, 1.0), "amplitud": 0.020},
	&"caminar_izquierda": {"zona": Vector4(0.62, 0.50, 0.98, 0.95), "punta_izquierda": false, "eje": Vector2(0.0, 1.0), "amplitud": 0.020},
	&"caminar_arriba": {"zona": Vector4(0.50, 0.72, 0.95, 0.97), "punta_izquierda": false, "eje": Vector2(0.0, 1.0), "amplitud": 0.012},
}


static func crear_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	return material


## Ajusta la zona de la cola a la animación indicada. No hace nada si ya estaba ajustada para ella.
static func configurar(material: ShaderMaterial, animacion: StringName) -> void:
	if not ZONAS.has(animacion) or material.get_meta(&"animacion", &"") == animacion:
		return
	material.set_meta(&"animacion", animacion)
	var datos: Dictionary = ZONAS[animacion]
	material.set_shader_parameter("zona", datos["zona"])
	material.set_shader_parameter("punta_a_la_izquierda", datos["punta_izquierda"])
	material.set_shader_parameter("eje", datos["eje"])
	material.set_shader_parameter("amplitud", datos["amplitud"])
