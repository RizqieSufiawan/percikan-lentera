shader_type canvas_item;
// Mewarnai satu wilayah provinsi (mask putih) dengan sebaran yang tumbuh dari satu titik.
// Kuning = menyala, hijau = mandiri, sisanya warna gelap. Tepi bergerigi gaya pixel art.

uniform vec4 color_dark : source_color = vec4(0.25, 0.27, 0.34, 1.0);
uniform vec4 color_lit : source_color = vec4(1.0, 0.77, 0.25, 1.0);
uniform vec4 color_independent : source_color = vec4(0.38, 0.78, 0.47, 1.0);
uniform vec4 border_color : source_color = vec4(0.06, 0.07, 0.14, 1.0);
// Titik awal sebaran dan jari-jari, dalam piksel referensi 1280x720.
uniform vec2 origin = vec2(640.0, 360.0);
uniform float radius_lit = -1.0;
uniform float radius_independent = -1.0;
uniform float highlight = 0.0;
// Tebal garis batas, dalam piksel tekstur.
uniform float border_px = 2.0;
// Ukuran "piksel" pixel art (4 = gambar 320x180 diperbesar 4x).
uniform float pixel = 4.0;
uniform sampler2D noise_tex : repeat_enable, filter_nearest;
uniform float noise_amp = 22.0;
uniform vec2 ref_size = vec2(1280.0, 720.0);

void fragment() {
	vec4 m = texture(TEXTURE, UV);
	if (m.a < 0.5) {
		vec2 o = TEXTURE_PIXEL_SIZE * border_px;
		float n = texture(TEXTURE, UV + vec2(o.x, 0.0)).a + texture(TEXTURE, UV - vec2(o.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, o.y)).a + texture(TEXTURE, UV - vec2(0.0, o.y)).a;
		COLOR = n > 0.5 ? border_color : vec4(0.0);
	} else {
		vec2 p = floor(UV * ref_size / pixel) * pixel;
		float d = distance(p, origin) + (texture(noise_tex, p / 256.0).r - 0.5) * noise_amp;
		vec3 c = color_dark.rgb;
		if (d < radius_lit) {
			c = color_lit.rgb;
		}
		if (d < radius_independent) {
			c = color_independent.rgb;
		}
		c *= m.rgb;
		c = mix(c, vec3(1.0), highlight);
		COLOR = vec4(c, 1.0);
	}
}
