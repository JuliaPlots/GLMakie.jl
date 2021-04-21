{{GLSL_VERSION}}

out vec4 fragment_color;

in vec4 o_view_pos;
in vec3 o_normal;

void write2framebuffer(vec4 color, uvec2 id){
    // For FXAA & SSAO
    fragment_color = color;
}
