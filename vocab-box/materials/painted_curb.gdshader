shader_type spatial;

uniform sampler2D pavement_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 pavement_tint : source_color = vec4(0.96, 0.94, 0.88, 1.0);
uniform vec4 curb_red : source_color = vec4(0.737, 0.188, 0.188, 1.0);
uniform vec4 curb_white : source_color = vec4(0.953, 0.933, 0.890, 1.0);
uniform float lip_depth = 0.17;
uniform float stripe_width = 1.0;

varying vec3 mesh_position;
varying vec3 mesh_normal;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    mesh_position = VERTEX;
    mesh_normal = NORMAL;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    // Project the existing pavement image in world space so it continues across tiles.
    vec3 weights = pow(abs(normalize(world_normal)), vec3(4.0));
    weights /= max(weights.x + weights.y + weights.z, 0.0001);
    vec3 stone = texture(pavement_texture, world_position.zy).rgb * weights.x;
    stone += texture(pavement_texture, world_position.xz).rgb * weights.y;
    stone += texture(pavement_texture, world_position.xy).rgb * weights.z;

    // Paint both faces of the same curb mesh, keeping the red/white bands aligned.
    float tile_depth = length(MODEL_MATRIX[2].xyz);
    bool front_face = mesh_normal.z > 0.9 && mesh_position.z > 0.49;
    bool top_lip = mesh_normal.y > 0.9 && mesh_position.z > 0.5 - lip_depth / tile_depth;
    if (front_face || top_lip) {
        float band = mod(floor((world_position.x + 22.75) / stripe_width), 2.0);
        ALBEDO = mix(curb_red.rgb, curb_white.rgb, band);
    } else {
        ALBEDO = stone * pavement_tint.rgb;
    }
    ROUGHNESS = 0.94;
}
