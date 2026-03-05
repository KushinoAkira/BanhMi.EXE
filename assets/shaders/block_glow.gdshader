shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(1.0);
uniform float border_width : hint_range(0.0, 0.5) = 0.1;
uniform float inner_glow_strength : hint_range(0.0, 2.0) = 1.0;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec2 uv = UV;
    
    // Distance from center for gradient
    vec2 centered_uv = uv - vec2(0.5);
    float distSq = dot(centered_uv, centered_uv);
    
    // Inner radial glow calculation
    float glow = 1.0 - (distSq * 2.0);
    glow = clamp(glow, 0.0, 1.0) * inner_glow_strength;
    
    // Calculate border proximity
    vec2 e = min(uv, 1.0 - uv);
    float edge_dist = min(e.x, e.y);
    
    float is_border = step(edge_dist, border_width);
    
    // 3D Bevel approximation: brighter top/left, darker bottom/right
    float bevel_light = (uv.x + uv.y) * 0.5; // diagonally
    vec4 bevel_color = mix(base_color * 0.6, base_color * 1.4, bevel_light);
    
    vec4 main_fill = mix(bevel_color, base_color * 1.5, glow * 0.4);
    
    COLOR = mix(main_fill, border_color, is_border);
    COLOR.a *= base_color.a; // Respect base alpha if passed
}
