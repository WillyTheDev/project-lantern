shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float hit_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 hit_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec3 base_color = albedo.rgb;
	ALBEDO = mix(base_color, hit_color.rgb, hit_intensity);
	EMISSION = hit_color.rgb * hit_intensity * 2.0; // Make it glow slightly when flashing
}
