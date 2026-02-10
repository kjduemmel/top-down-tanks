#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, r32ui) uniform uimage2D depth_img;
layout(set = 0, binding = 1, rgba8) uniform image2D color_img;

layout(push_constant, std430) uniform Push {
    ivec2 size;
} pc;

void main() {
    ivec2 p = ivec2(gl_GlobalInvocationID.xy);
    if (p.x >= pc.size.x || p.y >= pc.size.y) return;

    imageStore(depth_img, p, uvec4(0,0,0,0));
    imageStore(color_img, p, vec4(0.0,0.0,0.0,0.0));
}
