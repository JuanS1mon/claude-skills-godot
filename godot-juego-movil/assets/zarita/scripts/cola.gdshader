shader_type canvas_item;
// Ondula la cola de Zarita: desplaza un poco los píxeles de una zona del dibujo, más cuanto más cerca de la punta.
// El cuerpo no se mueve: solo lo que cae dentro de `zona`.

// Zona de la cola en coordenadas de la imagen (0 a 1): izquierda, arriba, derecha, abajo.
uniform vec4 zona = vec4(0.74, 0.30, 0.97, 0.90);
// true si la punta de la cola queda a la izquierda de la zona (y la base a la derecha).
uniform bool punta_a_la_izquierda = false;
// Dirección del vaivén: (1, 0) a los lados, (0, 1) arriba y abajo.
uniform vec2 eje = vec2(1.0, 0.0);
// Cuánto se mueve la punta, como fracción de la imagen.
uniform float amplitud = 0.02;
uniform float velocidad = 3.0;

void fragment() {
	// 0 en la base de la cola y 1 en la punta.
	float t = (UV.x - zona.x) / (zona.z - zona.x);
	if (punta_a_la_izquierda) {
		t = 1.0 - t;
	}
	t = clamp(t, 0.0, 1.0);
	float peso = smoothstep(0.0, 1.0, t)
		* smoothstep(zona.y, zona.y + 0.05, UV.y)
		* (1.0 - smoothstep(zona.w - 0.05, zona.w, UV.y));
	vec2 desplazamiento = eje * sin(TIME * velocidad + UV.y * 6.0 + UV.x * 6.0) * amplitud * peso;
	COLOR = texture(TEXTURE, UV + desplazamiento);
}
