// Sombreado "dibujado": la luz se corta en bandas en vez de degradarse.
// El color se pone por instancia (instance_shader_parameters/color),
// así todos los obstáculos comparten el mismo material.
// Opcional: una textura dibujada proyectada por ejes (triplanar simple), sin depender
// de las UV de la malla: sirve igual para un bloque de 1 m o una plataforma de 3 m.
shader_type spatial;

instance uniform vec4 color : source_color = vec4(0.75, 0.7, 0.65, 1.0);
uniform int bandas : hint_range(1, 6) = 3;
uniform float suavizado : hint_range(0.0, 0.2) = 0.02;
uniform float brillo_borde : hint_range(0.0, 1.0) = 0.15;
// Modelos de Mojulo guardan el color en los vértices: activar para usarlo.
uniform bool usar_color_vertice = false;

uniform sampler2D textura : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform bool usar_textura = false;
// Metros que ocupa una repetición de la textura (ancho, alto).
uniform vec2 metros_por_textura = vec2(1.0, 1.0);
uniform vec2 desfase = vec2(0.0, 0.0);
// En espacio del objeto (cajas que se mueven y giran) o del mundo (piso, bloques fijos).
uniform bool espacio_objeto = false;
// Solo la cara de frente lleva textura; las demás usan `color` (el piso: tira de pasto al frente).
uniform bool solo_frente = false;
// Para tiras de suelo: debajo de la primera repetición se repite solo la parte de abajo (tierra).
uniform bool tira_de_suelo = false;

varying vec3 pos_tex;
varying vec3 normal_tex;

void vertex() {
	if (espacio_objeto) {
		pos_tex = VERTEX;
		normal_tex = NORMAL;
	} else {
		pos_tex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		normal_tex = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
}

void fragment() {
	vec3 base = usar_color_vertice ? COLOR.rgb : color.rgb;
	if (usar_textura) {
		vec3 an = abs(normal_tex);
		bool frente = an.z >= an.x && an.z >= an.y;
		vec2 c;
		if (frente) {
			c = pos_tex.xy;
		} else if (an.y >= an.x) {
			c = pos_tex.xz;
		} else {
			c = pos_tex.zy;
		}
		// La imagen tiene la v hacia abajo; el mundo, la y hacia arriba.
		vec2 uv = vec2(c.x, -c.y) / metros_por_textura + desfase;
		// Derivadas de la UV sin cortes: con fract() el mipmap salta y dibuja una línea en cada repetición.
		vec2 dx = dFdx(uv);
		vec2 dy = dFdy(uv);
		if (tira_de_suelo && uv.y > 1.0) {
			// Margen arriba y abajo: el filtrado no mezcla la tierra con el pasto del borde opuesto.
			// En espejo (ida y vuelta): la tierra de la IA no repite en vertical y se notaba el corte.
			float t = (uv.y - 1.0) / 0.42;
			float f = fract(t);
			if (mod(floor(t), 2.0) < 1.0) {
				f = 1.0 - f;
			}
			uv.y = 0.56 + f * 0.42;
			dx.y *= 0.42;
			dy.y *= 0.42;
		}
		if (!solo_frente || frente) {
			base = textureGrad(textura, uv, dx, dy).rgb;
		}
	}
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float n = float(bandas);
	float escalon = floor(ndl * n) / n;
	float resto = fract(ndl * n);
	float b = escalon + smoothstep(1.0 - suavizado, 1.0, resto) / n;
	DIFFUSE_LIGHT += b * LIGHT_COLOR / PI;

	// Luz de borde: separa la silueta del fondo como un trazo claro.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	DIFFUSE_LIGHT += rim * brillo_borde * b * LIGHT_COLOR / PI;
}
