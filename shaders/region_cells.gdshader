shader_type canvas_item;
// Mewarnai satu wilayah per SEL KLOTER (assets/map/cells.png, dibuat tools/make_cells.py).
// Warna sel = energi yang dipakai kloter itu. Rapuh = bergaris, mandiri = penuh.
// Belum bersih: coklat hangat (fosil) atau biru keunguan gelap (gelap). Warna menyebar dari titik
// kloter ke tepi selnya. Supaya peta tidak terlihat mati: tekstur halus, cahaya tipis di garis pantai,
// dan lampu kecil berkelip di desa yang sudah berlistrik (fosil sedikit, energi bersih lebih banyak).

uniform vec4 color_dark : source_color = vec4(0.25, 0.27, 0.34, 1.0);
uniform vec4 color_fossil : source_color = vec4(0.55, 0.42, 0.32, 1.0);
uniform vec4 border_color : source_color = vec4(0.06, 0.07, 0.14, 1.0);
// Pewarnaan wilayah (benih internet = biru, belum terjangkau = gelap): rgb + kekuatan di a.
uniform vec4 region_tint = vec4(0.0);
uniform float highlight = 0.0;
uniform float border_px = 2.0;
uniform float pixel = 4.0;
uniform vec2 ref_size = vec2(1280.0, 720.0);
uniform sampler2D noise_tex : repeat_enable, filter_nearest;
uniform float noise_amp = 10.0;

// Id sel per piksel pixel art (R + G*256 = id + 1).
uniform sampler2D cell_map : filter_nearest;
uniform vec2 cell_map_size = vec2(320.0, 180.0);
// Satu kolom per kloter. cell_color: rgb energi, a = mode (0 belum, 0.33 dibangun, 0.66 rapuh, 1 mandiri).
uniform sampler2D cell_color : filter_nearest;
// cell_geom: titik kloter (x, y), jari-jari sebaran sekarang, dasar (0 gelap, 1 fosil).
uniform sampler2D cell_geom : filter_nearest;
uniform float cell_count = 1.0;
uniform float selected_cell = -1.0;
uniform float lights = 1.0;

float hash(vec2 v) {
	return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453);
}

int cell_at(vec2 uv) {
	vec4 c = texture(cell_map, uv);
	return int(round(c.r * 255.0) + round(c.g * 255.0) * 256.0);
}

void fragment() {
	vec4 m = texture(TEXTURE, UV);
	if (m.a < 0.5) {
		vec2 o = TEXTURE_PIXEL_SIZE * border_px;
		float n = texture(TEXTURE, UV + vec2(o.x, 0.0)).a + texture(TEXTURE, UV - vec2(o.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, o.y)).a + texture(TEXTURE, UV - vec2(0.0, o.y)).a;
		COLOR = n > 0.5 ? border_color : vec4(0.0);
	} else {
		vec2 p = floor(UV * ref_size / pixel) * pixel;
		vec2 gp = floor(UV * cell_map_size);
		int id = cell_at(UV);
		vec3 c = color_dark.rgb;
		bool sel = false;
		if (id > 0) {
			float u = (float(id - 1) + 0.5) / cell_count;
			vec4 col = texture(cell_color, vec2(u, 0.5));
			vec4 geo = texture(cell_geom, vec2(u, 0.5));
			c = mix(color_dark.rgb, color_fossil.rgb, geo.a);
			c = mix(c, region_tint.rgb, region_tint.a);
			float d = distance(p, geo.xy) + (texture(noise_tex, p / 256.0).r - 0.5) * noise_amp;
			if (col.a > 0.1 && d < geo.z) {
				if (col.a > 0.85) {
					c = col.rgb;  // mandiri: penuh
				} else {
					// rapuh / sedang dibangun: garis miring berselang dengan warna tanah asal, supaya
					// energi berwarna biru (mikrohidro) tidak menyatu dengan laut.
					bool stripe = mod(gp.x + gp.y, col.a > 0.5 ? 3.0 : 2.0) < 1.0;
					c = stripe ? mix(col.rgb, c, 0.6) : col.rgb;
				}
			}
			// Tekstur tanah: variasi terang-gelap halus per blok pixel art.
			c *= 0.95 + 0.12 * texture(noise_tex, p / 97.0).r;
			// Garis tipis antar kloter, dan cahaya tipis di tepi pantai (tetangga = laut).
			vec2 step = 1.0 / cell_map_size;
			int r = cell_at(UV + vec2(step.x, 0.0));
			int b = cell_at(UV + vec2(0.0, step.y));
			int l = cell_at(UV - vec2(step.x, 0.0));
			int t = cell_at(UV - vec2(0.0, step.y));
			if ((r > 0 && r != id) || (b > 0 && b != id)) {
				c *= 0.88;
			}
			if (r == 0 || b == 0 || l == 0 || t == 0) {
				// Kloter berenergi bersih di pantai diberi tepi gelap (bukan cahaya) agar batas
				// daratan tetap jelas walau warnanya mirip laut.
				if (col.a > 0.5 && d < geo.z) {
					c *= 0.62;
				} else {
					c = mix(c, vec3(0.9, 0.96, 1.0), 0.24);
				}
			}
			// Lampu desa: hanya di desa berlistrik. Fosil = lampu redup jingga, mandiri = lampu terang.
			float h = hash(gp);
			float density = 0.0;
			vec3 lamp = vec3(1.0, 0.82, 0.5);
			if (col.a > 0.85 && d < geo.z) {
				density = 0.07;
				lamp = vec3(1.0, 0.97, 0.85);
			} else if (col.a > 0.5 && d < geo.z) {
				density = 0.04;
			} else if (geo.a > 0.5) {
				density = 0.03;
			}
			if (h < density * lights) {
				float tw = 0.65 + 0.35 * sin(TIME * (1.5 + h * 40.0) + h * 300.0);
				c = mix(c, lamp, 0.85 * tw);
			}
			sel = float(id - 1) == selected_cell;
		}
		c *= m.rgb;
		c = mix(c, vec3(1.0), highlight);
		if (sel) {
			c = mix(c, vec3(1.0), 0.3);
		}
		COLOR = vec4(c, 1.0);
	}
}
