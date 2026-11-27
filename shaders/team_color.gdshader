shader_type canvas_item;
// Recolours a wizard's red robe for the other team colours by rotating the
// hue of strongly red pixels only. Skin, the staff glow and the outline
// fall outside the red band and stay as drawn.

uniform float hue_shift : hint_range(0.0, 1.0) = 0.0;
// Death: 0 = whole, 1 = gone. Texels vanish in a random order with a hot
// orange rim just before they go (visual pass 1).
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;

varying vec4 tint; // modulate / self_modulate

void vertex() {
	tint = COLOR;
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (hue_shift > 0.0) {
		vec3 hsv = rgb2hsv(c.rgb);
		// Red band: hue above ~306 deg or below ~13 deg, and saturated.
		bool red = (hsv.x > 0.85 || hsv.x < 0.035) && hsv.y > 0.45;
		if (red) {
			hsv.x = fract(hsv.x + hue_shift);
			c.rgb = hsv2rgb(hsv);
		}
	}
	COLOR = c * tint;
	if (dissolve > 0.0) {
		vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
		float n = fract(sin(dot(texel, vec2(12.9898, 78.233))) * 43758.5453);
		if (n < dissolve) {
			COLOR.a = 0.0;
		} else if (n < dissolve + 0.12) {
			COLOR.rgb = mix(vec3(1.0, 0.45, 0.1), vec3(1.0, 0.85, 0.4), (n - dissolve) / 0.12);
		}
	}
}
