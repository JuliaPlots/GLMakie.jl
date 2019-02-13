{{GLSL_VERSION}}
{{GLSL_EXTENSIONS}}
{{SUPPORTED_EXTENSIONS}}


struct Nothing{ //Nothing type, to encode if some variable doesn't contain any data
    bool _; //empty structs are not allowed
};

#define CIRCLE            0
#define RECTANGLE         1
#define ROUNDED_RECTANGLE 2
#define DISTANCEFIELD     3
#define TRIANGLE          4

// Half width of antialiasing smoothstep
#define ALIASING_CONST    0.8
#define M_SQRT_2          1.4142135


{{distancefield_type}}  distancefield;
{{image_type}}          image;

uniform float           stroke_width;
uniform float           glow_width;
uniform int             shape; // shape is a uniform for now. Making them a varying && using them for control flow is expected to kill performance
uniform vec2            resolution;
uniform bool            transparent_picking;

flat in vec2            f_scale;
flat in vec4            f_color;
flat in vec4            f_bg_color;
flat in vec4            f_stroke_color;
flat in vec4            f_glow_color;
flat in uvec2           f_id;
flat in int             f_primitive_index;
in vec2                 f_uv;
flat in vec4            f_uv_offset;



float aastep(float threshold1, float value) {
    float afwidth = length(vec2(dFdx(value), dFdy(value))) * ALIASING_CONST;
    return smoothstep(threshold1-afwidth, threshold1+afwidth, value);
}
float aastep(float threshold1, float threshold2, float value) {
    float afwidth = length(vec2(dFdx(value), dFdy(value))) * ALIASING_CONST;
    return smoothstep(threshold1-afwidth, threshold1+afwidth, value) -
           smoothstep(threshold2-afwidth, threshold2+afwidth, value);
}

float step2(float edge1, float edge2, float value){
    return min(step(edge1, value), 1-step(edge2, value));
}

float triangle(vec2 P){
    P /= 2;
    float x = M_SQRT_2/2.0 * (P.x - P.y);
    float y = M_SQRT_2/2.0 * (P.x + P.y);
    float r1 = max(abs(x), abs(y)) - 1./(2*M_SQRT_2);
    float r2 = P.y;
    return -max(r1,r2);
}
float circle(vec2 uv){
    return 1-length(uv);
}
float rectangle(vec2 uv){
    uv /= 2; uv += 0.5;
    vec2 d = max(-uv, uv-vec2(1));
    return -((length(max(vec2(0.0), d)) + min(0.0, max(d.x, d.y))));
}
float rounded_rectangle(vec2 uv, vec2 tl, vec2 br){
    uv /= 2; uv += 0.5;
    vec2 d = max(tl-uv, uv-br);
    return -((length(max(vec2(0.0), d)) + min(0.0, max(d.x, d.y)))-tl.x);
}

void fill(vec4 fillcolor, Nothing image, vec2 uv, float infill, inout vec4 color){
    color = mix(color, fillcolor, infill);
}
void fill(vec4 c, sampler2D image, vec2 uv, float infill, inout vec4 color){
    color.rgba = mix(color, texture(image, uv.yx), infill);
}
void fill(vec4 c, sampler2DArray image, vec2 uv, float infill, inout vec4 color){
    color = mix(color, texture(image, vec3(uv.yx, f_primitive_index)), infill);
}


void stroke(vec4 strokecolor, float signed_distance, float half_stroke, inout vec4 color){
    if (half_stroke != 0.0){
        float t = aastep(min(half_stroke, 0.0), max(half_stroke, 0.0), signed_distance);
        color = mix(color, strokecolor, t);
    }
}

void glow(vec4 glowcolor, float signed_distance, float inside, inout vec4 color){
    if (glow_width > 0.0){
        float lolz = (f_scale.x+f_scale.y);
        float outside = (abs(signed_distance)-f_scale.x)/f_scale.y;
        float alpha = 1-outside;
        color = mix(vec4(glowcolor.rgb, glowcolor.a*alpha), color, inside);
    }
}

float get_distancefield(sampler2D distancefield, vec2 uv){
    return -texture(distancefield, uv).r;
}
float get_distancefield(Nothing distancefield, vec2 uv){
    return 0.0;
}

void write2framebuffer(vec4 color, uvec2 id);

void main(){
    float signed_distance = 0.0;

    vec2 uv_offset = mix(f_uv_offset.xy, f_uv_offset.zw, clamp(0.5*(f_uv+1.0), 0.0, 1.0));

    if(shape == CIRCLE)
        signed_distance = circle(f_uv);
    else if(shape == DISTANCEFIELD)
        signed_distance = get_distancefield(distancefield, uv_offset);
    else if(shape == ROUNDED_RECTANGLE)
        signed_distance = rounded_rectangle(f_uv, vec2(0.2), vec2(0.8));
    else if(shape == RECTANGLE)
        signed_distance = 1.0;
    else if(shape == TRIANGLE)
        signed_distance = triangle(f_uv);

    float half_stroke = -f_scale.x;
    float inside_start = max(half_stroke, 0.0);
    float inside = aastep(inside_start, signed_distance);
    vec4 final_color = f_bg_color;

    fill(f_color, image, uv_offset, inside, final_color);
    stroke(f_stroke_color, signed_distance, half_stroke, final_color);
    glow(f_glow_color, signed_distance, aastep(-f_scale.x, signed_distance), final_color);
    // TODO: In 3D, arguably should discard fragments outside the sprite
    //if (final_color == f_bg_color)
    //    discard;
    write2framebuffer(final_color, f_id);
}
