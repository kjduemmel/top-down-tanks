#[compute]
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, r32ui) uniform uimage2D depth_img;
layout(set = 0, binding = 1, rgba8) uniform readonly image2D albedo_img;
layout(set = 0, binding = 2, rgba8) uniform readonly image2D normal_img;
layout(set = 0, binding = 3, rgba8) uniform image2D lit_img;

struct Light {
    vec4 pos_type;   // x_screen_px, y_screen_px, z_norm, type
    vec4 dir_param;  // dx_view, dy_view, dz_view, inner_cos   (view-space dir)
    vec4 col_range;  // r,g,b,range   (range in VIEW units)
    vec4 extra;      // intensity, outer_cos, falloff, shadow_steps
};
layout(std430, set = 1, binding = 0) readonly buffer LightsBuf { Light L[]; } lights;

layout(push_constant, std430) uniform Push {
    ivec2 size;
    int light_count;
    float ambient;
} pc;

float u32_to_norm(uint u) { return float(u) / 4294967295.0; }

// 3 heightmap bits = 1 vertical pixel
const float Z_BITS_PER_PX = 3.0;
const float ZPX_SCALE = 255.0 / Z_BITS_PER_PX; // z_px = z_norm * (255/3)

const float COS_T = 2.0 / 3.0;
const float SIN_T = 0.7453559925; // sqrt(5)/3

vec3 tilted_to_world(vec3 v) { // Rx(-theta)
    return vec3(
        v.x,
        COS_T * v.y + SIN_T * v.z,
       -SIN_T * v.y + COS_T * v.z
    );
}

vec3 decode_normal_view(vec3 enc) {
    vec3 n = enc * 2.0 - 1.0;
    n.y *= -1.0;      // flip green
    return normalize(n);
}

vec3 pos_view_from_screen(ivec2 p, float z_norm) {
    float z_px = z_norm * ZPX_SCALE;
    float x = float(p.x);
    float y = (float(p.y) + (z_px)) * 1.5;
    float z = z_px;
    return vec3(x, y, z);
}

// Directional shadow march in VIEW space along screen grid; we compare in z_norm units.
float shadow_dir(ivec2 p, float zP_norm, vec3 Ldir_view, int steps) {
    if (steps <= 0) return 1.0;

    vec2 lxy = Ldir_view.xy;
    float lxy_len = length(lxy);
    if (lxy_len < 1e-5) return 1.0;

    // march 1 screen pixel per step towards the light direction
    vec2 step_xy = -lxy / lxy_len;

    // dz per 1 screen pixel step, in VIEW z_px units:
    // if Ldir_view is normalized in VIEW units, then per horizontal step:
    float Lh = max(length(Ldir_view.xy), 1e-5);
    float step_z_px = (-Ldir_view.z / Lh) * 1.0; // 1.0 = one screen pixel

    // convert dz_px back to normalized depth units so it can be compared to depth_img
    float step_z_norm = step_z_px / ZPX_SCALE;

    vec2 q = vec2(p);
    float zRay = zP_norm;

    const float BIAS = 1.0 / 4096.0;

    for (int i = 0; i < steps; i++) {
        q += step_xy;
        zRay += step_z_norm;

        ivec2 qi = ivec2(round(q));
        if (qi.x < 0 || qi.y < 0 || qi.x >= pc.size.x || qi.y >= pc.size.y)
            break;

        float zS = u32_to_norm(imageLoad(depth_img, qi).r);
        if (zS > zRay + BIAS) return 0.0;
    }
    return 1.0;
}

void main() {
    ivec2 p = ivec2(gl_GlobalInvocationID.xy);
    if (p.x >= pc.size.x || p.y >= pc.size.y) return;

    vec4 a = imageLoad(albedo_img, p);
    if (a.a < 0.5) { imageStore(lit_img, p, vec4(0)); return; }

    float zP_norm = u32_to_norm(imageLoad(depth_img, p).r);

    // View-space pixel position
    vec3 P = pos_view_from_screen(p, zP_norm);

    // View-space normal (angle with camera)
    vec3 N = decode_normal_view(imageLoad(normal_img, p).xyz);
    N = normalize(tilted_to_world(N));

    vec3 out_rgb = a.rgb * pc.ambient;

    for (int i = 0; i < pc.light_count; i++) {
        Light li = lights.L[i];
        int type = int(li.pos_type.w + 0.5);

        vec3 Ldir;   // direction from pixel toward light
        float att = 1.0;

        if (type == 0) {
            // Directional: li.dir_param.xyz must already be view-space
            Ldir = normalize(li.dir_param.xyz);
        } else {
            float zL_px = li.pos_type.z * ZPX_SCALE;
            vec3 LP = vec3(
                li.pos_type.x,
                (li.pos_type.y * 1.5) - zL_px,
                zL_px
            );
            vec3 toL = LP - P;               // view-space delta
            float dist = length(toL);
            if (dist < 1e-4) continue;

            Ldir = toL / dist;

            float range = li.col_range.w;    // range in view units (pixels)
            if (range > 0.0) {
                float x = clamp(1.0 - dist / range, 0.0, 1.0);
                float falloff = max(li.extra.z, 0.001);
                att = pow(x, falloff);
            }

            if (type == 2) {
                vec3 spot_dir = normalize(li.dir_param.xyz); // view-space
                float inner_cos = li.dir_param.w;
                float outer_cos = li.extra.y;

                float cd = dot(spot_dir, normalize(-toL));
                float cone = smoothstep(outer_cos, inner_cos, cd);
                att *= cone;
            }
        }

        float ndl = max(dot(N, Ldir), 0.0);
        if (ndl <= 0.0) continue;

        int shadow_steps = int(li.extra.w + 0.5);
        float shadow = 1.0;
        if (shadow_steps > 0 && type == 0) {
            shadow = shadow_dir(p, zP_norm, normalize(li.dir_param.xyz), shadow_steps);
        }

        vec3 col = li.col_range.xyz;
        float intensity = li.extra.x;

        out_rgb += a.rgb * (col * (intensity * att * ndl * shadow));
    }

    imageStore(lit_img, p, vec4(out_rgb, 1.0));
}