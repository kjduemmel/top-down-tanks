#[compute]
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, r32ui) uniform uimage2D depth_img;
layout(set = 0, binding = 1, rgba8) uniform readonly image2D albedo_img;
layout(set = 0, binding = 2, rgba8) uniform readonly image2D normal_img;
layout(set = 0, binding = 3, rgba8) uniform image2D lit_img;

struct Light {
    vec4 pos_type;   // x_screen_px, y_screen_px, z_norm, type
    vec4 dir_param;  // dx_view, dy_view, dz_view, inner_cos
    vec4 col_range;  // r,g,b,range
    vec4 extra;      // intensity, outer_cos, falloff, shadow_enabled
};
layout(std430, set = 1, binding = 0) readonly buffer LightsBuf {
    Light L[];
} lights;

struct ShadowPlane {
    vec4 center_flags;   // center.xyz, two_sided
    vec4 axis_u_halfu;   // axis_u.xyz, half_u
    vec4 axis_v_halfv;   // axis_v.xyz, half_v
    vec4 extra;          // x = strength, y = shape_type, z = softness, w = unused
};
layout(std430, set = 2, binding = 0) readonly buffer ShadowPlanesBuf {
    ShadowPlane P[];
} shadow_planes;

// Shared shadow tint texture.
// RGB = shadow tint color, A = shadow strength/opacity.
layout(set = 2, binding = 1) uniform sampler2D shadow_tint_tex;

// Editor-friendly profile mask, usually a Godot CurveTexture.
// For shape_type 1: R = side top limit at uv.x.
layout(set = 2, binding = 2) uniform sampler2D shadow_profile_tex;

layout(push_constant, std430) uniform Push {
    ivec2 size;
    int light_count;
    int plane_count;
    float ambient;
    float _pad0;
    float _pad1;
    float _pad2;
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
    float x = float(p.x) + 1;
    float y = (float(p.y) + 1 + z_px) * 1.5;
    float z = z_px / SIN_T;
    return vec3(x, y, z);
}

float side_profile_mask(vec2 uv, float softness) {
    // CurveTexture convention:
    // uv.x = along the side/profile
    // sampled red = max allowed uv.y/top edge
    // below the curve exists; above it is cut away.
    float top_limit = texture(shadow_profile_tex, vec2(uv.x, 0.5)).r;
    float d = top_limit - uv.y;
    return smoothstep(-softness, softness, d);
}

vec3 ray_plane_shadow_filter(vec3 ro, vec3 rd, float t_max, ShadowPlane pl) {
    vec3 C = pl.center_flags.xyz;
    float two_sided = pl.center_flags.w;

    vec3 U = normalize(pl.axis_u_halfu.xyz);
    float half_u = pl.axis_u_halfu.w;

    vec3 V = normalize(pl.axis_v_halfv.xyz);
    float half_v = pl.axis_v_halfv.w;

    vec3 N = normalize(cross(U, V));
    float denom = dot(rd, N);

    if (abs(denom) < 1e-5) {
        return vec3(1.0);
    }

    if (two_sided < 0.5 && denom > 0.0) {
        return vec3(1.0);
    }

    float t = dot(C - ro, N) / denom;
    
    const float SELF_SHADOW_SKIP = 1.0;

    if (t <= SELF_SHADOW_SKIP || t >= t_max - 0.001) {
        return vec3(1.0);
    }

    vec3 H = ro + rd * t;
    vec3 rel = H - C;

    float u = dot(rel, U);
    float v = dot(rel, V);

    const float EDGE_EPS = 0.01;

    if (u <= -half_u || u > half_u) return vec3(1.0);
    if (v <= -half_v || v > half_v) return vec3(1.0);

    vec2 uv = vec2(u / half_u, v / half_v) * 0.5 + 0.5;
    uv.y = 1.0 - uv.y;

    float strength = clamp(pl.extra.x, 0.0, 1.0);
    int shape_type = int(pl.extra.y + 0.5);
    float softness = max(pl.extra.z, 0.0001);

    float shape_mask = 1.0;

    if (shape_type == 1) {
        // Side-wedge/profile plane. Use a CurveTexture to decide where the face exists.
        shape_mask = side_profile_mask(uv, softness);
    }

    vec4 shadow_tex = texture(shadow_tint_tex, uv);
    vec3 shadow_tint = clamp(shadow_tex.rgb, vec3(0.0), vec3(1.0));
    float shadow_alpha = clamp(shadow_tex.a * shape_mask * strength, 0.0, 1.0);

    // vec3(1.0) = no light filtering.
    // shadow_tint = fully shadowed/tinted color filter.
    return mix(vec3(1.0), shadow_tint, shadow_alpha);
}

vec3 light_visibility_by_planes(vec3 P, vec3 Ldir, float max_dist) {
    vec3 ro = P;
    vec3 visibility = vec3(1.0);

    for (int i = 0; i < pc.plane_count; i++) {
        visibility *= ray_plane_shadow_filter(ro, Ldir, max_dist, shadow_planes.P[i]);

        if (max(visibility.r, max(visibility.g, visibility.b)) <= 0.001) {
            return vec3(0.0);
        }
    }

    return visibility;
}

void main() {
    ivec2 p = ivec2(gl_GlobalInvocationID.xy);
    if (p.x >= pc.size.x || p.y >= pc.size.y) return;

    vec4 a = imageLoad(albedo_img, p);
    if (a.a < 0.5) {
        imageStore(lit_img, p, vec4(0));
        return;
    }

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
        float max_dist = 4096.0;
        int shadow_enabled = int(li.extra.w + 0.5);

        if (type == 0) {
            // Directional: li.dir_param.xyz must already be view-space
            Ldir = normalize(li.dir_param.xyz);
            max_dist = 4096.0;

        } else {
            float zL_px = li.pos_type.z * ZPX_SCALE;
            vec3 LP = vec3(
                li.pos_type.x,
                (li.pos_type.y * 1.5) - zL_px,
                zL_px / SIN_T
            );
            vec3 toL = LP - P;               // view-space delta
            float dist = length(toL);
            if (dist < 1e-4) continue;

            Ldir = toL / dist;
            max_dist = dist;

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

        vec3 visibility = vec3(1.0);
        if (pc.plane_count > 0) {
            visibility = light_visibility_by_planes(P, Ldir, max_dist);
            if (max(visibility.r, max(visibility.g, visibility.b)) <= 0.001) {
                continue;
            }
        }

        float ndl = max(dot(N, Ldir), 0.0);
        if (ndl <= 0.0) continue;

        vec3 col = li.col_range.xyz;
        float intensity = li.extra.x;

        out_rgb += a.rgb * (col * visibility * (intensity * att * ndl));
    }

    imageStore(lit_img, p, vec4(out_rgb, 1.0));
}
