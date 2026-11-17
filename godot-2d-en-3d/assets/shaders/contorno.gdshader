// Contorno por casco invertido: se dibuja la malla agrandada y de espaldas.
// Se usa como next_pass del material toon. Empuja los vértices desde el centro
// (no por la normal) para que las cajas no se abran en las esquinas.
shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

uniform vec4 color_linea : source_color = vec4(0.08, 0.06, 0.1, 1.0);
uniform float grosor : hint_range(0.0, 0.2) = 0.035;

void vertex() {
	VERTEX += normalize(VERTEX) * grosor;
}

void fragment() {
	ALBEDO = color_linea.rgb;
}
