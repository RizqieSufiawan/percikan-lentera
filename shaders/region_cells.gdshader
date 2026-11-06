shader_type canvas_item;
// Mewarnai satu wilayah per SEL KLOTER (assets/map/cells.png, dibuat tools/make_cells.py).
// Warna sel = energi yang dipakai kloter itu. Rapuh = bergaris, mandiri = penuh.
// Belum bersih: coklat hangat (fosil) atau biru keunguan gelap (gelap). Warna menyebar dari titik
// kloter ke tepi selnya, titik demi titik. Supaya peta tidak terlihat mati: tekstur halus, cahaya tipis di garis pantai,
// dan lampu kecil berkelip di desa yang sudah berlistrik (fosil sedikit, energi bersih lebih banyak).

uniform vec4 color_dark : source_color = vec4(0.25, 0.27, 0.34, 1.0);
uniform vec4 color_fossil : source_color = vec4(0.55, 0.42, 0.32, 1.0);
uniform vec4 border_color : source_color = vec4(0.06, 0.07, 0.14, 1.0);
// Pewarnaan wilayah (benih internet = biru, belum terjangkau = gelap): rgb + kekuatan di a.
uniform vec4 region_tint = vec4(0.0);
uniform float highlight = 0.0;
uniform float border_px = 2.0;  // tidak dipakai lagi (garis mengikuti kisi piksel)
uniform float highlight_border = 0.0;  // 1 = wilayah terpilih (garis krem)
uniform float pixel = 4.0;
uniform vec2 ref_size = vec2(1280.0, 720.0);
uniform sampler2D noise_tex : repeat_enable, filter_nearest;
uniform float noise_amp = 10.0;

// Id sel per piksel pixel art (R + G*256 = id + 1).
uniform sampler2D cell_map : filter_nearest;
uniform vec2 cell_map_size = vec2(320.0, 180.0);
// Satu kolom per kloter. cell_color: rgb energi, a = mode (0 belum, 0.33 dibangun, 0.66 rapuh, 1 mandiri).
uniform sampler2D cell_color : filter_nearest;
// cell_geom: titik kloter (x, y), isi kloter sekarang 0..1 (-1 = kosong), dasar (0 gelap, 1 fosil).
uniform sampler2D cell_geom : filter_nearest;
uniform float cell_count = 1.0;
// Urutan menyala tiap piksel di kloternya (0..1); piksel menyala jika urutannya < isi kloter (geo.z).
uniform sampler2D cell_rank : filter_nearest;
// Energi kedua (baris atas) dan ketiga (baris bawah) per kloter: rgb warna, a = bagian titik.
uniform sampler2D cell_mix : filter_nearest;
uniform float selected_cell = -1.0;
uniform float lights = 1.0;

float hash(vec2 v) {
	return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453);
}

int cell_at(vec2 uv) {
	vec4 c = texture(cell_map, uv);
	return int(round(c.r * 255.0) + round(c.g * 255.0) * 256.0);
}

// Semua digambar di kisi pixel art (1 piksel seni = 4x4 piksel layar): garis pantai, batas wilayah,
// dan sorotan ikut kisi yang sama, jadi tidak ada garis setengah piksel.
vec2 art_uv(vec2 g) {
	return (g + 0.5) / cell_map_size;
}

// Piksel seni g adalah daratan milik wilayah INI (mask wilayah + sel kloter).
bool mine(sampler2D mask, vec2 g) {
	vec2 uv = art_uv(g);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return false;
	}
	return texture(mask, uv).a > 0.5 && cell_at(uv) > 0;
}

