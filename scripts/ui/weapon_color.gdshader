shader_type canvas_item;
// Armadura na cor da arma: troca o matiz dos azuis (e a saturação, para armas cinza/brancas) pela cor
// alvo, mantendo o brilho de cada pixel. Pele, branco, vermelho e contornos ficam como estão.
uniform vec4 target : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(c.rgb);
	vec3 t = rgb2hsv(target.rgb);
	if (hsv.y > 0.25 && hsv.x > 0.5 && hsv.x < 0.78) {
		vec3 swapped = hsv2rgb(vec3(t.x, hsv.y * min(1.0, t.y * 1.3), hsv.z));
		c.rgb = mix(c.rgb, swapped, amount);
	}
	COLOR = c;
}
