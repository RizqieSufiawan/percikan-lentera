shader_type canvas_item;
// Laut peta (assets/map/map_background.png), digambar memenuhi seluruh kotak peta. Tepi gambar
// diperpanjang (clamp) supaya tidak ada sambungan saat peta di-zoom atau layar lebih lebar.
// Kilau ombak kecil muncul dan hilang perlahan di laut, supaya peta tidak terasa diam.

uniform sampler2D sea_tex : filter_nearest, repeat_disable;
// Posisi dan ukuran gambar laut 1280x720 di dalam kotak ini (piksel layar).
uniform vec2 map_pos = vec2(0.0);
uniform vec2 map_size = vec2(1280.0, 720.0);
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform float pixel = 4.0;
uniform vec2 ref_size = vec2(1280.0, 720.0);
uniform float amount = 1.0;
// Gambar laut lebih luas dari peta: tambahan sekian piksel referensi di tiap sisi (tools/make_sea.py).
uniform vec2 sea_ext = vec2(320.0, 180.0);
// Suasana malam seperti menu utama (1 = malam pekat, 0 = terang). Makin banyak desa memakai
// energi bersih, makin terang (diatur scripts/ui/map_view.gd).
uniform float night = 0.0;

vec3 night_sea(vec3 c) {
	// Laut malam: gelap, biru keunguan (selaras danau di menu utama).
	vec3 n = c * vec3(0.42, 0.40, 0.62);
	return mix(n, vec3(0.05, 0.06, 0.17), 0.25);
}

float hash(vec2 v) {
	return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 suv = (UV * rect_size - map_pos) / map_size;
	vec2 tuv = (suv * ref_size + sea_ext) / (ref_size + 2.0 * sea_ext);
	vec4 c = texture(sea_tex, clamp(tuv, vec2(0.001), vec2(0.999)));
	// Di luar gambar (sangat jarang): warna tepi memudar ke laut terdalam.
	vec2 outside = max(max(-tuv, tuv - 1.0), vec2(0.0)) * map_size;
	float fade = clamp(max(outside.x, outside.y) / 48.0, 0.0, 1.0);
	c.rgb = mix(c.rgb, vec3(23.0, 55.0, 94.0) / 255.0, fade);
	vec2 gp = floor(suv * ref_size / pixel);
	bool water = c.b > c.r + 0.08 && c.b > 0.15;
	c.rgb = mix(c.rgb, night_sea(c.rgb), night);
	if (water) {
		// Setiap kilau hidup beberapa detik di posisi acak, lalu pindah.
		float phase = TIME * 0.35 + hash(vec2(gp.y, 7.0)) * 10.0;
		float slot = floor(phase);
		float h = hash(gp + vec2(slot * 13.0, slot * 7.0));
		if (h < 0.0025 * amount) {
			float glow = sin(fract(phase) * 3.14159);
			// Malam: kilau jadi pantulan bulan, lebih jarang tapi tetap terang.
			c.rgb = mix(c.rgb, mix(vec3(0.75, 0.9, 1.0), vec3(0.8, 0.82, 1.0), night), 0.6 * glow);
		}
	}
	COLOR = vec4(c.rgb, 1.0);
}
