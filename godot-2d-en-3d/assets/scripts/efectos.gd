## Efectos visuales chicos reutilizables (sin escena propia).
class_name Efectos
extends RefCounted


## Número de daño que sube y se desvanece.
static func numero_flotante(padre: Node, cantidad: int, punto: Vector3, color := Color(1.0, 0.9, 0.3)) -> void:
	texto_flotante(padre, str(cantidad), punto, color, 64)


## Texto corto que sube y se desvanece (daño, "¡clink!", nombre del poder...).
static func texto_flotante(padre: Node, texto: String, punto: Vector3, color := Color.WHITE, tamano := 48) -> void:
	var n := Label3D.new()
	n.text = texto
	n.font_size = tamano
	n.outline_size = 12
	n.modulate = color
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.no_depth_test = true
	padre.add_child(n)
	n.global_position = Vector3(punto.x + randf_range(-0.2, 0.2), punto.y + 0.3, 0.5)
	var t := n.create_tween().set_parallel()
	t.tween_property(n, "position:y", n.position.y + 1.0, 0.6).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "modulate:a", 0.0, 0.6).set_delay(0.2)
	t.chain().tween_callback(n.queue_free)


## Esfera de color sin sombreado, para destellos y explosiones.
static func esfera(color: Color, radio: float) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	var malla := SphereMesh.new()
	malla.radius = radio
	malla.height = radio * 2.0
	malla.radial_segments = 16
	malla.rings = 8
	malla.material = mat
	var m := MeshInstance3D.new()
	m.mesh = malla
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## Bola que crece hasta `radio` y se desvanece, con un fogonazo de luz.
static func explosion(padre: Node, punto: Vector3, radio: float, color: Color) -> void:
	var m := esfera(Color(color, 0.7), 1.0)
	padre.add_child(m)
	m.global_position = punto
	m.scale = Vector3.ONE * 0.2
	var luz := OmniLight3D.new()
	luz.light_color = color
	luz.light_energy = 6.0
	luz.omni_range = radio * 2.5
	m.add_child(luz)
	var t := m.create_tween().set_parallel()
	t.tween_property(m, "scale", Vector3.ONE * radio, 0.18).set_ease(Tween.EASE_OUT)
	t.tween_property(m.mesh.material, "albedo_color:a", 0.0, 0.3)
	t.tween_property(luz, "light_energy", 0.0, 0.3)
	t.chain().tween_callback(m.queue_free)


## Mancha de baba sobre el frente de una pared; se desvanece sola.
static func baba(padre: Node, punto: Vector3, duracion := 8.0) -> void:
	var m := esfera(Color(0.45, 0.9, 0.35, 0.85), 0.5)
	padre.add_child(m)
	m.global_position = punto
	m.scale = Vector3(randf_range(0.35, 0.55), randf_range(0.5, 0.8), 0.08)
	var t := m.create_tween()
	t.tween_interval(duracion)
	t.tween_property(m.mesh.material, "albedo_color:a", 0.0, 1.0)
	t.tween_callback(m.queue_free)
