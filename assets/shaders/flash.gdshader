shader_type canvas_item;
// Hit flash: mixes the sprite toward solid white. Tween `flash` 1 -> 0.

uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(base.rgb, vec3(1.0), flash), base.a);
}
