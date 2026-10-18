shader_type spatial;

uniform sampler2D kenney_colormap : source_color, filter_linear_mipmap;
uniform sampler2D asphalt_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform float texture_world_size = 2.0;
uniform float asphalt_darkness = 0.82;

varying vec3 world_position;
varying vec3 mesh_normal;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    mesh_normal = NORMAL;
}

void fragment() {
    vec3 atlas_color = texture(kenney_colormap, UV).rgb;

    // The Kenney road atlas uses these UV swatches for its two asphalt faces.
    // Show the dark asphalt image directly and retain the darker shoulder tone.
    bool asphalt_face = mesh_normal.y > 0.9 && UV.y > 0.8 && UV.x < 0.32;
    if (asphalt_face) {
        float base_brightness = dot(atlas_color, vec3(0.2126, 0.7152, 0.0722));
        float shoulder_tone = clamp(base_brightness / 0.13, 0.55, 1.0);
        ALBEDO = texture(asphalt_texture, world_position.xz / texture_world_size).rgb * shoulder_tone * asphalt_darkness;
    } else {
        // Keep the original Kenney markings, edge colors, and side faces.
        ALBEDO = atlas_color;
    }
    ROUGHNESS = 0.97;
}
