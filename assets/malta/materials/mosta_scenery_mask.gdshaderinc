// The wartime site replaces rural batches only inside its traced footprint.
uniform sampler2D mosta_scenery_mask : filter_linear, repeat_disable;
uniform vec2 mosta_mask_min;
uniform float mosta_mask_span = 0.0;

bool inside_mosta_reconstruction(vec2 world_xz) {
    if (mosta_mask_span <= 0.0) { return false; }
    vec2 uv = (world_xz - mosta_mask_min) / mosta_mask_span;
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
        return false;
    }
    return texture(mosta_scenery_mask, uv).r > 0.51;
}
