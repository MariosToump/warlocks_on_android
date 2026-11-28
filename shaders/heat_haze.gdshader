shader_type canvas_item;
// Heat shimmer over the lava (visual pass 1). Drawn over the arena tiles and
// under the wizards: it shifts the screen sideways in thin wavy bands, only
// where both the pixel and its shifted source are lava-coloured, so the stone
// and the island edge stay put. Whole-pixel steps keep the pixel-art look.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float strength = 2.0; // screen px
uniform float speed = 3.0;

float warm(vec3 c) {
	return smoothstep(0.12, 0.35, c.r - c.b) * smoothstep(0.35, 0.6, c.r);
}

void fragment() {
	vec4 c = texture(screen_tex, SCREEN_UV);
	float wc = warm(c.rgb);
	if (wc <= 0.0) {
		// Not lava: mixing by 0 below would give c exactly, so skip the
		// second read (perf 2026-11-28).
		COLOR = vec4(c.rgb, 1.0);
	} else {
		float band = floor(FRAGCOORD.y / 3.0);
		float off = round(sin(band * 0.35 + TIME * speed) * strength);
		vec4 d = texture(screen_tex, SCREEN_UV + vec2(off, 0.0) * SCREEN_PIXEL_SIZE);
		COLOR = vec4(mix(c.rgb, d.rgb, wc * warm(d.rgb)), 1.0);
	}
}
