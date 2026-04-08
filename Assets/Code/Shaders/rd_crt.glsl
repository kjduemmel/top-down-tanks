#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba8) uniform readonly image2D src_img;
layout(set = 0, binding = 1, rgba8) uniform writeonly image2D dst_img;

layout(push_constant, std430) uniform Params {
	ivec2 src_size;
	ivec2 dst_size;
} pc;

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float gaussian(float x, float sigma) {
	return exp(-(x * x) / (2.0 * sigma * sigma));
}

float scanline_mask(float y_src, float brightness) {
	float row_center = floor(y_src) + 0.5;
	float dy = y_src - row_center;

	// broader line so the dark gap is narrower
	float line = gaussian(dy, 0.62);

	float floor_amt = mix(0.38, 0.78, sqrt(clamp(brightness, 0.0, 1.0)));

	return mix(floor_amt, 1.0, line);
}

float slot_mask(vec2 frag_pos) {
	// subtle grayscale slot mask
	float col = 0.88 + 0.12 * step(0.5, fract(frag_pos.x / 3.0));
	float row = 0.96 + 0.04 * step(0.5, fract(frag_pos.y / 2.0));
	return col * row;
}

void main() {
	ivec2 dst_xy = ivec2(gl_GlobalInvocationID.xy);

	if (dst_xy.x >= pc.dst_size.x || dst_xy.y >= pc.dst_size.y) {
		return;
	}

	vec2 uv = (vec2(dst_xy) + vec2(0.5)) / vec2(pc.dst_size);
	vec2 src_pos = uv * vec2(pc.src_size);

	ivec2 center_px = ivec2(floor(src_pos));

	vec3 base = vec3(0.0);
	float base_w = 0.0;

	vec3 bloom = vec3(0.0);

	// core with slight horizontal smear
	for (int ox = -2; ox <= 2; ox++) {
		ivec2 sp = center_px + ivec2(ox, 0);

		if (sp.x < 0 || sp.y < 0 || sp.x >= pc.src_size.x || sp.y >= pc.src_size.y) {
			continue;
		}

		vec3 c = imageLoad(src_img, sp).rgb;

		float px_center_x = float(sp.x) + 0.5;
		float dx = src_pos.x - px_center_x;

		float w = gaussian(dx, 0.72);

		base += c * w;
		base_w += w;
	}

	// brighter pixels bloom more, but dim ones still bloom a little
	for (int ox = -5; ox <= 5; ox++) {
		ivec2 sp = center_px + ivec2(ox, 0);

		if (sp.x < 0 || sp.y < 0 || sp.x >= pc.src_size.x || sp.y >= pc.src_size.y) {
			continue;
		}

		vec3 c = imageLoad(src_img, sp).rgb;
		float b = luma(c);

		float px_center_x = float(sp.x) + 0.5;
		float dx = src_pos.x - px_center_x;

		float w = gaussian(dx, 1.65);

		// was b*b; this gives dimmer lights some bleed too
		float glow = pow(b, 1.35);

		bloom += c * w * glow;
	}

	vec3 col = vec3(0.0);
	if (base_w > 0.0) {
		col = base / base_w;
	}

	col += bloom * 0.34;

	float bright = clamp(luma(col), 0.0, 1.0);
	col *= scanline_mask(src_pos.y, bright);

	// subtle slot mask after scanlines
	col *= slot_mask(vec2(dst_xy));

	col *= 1.38;

	imageStore(dst_img, dst_xy, vec4(clamp(col, 0.0, 1.0), 1.0));
}