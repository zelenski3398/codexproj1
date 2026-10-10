shader_type spatial;
render_mode cull_back, diffuse_burley, specular_disabled;

// Compatibility/WebGL 2: no displacement, screen/depth textures or runtime GIS.
uniform sampler2D landcover : filter_linear_mipmap, repeat_disable;
uniform sampler2D surface_detail : filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff_detail : filter_linear_mipmap, repeat_enable;
uniform vec2 map_min = vec2(-21000.0, -18500.0);
uniform vec2 map_span = vec2(39000.0, 36000.0);
uniform vec3 limestone_color : source_color = vec3(0.45, 0.38, 0.27);
uniform vec3 soil_color : source_color = vec3(0.31, 0.20, 0.135);
uniform vec3 cultivated_color : source_color = vec3(0.22, 0.265, 0.135);
uniform vec3 scrub_color : source_color = vec3(0.30, 0.29, 0.18);
uniform vec3 wall_color : source_color = vec3(0.48, 0.425, 0.315);
uniform float detail_metres : hint_range(4.0, 40.0) = 14.0;
uniform float detail_fade_start : hint_range(100.0, 2000.0) = 400.0;
uniform float detail_fade_end : hint_range(500.0, 6000.0) = 1800.0;
uniform float cliff_slope_start : hint_range(0.0, 1.0) = 0.12;
uniform float cliff_slope_end : hint_range(0.0, 1.0) = 0.5;
uniform float wall_strength : hint_range(0.0, 1.0) = 0.55;
uniform float terrace_strength : hint_range(0.0, 0.3) = 0.08;
varying vec3 terrain_position;

void vertex() {
    terrain_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 uv = (terrain_position.xz - map_min) / map_span;
    vec4 parcel = texture(landcover, uv);
    // The supplied GLB has no NORMAL buffer. Derive each existing triangle's
    // normal in the fragment shader instead of editing/rebuilding that mesh.
    // Derivatives are core in WebGL 2 and Godot's Compatibility renderer.
    vec3 n = normalize(cross(dFdx(terrain_position), dFdy(terrain_position)));
    if (n.y < 0.0) { n = -n; }
    NORMAL = normalize(mat3(VIEW_MATRIX) * n);
    float slope = 1.0 - abs(n.y);
    float cliff = smoothstep(cliff_slope_start, cliff_slope_end, slope);
    // Parcel classes, not height bands, establish cultivated/dry/scrub regions.
    vec3 color = limestone_color * max(0.0, 1.0 - parcel.r - parcel.g - parcel.b);
    color += soil_color * parcel.r + cultivated_color * parcel.g + scrub_color * parcel.b;
    float distance_to_camera = distance(terrain_position, CAMERA_POSITION_WORLD);
    float detail_fade = 1.0 - smoothstep(detail_fade_start, detail_fade_end, distance_to_camera);
    vec4 detail = texture(surface_detail, terrain_position.xz / detail_metres);
    float grain = detail.r * (1.0 - parcel.r - parcel.g - parcel.b);
    grain += detail.g * parcel.r + mix(detail.a, detail.b, 0.3) * parcel.g + detail.b * parcel.b;
    color *= 1.0 + (grain - 0.5) * 0.28 * detail_fade;
    // Side projections prevent rock layers from stretching up vertical cliffs.
    float side_blend = abs(n.x) / max(abs(n.x) + abs(n.z), 0.001);
    float strata = mix(texture(cliff_detail, terrain_position.xy / detail_metres).r,
                       texture(cliff_detail, terrain_position.zy / detail_metres).r, side_blend);
    vec3 rock = limestone_color * (0.95 + (strata - 0.5) * 0.35 * detail_fade);
    color = mix(color, rock, cliff);
    // Rubble-boundary colour is baked at island scale, retaining it from the air.
    float farmland = min(1.0, parcel.r + parcel.g);
    color = mix(color, wall_color, parcel.a * wall_strength * (1.0 - cliff));
    // Contour-following visual terraces only on cultivated moderate slopes.
    // This never raises/lowers vertices or creates landing/collision geometry.
    float terrace = 1.0 - smoothstep(0.04, 0.14 + fwidth(terrain_position.y / 3.0),
                                   abs(fract(terrain_position.y / 3.0) - 0.5));
    float terrace_slope = smoothstep(0.015, 0.05, slope) * (1.0 - smoothstep(0.18, 0.35, slope));
    color *= 1.0 - terrace * terrace_slope * farmland * terrace_strength * detail_fade;
    // Very low shores expose neutral rock, not blue terrain or white foam.
    float shore = 1.0 - smoothstep(0.5, 5.0, terrain_position.y);
    color = mix(color, limestone_color * 0.86, shore * 0.65);
    ALBEDO = color;
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
}
