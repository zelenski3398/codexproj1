shader_type spatial;
render_mode cull_back;
#include "res://assets/malta/materials/mosta_scenery_mask.gdshaderinc"
varying vec2 world_xz;
void vertex() {
    world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
    if (inside_mosta_reconstruction(world_xz)) { discard; }
    ALBEDO = pow(COLOR.rgb, vec3(2.2)) * 0.48;
    ROUGHNESS = 1.0;
}
