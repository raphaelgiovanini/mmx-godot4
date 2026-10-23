shader_type canvas_item;
// Cores da arma no sprite (SpriteVisual.set_palette), na GPU: sem recolorir quadro a quadro.
// mode 1 (X): troca cor a cor, como o SNES troca índices de paleta.
// mode 1 também serve para a lista de cores da armadura (SpriteVisual.ARMOR).
// mode 2 (sem lista): pixels no matiz principal do sprite, fora tons de pele, viram a cor da arma de
// brilho mais próximo.

uniform int mode = 0;
uniform int count = 0;
uniform vec3 from_c[12];
uniform vec3 to_c[12];
uniform float hue = 0.0;
uniform int ramp_n = 0;
uniform float ramp_v[8];
uniform vec3 ramp_c[8];

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

vec3 hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (mode == 1) {
		for (int i = 0; i < count; i++) {
			if (distance(c.rgb, from_c[i]) < 0.006) {
				c.rgb = to_c[i];
				break;
			}
		}
	} else if (mode == 2 && ramp_n > 0) {
		vec3 h = hsv(c.rgb);
		float d = abs(h.x - hue);
		bool skin = h.x >= 0.02 && h.x <= 0.11 && h.y <= 0.66 && h.z >= 0.7;   // rosto e mãos ficam
		if (!skin && h.y >= 0.3 && min(d, 1.0 - d) <= 0.05) {
			int best = 0;
			for (int i = 1; i < ramp_n; i++) {
				if (abs(ramp_v[i] - h.z) < abs(ramp_v[best] - h.z)) {
					best = i;
				}
			}
			c.rgb = ramp_c[best];
		}
	}
	COLOR = c * tint;
}
