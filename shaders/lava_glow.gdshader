shader_type canvas_item;
// Animates lava pixels on the arena tile layer: a slow, rolling brightness
// pulse on warm (orange/red) pixels only, so the stone stays untouched.
// Colours are quantised to keep the pixel-art look.

uniform float speed = 1.2;
uniform float strength = 0.22;
uniform float wave_scale = 0.045;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// "How lava-ish is this pixel": red clearly above blue, and bright.
	float warm = smoothstep(0.12, 0.35, c.r - c.b) * smoothstep(0.35, 0.6, c.r);
	vec2 p = floor(world_pos / 4.0) * 4.0; // move in 4px steps
	float w = sin(p.x * wave_scale + TIME * speed)
			+ sin(p.y * wave_scale * 1.3 - TIME * speed * 0.8)
			+ sin((p.x + p.y) * wave_scale * 0.6 + TIME * speed * 0.5);
	w = floor(w * 2.0) / 6.0; // quantise to a few bands, range ~[-1, 1]
	vec3 lit = c.rgb * (1.0 + w * strength) + vec3(0.08, 0.03, 0.0) * max(w, 0.0);
	COLOR = vec4(mix(c.rgb, lit, warm), c.a);
}
