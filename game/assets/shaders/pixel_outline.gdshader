shader_type canvas_item;

// Shared by all zombie sprites, including pooled and dying sprites. Alpha is
// the night switch; RGB is compensated for the active CanvasModulate palette.
uniform vec4 outline_color = vec4(0.0);
uniform vec2 frame_size = vec2(16.0);
uniform vec2 sprite_offset = vec2(0.0, -5.0);
varying flat vec2 frame_origin;
varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
	vec2 corner = sign(VERTEX - sprite_offset);
	vec2 local_uv = (VERTEX - sprite_offset) / frame_size + vec2(0.5);
	frame_origin = UV - local_uv * frame_size * TEXTURE_PIXEL_SIZE;
	// T-102 cells touch their lower edge (brutes also touch the sides/top).
	// Expand exactly one source pixel, preserving the original texture mapping.
	if (outline_color.a > 0.0) {
		VERTEX += corner;
		UV += corner * TEXTURE_PIXEL_SIZE;
	}
}

float frame_mask(vec2 uv, vec2 pixel_size) {
	vec2 cell = (uv - frame_origin) / pixel_size;
	// Never sample an adjacent atlas frame or clamp the outer texture edge.
	if (any(lessThan(cell, vec2(0.0))) || any(greaterThanEqual(cell, frame_size))) {
		return 0.0;
	}
	return 1.0;
}

void fragment() {
	// Leave the default shaded sprite path untouched during the day.
	if (outline_color.a > 0.0) {
		vec4 source = texture(TEXTURE, UV) * frame_mask(UV, TEXTURE_PIXEL_SIZE);
		float edge = 0.0;
		if (source.a < 0.5) {
			for (int y = -1; y <= 1; y++) {
				for (int x = -1; x <= 1; x++) {
					vec2 neighbour_uv = UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE;
					edge = max(edge, texture(TEXTURE, neighbour_uv).a * frame_mask(neighbour_uv, TEXTURE_PIXEL_SIZE));
				}
			}
		}
		COLOR = mix(vec4(outline_color.rgb, edge * outline_color.a), source, source.a) * vertex_color;
	}
}
