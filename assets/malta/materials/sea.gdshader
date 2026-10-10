shader_type spatial;
render_mode cull_back, diffuse_burley, specular_disabled;
uniform sampler2D coast_distance : filter_linear_mipmap, repeat_disable;
uniform vec2 map_min = vec2(-21000.0, -18500.0);
uniform vec2 map_span = vec2(39000.0, 36000.0);
uniform vec3 deep_color : source_color = vec3(0.025, 0.145, 0.22);
uniform vec3 shallow_color : source_color = vec3(0.035, 0.215, 0.245);
uniform float ripple_strength : hint_range(0.0, 0.1) = 0.025;
varying vec3 water_position;
void vertex() {
    water_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec2 uv = (water_position.xz - map_min) / map_span;
    float inside = step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
    vec2 coast = texture(coast_distance, clamp(uv, vec2(0.0), vec2(1.0))).rg;
    float shallow = (1.0 - smoothstep(0.0, 1.0, coast.g)) * (1.0 - coast.r) * inside;
    float ripples = sin(water_position.x * 0.018 + TIME * 0.18) * sin(water_position.z * 0.013 - TIME * 0.12);
    ALBEDO = mix(deep_color, shallow_color, shallow * 0.65) * (1.0 + ripples * ripple_strength);
    ROUGHNESS = 0.88;
    METALLIC = 0.0;
}
