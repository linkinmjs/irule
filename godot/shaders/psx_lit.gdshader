// Shader PS1 del proyecto (GDD §10.1): vertex snapping + affine texture mapping
// + banding de color + dissolve por dithering (usado en el despawn de ragdolls).
// La niebla del Environment se aplica sola (Forward+).
shader_type spatial;
render_mode cull_back, diffuse_lambert_wrap, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);
// 1.0 = snap a la resolución del viewport; valores mayores = grilla más gruesa (más wobble).
uniform float snap_divisor : hint_range(1.0, 8.0) = 2.0;
uniform float color_levels : hint_range(4.0, 64.0) = 32.0;
// Warp affine: 1.0 = PS1 pleno (exige geometría subdividida), 0.0 = sin warp.
uniform float affine_strength : hint_range(0.0, 1.0) = 0.85;
// 1.0 visible — 0.0 disuelto (per-instancia, para despawns).
instance uniform float dissolve : hint_range(0.0, 1.0) = 1.0;

varying float v_affine_w;

const mat4 BAYER = mat4(
	vec4(0.0, 8.0, 2.0, 10.0),
	vec4(12.0, 4.0, 14.0, 6.0),
	vec4(3.0, 11.0, 1.0, 9.0),
	vec4(15.0, 7.0, 13.0, 5.0));

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float w = max(clip.w, 0.0001);
	vec2 grid = (VIEWPORT_SIZE.xy / max(snap_divisor, 1.0)) * 0.5;
	vec2 ndc = clip.xy / w;
	ndc = floor(ndc * grid) / grid;
	clip.xy = ndc * w;
	POSITION = clip;
	float w_affine = mix(1.0, w, affine_strength);
	v_affine_w = w_affine;
	UV = UV * uv_scale * w_affine;
}

void fragment() {
	vec2 uv = UV / v_affine_w;
	vec4 tex = texture(albedo_tex, uv);
	vec3 col = tex.rgb * tint.rgb;
	col = floor(col * color_levels) / color_levels;
	ALBEDO = col;

	ivec2 px = ivec2(FRAGCOORD.xy);
	float threshold = (BAYER[px.x % 4][px.y % 4] + 1.0) / 17.0;
	if (dissolve < threshold) {
		discard;
	}
}
