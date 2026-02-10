#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, r32ui) uniform uimage2D depth_img;
layout(set = 0, binding = 1, rgba8) uniform image2D color_img;

layout(set = 1, binding = 0) uniform sampler2D albedo_tex;
layout(set = 1, binding = 1) uniform sampler2D height_tex;

layout(push_constant, std430) uniform Push {
    ivec2  out_size;       //  8
    ivec2  spr_pos;        // 16
    ivec2  spr_size;       // 24
    ivec2  sheet_px;       // 32  (texture width/height in pixels)
    ivec2  frames;         // 40  (hframes, vframes)
    ivec2  frame_xy;       // 48  (frame column,row)
    float  base_depth;     // 52
    float  height_scale;   // 56
    // padded to 64
} pc;

uint depth_to_u32(float d) {
    d = clamp(d, 0.0, 1.0);
    return uint(d * 4294967295.0);
}

void main() {
    ivec2 local = ivec2(gl_GlobalInvocationID.xy);
    if (local.x >= pc.spr_size.x || local.y >= pc.spr_size.y) return;

    ivec2 p = pc.spr_pos + local;
    if (p.x < 0 || p.y < 0 || p.x >= pc.out_size.x || p.y >= pc.out_size.y) return;

    // local UV inside the rendered sprite rect (0..1)
    vec2 uv_local = (vec2(local) + vec2(0.5)) / vec2(pc.spr_size);

    // Frame size on the sheet in pixels
    ivec2 frm_count = max(pc.frames, ivec2(1, 1));
    vec2 frame_px = vec2(pc.sheet_px) / vec2(frm_count);

    // Convert local uv to pixel coords inside the chosen frame
    vec2 in_frame_px = uv_local * frame_px;

    // Top-left of the frame on the sheet in pixels
    vec2 frame_origin_px = vec2(pc.frame_xy) * frame_px;

    // Final UV on the whole sheet
    vec2 uv = (frame_origin_px + in_frame_px) / vec2(pc.sheet_px);

    vec4 a = texture(albedo_tex, uv);
    if (a.a < 0.5) return;


    float h = texture(height_tex, uv).r;
    float d = pc.base_depth + h * pc.height_scale;
    uint new_d = depth_to_u32(d);

    uint old_d = imageLoad(depth_img, p).r;

    while (new_d > old_d) {
        uint prev = imageAtomicCompSwap(depth_img, p, old_d, new_d);
        if (prev == old_d) {
            imageStore(color_img, p, vec4(a.rgb, 1.0));
            return;
        }
        old_d = prev;
    }
}