void fragment() {
	vec2 gp = floor(UV * cell_map_size);
	vec2 auv = art_uv(gp);
	bool is_sel_region = highlight_border > 0.5;
	if (!mine(TEXTURE, gp)) {
		// Laut: wilayah terpilih diberi garis krem selebar satu piksel seni di luar pantainya.
		bool near = mine(TEXTURE, gp + vec2(1.0, 0.0)) || mine(TEXTURE, gp - vec2(1.0, 0.0)) || mine(TEXTURE, gp + vec2(0.0, 1.0)) || mine(TEXTURE, gp - vec2(0.0, 1.0));
		COLOR = (is_sel_region && near && cell_at(auv) == 0) ? border_color : vec4(0.0);
	} else {
		vec4 m = texture(TEXTURE, auv);
		vec2 p = gp * pixel;
		int id = cell_at(auv);
		vec3 c = color_dark.rgb;
		bool sel = false;
		float u = (float(id - 1) + 0.5) / cell_count;
		vec4 col = texture(cell_color, vec2(u, 0.5));
		vec4 geo = texture(cell_geom, vec2(u, 0.5));
		c = mix(color_dark.rgb, color_fossil.rgb, geo.a);
		c = mix(c, region_tint.rgb, region_tint.a);
		// Kloter menyala titik demi titik (1 titik peta ~ 9 desa), bukan sekaligus.
		bool on = texture(cell_rank, auv).r < geo.z;
		if (col.a > 0.5 && on) {
			// Sebagian desa di kloter memakai energi lain yang cocok (campuran).
			vec4 m2 = texture(cell_mix, vec2(u, 0.25));
			vec4 m3 = texture(cell_mix, vec2(u, 0.75));
			float hm = hash(gp + vec2(17.3, 91.7));
			if (hm < m2.a) {
				col.rgb = m2.rgb;
			} else if (hm < m2.a + m3.a) {
				col.rgb = m3.rgb;
			}
		}
		if (col.a > 0.1 && on) {
			if (col.a > 0.85) {
				// Mandiri: penuh, dan "bernapas" sangat pelan (fase beda tiap kloter) supaya terasa hidup.
				c = col.rgb * (1.0 + 0.06 * sin(TIME * 1.1 + float(id) * 1.7));
			} else {
				// Rapuh: garis miring dari warna energinya sendiri yang lebih gelap (tanah fosil/gelap
				// sudah tertutup, desanya sudah bersih). Sedang dibangun: garis dengan warna tanah asal.
				bool fragile = col.a > 0.5;
				bool stripe = mod(gp.x + gp.y, fragile ? 3.0 : 2.0) < 1.0;
				vec3 stripe_col = fragile ? col.rgb * 0.62 : mix(col.rgb, c, 0.6);
				c = stripe ? stripe_col : col.rgb;
			}
		}
		// Tekstur tanah: variasi terang-gelap sangat halus per blok, supaya tidak berbintik.
		c *= 0.97 + 0.06 * texture(noise_tex, p / 97.0).r;
		vec2 one = vec2(1.0, 0.0);
		vec2 dn = vec2(0.0, 1.0);
		int r = cell_at(art_uv(gp + one));
		int b = cell_at(art_uv(gp + dn));
		// Garis tipis antar kloter (hanya kanan/bawah = satu piksel per batas).
		if ((r > 0 && r != id && mine(TEXTURE, gp + one)) || (b > 0 && b != id && mine(TEXTURE, gp + dn))) {
			c *= 0.9;
		}
		// Batas provinsi di dalam wilayah: garis terang-gelap dari gambar wilayah, dibaca di 4 sudut blok.
		vec2 q = 1.5 / (cell_map_size * 4.0);
		float inner = min(min(texture(TEXTURE, auv + vec2(q.x, q.y)).r, texture(TEXTURE, auv - vec2(q.x, q.y)).r),
			min(texture(TEXTURE, auv + vec2(q.x, -q.y)).r, texture(TEXTURE, auv + vec2(-q.x, q.y)).r));
		if (inner < 0.9) {
			c *= 0.86;
		}
		// Batas dengan wilayah lain: satu piksel gelap di sisi kiri/atas wilayah ini.
		bool other_l = cell_at(art_uv(gp - one)) > 0 && !mine(TEXTURE, gp - one);
		bool other_t = cell_at(art_uv(gp - dn)) > 0 && !mine(TEXTURE, gp - dn);
		bool other_r = r > 0 && !mine(TEXTURE, gp + one);
		bool other_b = b > 0 && !mine(TEXTURE, gp + dn);
		if (other_l || other_t) {
			c = mix(c, border_color.rgb, 0.7);
		}
		// Pantai: tepi daratan sedikit lebih gelap, laut di luarnya punya buih terang (latar laut).
		bool coast = !mine(TEXTURE, gp + one) && r == 0 || !mine(TEXTURE, gp + dn) && b == 0
			|| cell_at(art_uv(gp - one)) == 0 || cell_at(art_uv(gp - dn)) == 0;
		if (coast) {
			c *= 0.8;
		}
		// Wilayah terpilih: tepi dalamnya ke wilayah lain ikut krem.
		if (is_sel_region && (other_l || other_t || other_r || other_b)) {
			c = border_color.rgb;
		}
		// Lampu desa: hanya di desa berlistrik. Fosil = lampu redup jingga, mandiri = lampu terang.
		float h = hash(gp);
		float density = 0.0;
		vec3 lamp = vec3(1.0, 0.82, 0.5);
		if (col.a > 0.85 && on) {
			density = 0.07;
			lamp = vec3(1.0, 0.97, 0.85);
		} else if (col.a > 0.5 && on) {
			density = 0.04;
		} else if (geo.a > 0.5) {
			density = 0.03;
		}
		if (h < density * lights) {
			float tw = 0.65 + 0.35 * sin(TIME * (1.5 + h * 40.0) + h * 300.0);
			c = mix(c, lamp, 0.85 * tw);
		}
		sel = float(id - 1) == selected_cell;
		c = mix(c, vec3(1.0), highlight);
		if (sel) {
			c = mix(c, vec3(1.0), 0.3);
		}
		COLOR = vec4(c, 1.0);
	}
}
