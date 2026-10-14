shader_type spatial;
render_mode cull_back, diffuse_burley, specular_disabled;
uniform sampler2D surface_detail : filter_linear_mipmap, repeat_enable;
uniform vec3 ground_color : source_color = vec3(0.34, 0.305, 0.225);
// Access roads are painted into the existing apron surface, never overlays.
uniform int access_count = 0;
uniform vec2 access_start[8];
uniform vec2 access_end[8];
uniform vec2 access_origin = vec2(0.0);
uniform float access_half_width = 2.25;
uniform vec3 road_color : source_color = vec3(0.40, 0.365, 0.30);
varying vec2 apron_position;
varying vec3 ground_position;
void vertex() {
    apron_position = VERTEX.xz + access_origin;
    ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float grain = texture(surface_detail, ground_position.xz / 12.0).g;
    vec3 color = ground_color * (0.94 + grain * 0.12);
    float nearest = 100000.0;
    for (int i = 0; i < 8; i++) {
        if (i >= access_count) { break; }
        vec2 segment = access_end[i] - access_start[i];
        float t = clamp(dot(apron_position - access_start[i], segment) / max(dot(segment, segment), 0.001), 0.0, 1.0);
        nearest = min(nearest, distance(apron_position, access_start[i] + segment * t));
    }
    float lane = 1.0 - smoothstep(access_half_width, access_half_width + 1.5, nearest);
    float road_grain = texture(surface_detail, ground_position.xz / 14.0).g;
    vec3 road = road_color * (0.97 + (road_grain - 0.5) * 0.14);
    ALBEDO = mix(color, road, lane);
    ROUGHNESS = 1.0;
}
