shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
    vec4 screen_color = texture(screen_texture, SCREEN_UV);
    float luminance = (0.299 * screen_color.r + 0.587 * screen_color.g + 0.114 * screen_color.b);
    
    if (luminance > 0.5) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0); // Black on bright backgrounds
    } else {
        COLOR = vec4(1.0, 1.0, 1.0, 1.0); // White on dark backgrounds
    }
}
