shader_type canvas_item;
render_mode blend_add;
// Pancaran cahaya bulan di layar judul: pendar lembut dan berkas sinar tipis yang MEMANCAR: denyut
// cahaya berjalan dari bulan ke luar di sepanjang berkas. Berkas berputar sangat pelan, tiap berkas
// terang-redup sendiri-sendiri, panjangnya bernapas, dan pendarnya berdenyut pelan.
// Dihitung per setengah piksel seni (640x360) dengan dithering Bayer 4x4: gradasinya lebih halus,
// tapi tetap berpola piksel. Digambar di atas lapisan langit (title_sky.png).

uniform vec2 art_size = vec2(320.0, 180.0);
uniform vec2 moon = vec2(252.5, 38.5);  // pusat bulan (piksel seni, make_title_bg.py)
uniform float moon_r = 11.5;
uniform vec3 tint : source_color = vec3(0.62, 0.64, 0.82);
uniform float strength = 0.3;
uniform float sub = 2.0;  // pembagian per piksel seni (2 = setengah piksel seni)

float bayer(vec2 g) {
	int x = int(mod(g.x, 4.0));
	int y = int(mod(g.y, 4.0));
	int i = y * 4 + x;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

void fragment() {
	vec2 gs = floor(UV * art_size * sub);  // kisi halus
	vec2 d = (gs + 0.5) / sub - moon;
	float r = length(d);
	if (r < moon_r || r > 120.0) {
		COLOR = vec4(0.0);
	} else {
		float ang = atan(d.y, d.x);
		// Dua kelompok berkas dengan jumlah dan arah putar berbeda supaya tidak terasa kaku.
		float a1 = ang * 6.0 + TIME * 0.035;
		float a2 = ang * 10.0 - TIME * 0.025 + 1.3;
		// Tiap berkas punya denyut sendiri (fase bergantung sudut), jadi bergantian terang.
		float f1 = 0.65 + 0.35 * sin(TIME * 0.55 + floor(a1 / 6.2832 + 0.25) * 2.4);
		float f2 = 0.6 + 0.4 * sin(TIME * 0.8 + floor(a2 / 6.2832 + 0.25) * 1.7);
		float rays = pow(max(0.0, sin(a1)), 7.0) * 0.65 * f1
			+ pow(max(0.0, sin(a2)), 9.0) * 0.45 * f2;
		// Panjang berkas bernapas pelan.
		float reach = 28.0 * (1.0 + 0.18 * sin(TIME * 0.45));
		// Gelombang terang bergerak keluar (r - waktu): cahaya terasa memancar dari bulan.
		float wave = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(r * 0.2 - TIME * 1.1), 2.0);
		rays *= smoothstep(moon_r, moon_r + 6.0, r) * exp(-(r - moon_r) / reach) * wave;
		float breath = 0.85 + 0.15 * sin(TIME * 0.8);
		float halo = exp(-(r - moon_r) / (8.0 + 1.5 * sin(TIME * 0.8))) * breath * (0.85 + 0.15 * sin(r * 0.35 - TIME * 1.1));
		float v = clamp(rays * 0.95 + halo * 0.7, 0.0, 1.0) * 24.0;
		// Kuantisasi 24 tingkat + dithering di kisi halus: tetap berpola piksel, tapi lebih lembut.
		float lvl = floor(v);
		if (v - lvl > bayer(gs)) {
			lvl += 1.0;
		}
		COLOR = vec4(tint * strength * (lvl / 24.0), 1.0);
	}
}
