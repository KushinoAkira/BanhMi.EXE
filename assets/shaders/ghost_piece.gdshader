shader_type canvas_item;

uniform vec4 out_color : source_color = vec4(1.0, 1.0, 1.0, 0.4);
uniform float line_frequency : hint_range(1.0, 50.0) = 20.0;
uniform float line_speed : hint_range(-5.0, 5.0) = 2.0;
uniform float line_thickness : hint_range(0.01, 1.0) = 0.5;

void fragment() {
    vec2 uv = UV;
    
    // Outer Border (thickness)
    float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    float is_border = 1.0 - step(0.1, edge); // 0.1 border thickness relative to unmapped UV
    
    // Scanline generation
    float lines = sin((uv.y - TIME * line_speed) * line_frequency * 3.14159);
    float line_alpha = step(1.0 - line_thickness, lines);
    
    vec4 col = out_color;
    // Combine scanline + bright border
    float final_alpha = max(line_alpha * 0.5, is_border * 1.5) * out_color.a;
    
    COLOR = vec4(col.rgb, final_alpha);
}
