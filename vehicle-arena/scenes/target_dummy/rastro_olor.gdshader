// Niebla del rastro de olor del jabalí.
// Cada partícula es un cuadrado acostado sobre el piso (neblina rasante, para no
// tapar la vista); este shader le da forma de nube: un círculo suave "comido" por
// ruido, que se mueve despacio, y que se funde con el terreno donde lo atraviesa.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Textura de ruido (NoiseTexture2D, seamless) que deshace el borde del círculo
uniform sampler2D ruido : repeat_enable, filter_linear;
// Qué tan grande se ve el ruido dentro de cada bocanada (más chico = manchas más grandes)
uniform float escala_ruido = 0.7;
// Qué tan rápido se mueve la niebla por dentro
uniform float velocidad_ruido = 0.02;
// Cuántos metros antes de tocar el piso empieza a desvanecerse
// (chico: la niebla está acostada a poca altura del terreno)
uniform float suavidad_piso = 0.6;
// Profundidad de la escena (lo que ya está dibujado detrás), para el fundido con el piso
uniform sampler2D textura_profundidad : hint_depth_texture, filter_linear_mipmap;

varying vec2 desfase_ruido;
varying float angulo;

void vertex() {
	// Sin billboard: el cuadrado queda acostado (QuadMesh orientado hacia arriba).
	// El giro al azar de cada partícula lo aplicamos a la textura en fragment().
	angulo = INSTANCE_CUSTOM.x;
	// Cada bocanada usa una parte distinta del ruido (según dónde nació)
	desfase_ruido = MODEL_MATRIX[3].xz * 0.031;
}

void fragment() {
	// Giramos la textura según el ángulo de la partícula
	vec2 centro = UV - 0.5;
	vec2 uv = vec2(cos(angulo) * centro.x - sin(angulo) * centro.y,
			sin(angulo) * centro.x + cos(angulo) * centro.y) + 0.5;

	// Círculo suave: 1 en el centro, 0 en el borde
	float circulo = 1.0 - smoothstep(0.1, 0.5, length(centro));

	// Ruido que se mueve despacio: rompe el círculo en jirones de niebla
	vec2 uv_ruido = uv * escala_ruido + desfase_ruido + vec2(TIME * velocidad_ruido, TIME * velocidad_ruido * 0.6);
	float n = texture(ruido, uv_ruido).r;
	float forma = circulo * smoothstep(0.3, 0.8, n + circulo * 0.3);

	// Fundido con el piso: cuanto más cerca está la niebla de lo que hay detrás,
	// más transparente (así no se ve la "línea" donde el cuadrado atraviesa el terreno)
	float profundidad = texture(textura_profundidad, SCREEN_UV).r;
	// (Compatibility, el de la versión Web, guarda la profundidad distinto)
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, profundidad) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, profundidad);
#endif
	vec4 fondo = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	fondo.xyz /= fondo.w;
	float distancia_al_fondo = VERTEX.z - fondo.z;
	float fundido = clamp(distancia_al_fondo / suavidad_piso, 0.0, 1.0);

	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * forma * fundido;
}
