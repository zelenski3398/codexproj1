shader_type spatial;
render_mode cull_back;
uniform sampler2D surface_detail : repeat_enable, filter_linear_mipmap;
varying vec3 world_point;
void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    // Two depth-buffer units of polygon bias keep the exactly terrain-draped
    // skin stable at flight distances without lifting its geometry/physics.
    vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX,1.0);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    clip.z += 0.0000003 * clip.w;
#else
    clip.z += 0.00000015 * clip.w;
#endif
    POSITION = clip;
}
void fragment() {
    float earth = texture(surface_detail, world_point.xz * 0.11).g;
    // GLB vertex colours are stored in sRGB; ALBEDO uses linear colour.
    // Decode once to keep neighbouring plots earthy rather than pastel tiles.
    ALBEDO = pow(COLOR.rgb, vec3(2.2)) * (0.85 + earth * 0.23);
    ROUGHNESS = 0.98;
}
