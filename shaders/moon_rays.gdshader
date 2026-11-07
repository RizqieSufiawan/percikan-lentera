shader_type canvas_item;
render_mode blend_add;
// Pancaran cahaya bulan di layar judul: pendar lembut dan berkas sinar tipis yang MEMANCAR: denyut
// cahaya berjalan dari bulan ke luar di sepanjang berkas (berkasnya sendiri hampir diam). Dihitung per piksel seni (320x180) dan memakai dithering Bayer 4x4, jadi
// tetap terlihat pixel art, bukan gradasi halus. Digambar di atas lapisan langit (title_sky.png).

uniform vec2 art_size = vec2(320.0, 180.0);
uniform vec2 moon = vec2(252.5, 38.5);  // pusat bulan (piksel seni, make_title_bg.py)
uniform float moon_r = 11.5;
uniform vec3 tint : source_color = vec3(0.62, 0.64, 0.82);
uniform float strength = 0.3;

float bayer(vec2 g) {
	int x = int(mod(g.x, 4.0));
	int y = int(mod(g.y, 4.0));
	int i = y * 4 + x;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

void fragment() {
	vec2 g = floor(UV * art_size);
	vec2 d = g + 0.5 - moon;
	float r = length(d);
	if (r < moon_r || r > 110.0) {
		COLOR = vec4(0.0);
	} else {
		float ang = atan(d.y, d.x);
		// Dua kelompok berkas dengan jumlah dan arah putar berbeda supaya tidak terasa kaku.
		float rays = pow(max(0.0, sin(ang * 6.0 + TIME * 0.01)), 7.0) * 0.65
			+ pow(max(0.0, sin(ang * 10.0 - TIME * 0.008 + 1.3)), 9.0) * 0.45;
		// Gelombang terang bergerak keluar (r - waktu): cahaya terasa memancar dari bulan.
		float wave = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(r * 0.2 - TIME * 1.1), 2.0);
		rays *= smoothstep(moon_r, moon_r + 5.0, r) * exp(-(r - moon_r) / 28.0) * wave;
		float halo = exp(-(r - moon_r) / 8.0) * (0.8 + 0.2 * sin(r * 0.35 - TIME * 1.1));
		float v = clamp(rays * 0.75 + halo * 0.7, 0.0, 1.0) * 16.0;
		// Kuantisasi 16 tingkat + dithering di antaranya: tetap per piksel seni, tapi halus.
		float lvl = floor(v);
		if (v - lvl > bayer(g)) {
			lvl += 1.0;
		}
		COLOR = vec4(tint * strength * (lvl / 16.0), 1.0);
	}
}
