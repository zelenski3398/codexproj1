shader_type spatial;
render_mode cull_back, diffuse_burley, specular_disabled;
uniform sampler2D surface_detail : filter_linear_mipmap, repeat_enable;
uniform vec3 ground_color : source_color = vec3(0.34, 0.305, 0.225);
varying vec3 ground_position;
void vertex() {
    ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float grain = texture(surface_detail, ground_position.xz / 12.0).g;
    ALBEDO = ground_color * (0.94 + grain * 0.12);
    ROUGHNESS = 1.0;
}
