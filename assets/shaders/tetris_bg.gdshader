shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform vec4 grid_color : source_color = vec4(0.2, 0.2, 0.4, 0.5);
uniform float speed : hint_range(0.1, 5.0) = 0.5;
uniform float line_thickness : hint_range(0.01, 0.1) = 0.02;

// Subtly drifting and pulsing grid
void fragment() {
    vec2 uv = UV;
    uv.y += TIME * speed * 0.1; // Drift downwards to simulate falling
    
    // Scale UV for grid cells
    vec2 grid_uv = fract(uv * 10.0);
    
    // Calculate distance to nearest edge
    vec2 dist = min(grid_uv, 1.0 - grid_uv);
    float edge = min(dist.x, dist.y);
    
    // Smoothstep for anti-aliased lines
    float line_weight = smoothstep(line_thickness, line_thickness * 0.5, edge);
    
    // Add a pulsing effect based on TIME
    float pulse = (sin(TIME * 2.0) * 0.5 + 0.5) * 0.5 + 0.5;
    
    vec4 final_color = mix(bg_color, grid_color * pulse, line_weight);
    COLOR = final_color;
}
