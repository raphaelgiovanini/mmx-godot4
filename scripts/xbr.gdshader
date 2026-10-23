shader_type canvas_item;
// xBR nível 2 (Hyllian), em cima da imagem do jogo (398×224) desenhada na resolução da janela.
// Para cada pixel da tela: acha o canto do pixel do jogo em que ele está, testa se ali passa uma borda
// (diagonal de 45°, ou 30°/60° no nível 2) e, se passa, pinta aquele canto com a cor do vizinho,
// com a borda antisserrilhada. Resultado: contornos lisos sem borrar o pixel art.

uniform bool enabled = true;

const vec3 Y = vec3(0.299, 0.587, 0.114) * 255.0;   // luma em 0..255
const float EQ = 15.0;                       // abaixo disso, duas cores contam como iguais
const float LV2 = 2.0;

float df(float a, float b) { return abs(a - b); }
bool eq(float a, float b) { return df(a, b) < EQ; }

void fragment() {
	if (!enabled) {
		COLOR = texture(TEXTURE, UV);
	} else {
		vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
		vec2 pos = UV * size;
		vec2 ip = floor(pos);
		vec2 fp = fract(pos);
		// Gira a vizinhança para o canto deste pedaço do pixel ficar sempre em (1, 1).
		vec2 dir = vec2(fp.x >= 0.5 ? 1.0 : -1.0, fp.y >= 0.5 ? 1.0 : -1.0);
		vec2 f = vec2(dir.x > 0.0 ? fp.x : 1.0 - fp.x, dir.y > 0.0 ? fp.y : 1.0 - fp.y);
		#define S(dx, dy) texture(TEXTURE, (ip + vec2(dx, dy) * dir + 0.5) * TEXTURE_PIXEL_SIZE)
		vec4 pE = S(0.0, 0.0), pF = S(1.0, 0.0), pH = S(0.0, 1.0), pI = S(1.0, 1.0);
		vec4 pB = S(0.0, -1.0), pD = S(-1.0, 0.0), pC = S(1.0, -1.0), pG = S(-1.0, 1.0);
		vec4 pF4 = S(2.0, 0.0), pI4 = S(2.0, 1.0), pH5 = S(0.0, 2.0), pI5 = S(1.0, 2.0);
		float e = dot(pE.rgb, Y), fv = dot(pF.rgb, Y), h = dot(pH.rgb, Y), i = dot(pI.rgb, Y);
		float b = dot(pB.rgb, Y), d = dot(pD.rgb, Y), c = dot(pC.rgb, Y), g = dot(pG.rgb, Y);
		float f4 = dot(pF4.rgb, Y), i4 = dot(pI4.rgb, Y), h5 = dot(pH5.rgb, Y), i5 = dot(pI5.rgb, Y);

		bool lv1 = !eq(e, fv) && !eq(e, h) && ((!eq(fv, b) && !eq(h, d)) || (eq(e, i) && !eq(fv, i4) && !eq(h, i5))
			|| eq(e, g) || eq(e, c));
		float wd1 = df(e, c) + df(e, g) + df(i, h5) + df(i, f4) + 4.0 * df(h, fv);
		float wd2 = df(h, d) + df(h, i5) + df(fv, i4) + df(fv, b) + 4.0 * df(e, i);
		bool edge = lv1 && wd1 < wd2;
		bool edge_left = edge && LV2 * df(fv, g) <= df(h, c) && !eq(e, g) && !eq(d, g);
		bool edge_up = edge && df(fv, g) >= LV2 * df(h, c) && !eq(e, c) && !eq(b, c);

		// Linhas do canto (45°, 30° e 60°), com a largura de um pixel da tela para antisserrilhar.
		float l45 = f.x + f.y, l30 = f.y + 0.5 * f.x, l60 = f.y * 0.5 + f.x;
		float w = fwidth(l45);
		float a = edge ? smoothstep(1.5 - w, 1.5 + w, l45) : 0.0;
		a = max(a, edge_left ? smoothstep(1.0 - w, 1.0 + w, l30) : 0.0);
		a = max(a, edge_up ? smoothstep(1.0 - w, 1.0 + w, l60) : 0.0);
		vec4 px = df(e, fv) <= df(e, h) ? pF : pH;
		COLOR = mix(pE, px, a);
	}
}
