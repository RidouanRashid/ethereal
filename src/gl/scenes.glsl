// Etheral — alle visioenen.
// Elk blok dat begint met "// ---------- Naam ----------" wordt in stage.js een eigen,
// kleine shader. Zo hoeft de videokaart nooit alles tegelijk te compileren.
// De naam in de kop moet overeenkomen met de lijst ORDER in stage.js.

// ---------- Juweel ----------
vec3 sceneJewel(vec2 p, float t) {
  float r = length(p);
  float a = atan(p.y, p.x) + t * 0.05;
  float slice = TAU / 8.0;
  a = abs(mod(a, slice) - slice * 0.5);
  vec2 q = vec2(cos(a), sin(a)) * r;

  vec3 col = vec3(0.02, 0.01, 0.03);
  float s = 1.0;
  for (int i = 0; i < 4; i++) {
    float fi = float(i);
    q = abs(q) - vec2(0.32, 0.12) * s;
    q *= rot(0.6 + 0.15 * sin(t * 0.3 + fi));
    float d = abs(length(q) - 0.18 * s);
    vec3 c = pal(fi * 0.23 + r * 0.8 - t * 0.08,
                 vec3(0.5), vec3(0.5), vec3(1.0, 0.9, 0.7), vec3(0.0, 0.33, 0.67));
    col += c * (0.012 / (d + 0.012)) * 0.6;
    s *= 0.72;
  }
  // facetten: harde banden die het licht "breken"
  float facet = abs(fract(q.x * 6.0 + q.y * 4.0) - 0.5);
  col *= 0.65 + 0.9 * facet;
  // turquoise kern en roze gloed
  col += vec3(0.1, 0.8, 0.75) * 0.05 / (r * r + 0.05);
  col += vec3(1.0, 0.3, 0.6) * 0.15 * exp(-r * 2.5);
  return witness(col, p, 0.13, t);
}

// ---------- Netwerk ----------
vec2 nodePos(vec2 id, float t) {
  vec2 h = hash22(id);
  return id + 0.5 + 0.3 * vec2(sin(t * 0.6 + h.x * TAU), cos(t * 0.5 + h.y * TAU));
}

vec3 sceneNet(vec2 p, float t) {
  p *= rot(length(p) * 0.9 - t * 0.04);
  p += 0.22 * (vec2(fbm(p * 1.3 + t * 0.06), fbm(p * 1.3 + 4.0 - t * 0.05)) - 0.5);
  p = p * 4.0 + vec2(t * 0.08, t * 0.03);
  vec2 id = floor(p);
  float dLine = 10.0;
  float dNode = 10.0;
  float hNode = 0.0;
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 c = id + vec2(float(x), float(y));
      vec2 a = nodePos(c, t);
      float d = max(abs(p.x - a.x), abs(p.y - a.y));
      if (d < dNode) {
        dNode = d;
        hNode = hash21(c);
      }
      dLine = min(dLine, seg(p, a, nodePos(c + vec2(1.0, 0.0), t)));
      dLine = min(dLine, seg(p, a, nodePos(c + vec2(0.0, 1.0), t)));
      if (hash21(c + 3.0) > 0.5) {
        dLine = min(dLine, seg(p, a, nodePos(c + vec2(1.0, 1.0), t)));
      }
    }
  }
  vec3 col = vec3(0.02, 0.03, 0.07);
  col += vec3(0.95, 0.85, 0.5) * (0.01 / (dLine + 0.01)) * 0.55;
  vec3 nodeCol = mix(vec3(0.25, 0.45, 1.0), vec3(1.0, 0.85, 0.2), step(0.6, hNode));
  float pulse = 0.75 + 0.25 * sin(t * 2.0 + hNode * 40.0);
  col = mix(col, nodeCol * pulse, 1.0 - smoothstep(0.075, 0.09, dNode));
  col += nodeCol * 0.006 / (dNode * dNode + 0.02);
  return col;
}

// ---------- Wolk ----------
vec3 sceneCloud(vec2 p, float t) {
  p.x = abs(p.x); // gespiegeld, zoals een inktvlek
  vec3 sky = mix(vec3(0.1, 0.07, 0.2), vec3(0.02, 0.02, 0.07), clamp(p.y * 0.9 + 0.5, 0.0, 1.0));
  vec2 q = p * 1.6;
  vec2 w = vec2(fbm(q + t * 0.05), fbm(q + vec2(5.2, 1.3) - t * 0.04));
  float d = fbm(q * 1.2 + w * 1.8 + vec2(0.0, -t * 0.06));
  float shape = 1.0 - smoothstep(0.2, 1.1, length(p * vec2(0.8, 1.2) - vec2(0.0, 0.1)));
  float cover = smoothstep(0.3, 0.7, d * shape * 1.9);
  vec3 cloud = mix(vec3(0.6, 0.06, 0.2), vec3(0.98, 0.92, 0.96), smoothstep(0.4, 0.9, d + w.x * 0.3));
  cloud = mix(cloud, vec3(0.2, 0.25, 0.65), (1.0 - smoothstep(0.2, 0.6, w.y)) * 0.6);
  vec3 col = mix(sky, cloud, cover);

  return col;
}

// ---------- Oog ----------

vec3 sceneEye(vec2 p, float t) {
  // veld van verzonnen tekens; elke regel schuift de andere kant op
  vec2 g = p * vec2(9.0, 7.0);
  float row = floor(g.y);
  g.x += row * 0.37 + t * 0.15 * (mod(row, 2.0) * 2.0 - 1.0);
  vec2 id = floor(g);
  float seed = hash21(id);
  float flicker = step(0.15, hash21(id + floor(t * 2.0 + seed * 10.0)));
  float ink = glyph(fract(g), id + floor(t * 0.4 + seed * 4.0)) * flicker;

  float r = length(p);
  float a = atan(p.y, p.x);
  vec3 col = vec3(0.75, 0.8, 0.85) * ink * smoothstep(0.3, 0.65, r) * 0.8;

  // iris met vezels, pupil die langzaam ademt
  float iris = 1.0 - smoothstep(0.26, 0.3, r);
  float fibre = 0.5 + 0.5 * sin(a * 40.0 + fbm(vec2(a * 6.0, r * 10.0 - t * 0.5)) * 6.0);
  vec3 irisCol = mix(vec3(0.55, 0.02, 0.05), vec3(1.0, 0.38, 0.3), fibre * smoothstep(0.05, 0.28, r));
  float pupil = 0.08 + 0.02 * sin(t * 1.3);
  irisCol *= smoothstep(pupil, pupil + 0.03, r);
  col = mix(col, irisCol, iris);
  col += vec3(1.0, 0.1, 0.12) * 0.035 / (abs(r - 0.3) + 0.03);
  col += vec3(1.0, 0.15, 0.15) * 0.3 * exp(-r * 3.0);
  return col;
}

// ---------- Organisme ----------
vec3 sceneOrganism(vec2 p, float t) {
  vec2 w = p + 0.15 * (vec2(fbm(p * 2.0 + t * 0.1), fbm(p * 2.0 + 7.0 - t * 0.1)) - 0.5);
  float r = length(w);
  float a = atan(w.y, w.x);
  // zes armen die golven langs hun lengte
  float arm = abs(sin(a * 3.0 + sin(r * 5.0 - t * 0.7) * 0.8));
  float body = 1.0 - smoothstep(0.26, 0.32, r * (1.0 - 0.62 * arm));

  // parels: bolletjes in een raster van hoek × afstand
  vec2 uv = vec2(a / TAU * 24.0, r * 14.0 - t * 0.3);
  vec2 cell = fract(uv) - 0.5;
  float pd = length(cell);
  float pearl = 1.0 - smoothstep(0.36, 0.46, pd);
  float shade = sqrt(max(0.0, 1.0 - pd * pd * 4.5));
  vec3 skin = chrome(shade * 1.2 + r * 2.0 + t * 0.1 + hash21(floor(uv)) * 0.3, r + t * 0.05);

  vec3 col = vec3(0.015, 0.02, 0.04) + vec3(0.1, 0.15, 0.3) * 0.2 * exp(-r * 2.0);
  col = mix(col, skin * (0.25 + 0.85 * shade), pearl * body);

  // vier ogen, gespiegeld over beide assen
  float e = length(abs(w) - vec2(0.2, 0.13));
  vec3 eyeCol = pal(e * 12.0 - t * 0.4, vec3(0.5), vec3(0.5), vec3(1.0, 0.8, 0.6), vec3(0.05, 0.25, 0.6));
  eyeCol *= smoothstep(0.02, 0.035, e);
  col = mix(col, eyeCol, 1.0 - smoothstep(0.085, 0.1, e));
  return col;
}

// ---------- Zegels ----------
vec3 sceneSigils(vec2 p, float t) {
  vec2 g = p * 3.2 + vec2(0.0, t * 0.05);
  vec2 id = floor(g);
  vec2 c = fract(g) - 0.5;
  float h = hash21(id);
  float h2 = hash21(id + 9.7);
  float r = length(c);
  float a = atan(c.y, c.x) + t * 0.4 * (h - 0.5);
  float n = floor(3.0 + h * 9.0);
  float star = cos(a * n) * 0.5 + 0.5;

  float d = abs(r - 0.4);
  d = min(d, abs(r - 0.36));
  d = min(d, abs(r - (0.12 + 0.2 * pow(star, 1.0 + h2 * 3.0))));
  d = min(d, abs(r - 0.06 - 0.04 * h2));
  float pa = mod(a, TAU / n) - TAU / n * 0.5;
  d = min(d, max(abs(r * cos(pa) - 0.22), r - 0.36));

  vec3 ink = pal(h + floor(h2 * 3.0) / 3.0 + t * 0.02,
                 vec3(0.6), vec3(0.4), vec3(1.0, 0.8, 0.6), vec3(0.1, 0.3, 0.6));
  vec3 col = vec3(0.03, 0.03, 0.05);
  col += ink * (0.006 / (d + 0.006));
  // rand van elk vak, zoals een contactvel
  float frame = max(abs(c.x), abs(c.y));
  col += vec3(0.5, 0.5, 0.6) * 0.25 * step(0.488, frame);

  // regenboog-uitbarsting in het midden van het beeld
  float rr = length(p);
  float rays = 0.5 + 0.5 * cos(atan(p.y, p.x) * 60.0);
  col += pal(rr * 6.0 - t * 0.3, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67))
         * exp(-rr * 5.0) * rays * 0.7;
  return col;
}

// ---------- Tempel ----------
vec3 sceneTemple(vec2 p, float t) {
  p.x = abs(p.x);
  vec2 q = p * 1.4;
  vec3 col = vec3(0.02, 0.015, 0.05);
  float s = 1.0;
  for (int i = 0; i < 6; i++) {
    q = abs(q) - vec2(0.5, 0.35) + 0.05 * vec2(sin(t * 0.2), cos(t * 0.17));
    q *= rot(0.785 + 0.1 * sin(t * 0.1));
    q *= 1.35;
    s *= 1.35;
    float d = min(abs(q.x), abs(q.y)) / s;
    float ring = abs(length(q) - 0.4) / s;
    vec3 c = pal(float(i) * 0.13 + length(p) * 0.4 + t * 0.03,
                 vec3(0.55, 0.5, 0.6), vec3(0.45, 0.4, 0.4), vec3(1.0, 0.9, 0.6), vec3(0.65, 0.75, 0.9));
    col += c * (0.0012 / (d + 0.0012) + 0.002 / (ring + 0.002)) * 0.35;
  }
  // lichtstraal door het midden
  col += vec3(1.0, 0.8, 0.6) * (0.012 / (p.x + 0.012)) * (0.6 + 0.4 * sin(p.y * 40.0 - t * 4.0));
  return witness(col, p, 0.16, t);
}

// ---------- Vloeistof ----------
vec3 sceneLiquid(vec2 p, float t) {
  vec2 q = p * 1.5;
  vec2 w = vec2(fbm(q + vec2(0.0, t * 0.07)), fbm(q + vec2(3.1, -t * 0.06) + 1.7));
  vec2 w2 = vec2(fbm(q + 3.0 * w + vec2(1.7, 9.2) + t * 0.03),
                 fbm(q + 3.0 * w + vec2(8.3, 2.8) - t * 0.04));
  float v = fbm(q + 3.0 * w2);
  // hoogtelijnen door de vloeistof
  float bands = abs(fract(v * 9.0) - 0.5) * 2.0;
  vec3 col = pal(v * 2.2 + w2.x * 0.6 + t * 0.03,
                 vec3(0.5), vec3(0.5), vec3(1.0, 0.8, 0.9), vec3(0.9, 0.55, 0.3));
  col *= 0.3 + 0.7 * smoothstep(0.0, 0.35, bands);
  col += vec3(1.0, 0.95, 0.9) * pow(1.0 - bands, 12.0) * 0.45;
  return col;
}

// ---------- Moiré ----------
vec3 sceneMoire(vec2 p, float t) {
  vec2 a = 0.35 * vec2(cos(t * 0.21), sin(t * 0.17));
  vec2 b = 0.35 * vec2(cos(t * 0.13 + 2.0), sin(t * 0.19 + 4.0));
  vec2 c = 0.3 * vec2(cos(t * 0.11 + 4.0), sin(t * 0.23 + 1.0));
  // drie stelsels ringen die elkaar storen
  float r1 = sin(length(p - a) * 60.0);
  float r2 = sin(length(p - b) * 60.0);
  float r3 = sin(length(p - c) * 30.0);
  float m = r1 * r2;
  vec3 col = pal(m * 0.35 + r3 * 0.2 + length(p) * 0.5 - t * 0.04,
                 vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67));
  col *= 0.12 + 0.88 * (m * 0.5 + 0.5);
  col += vec3(1.0) * smoothstep(0.8, 1.0, m * r3) * 0.5;
  return col;
}

// ---------- Cellen ----------
vec3 sceneCells(vec2 p, float t) {
  p = p * 3.0 + 0.6 * (vec2(fbm(p * 1.5 + t * 0.05), fbm(p * 1.5 + 5.0 - t * 0.05)) - 0.5);
  vec2 id = floor(p);
  vec2 f = fract(p);
  float d1 = 10.0;
  float d2 = 10.0;
  vec2 cid = vec2(0.0);
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 g = vec2(float(x), float(y));
      vec2 o = 0.5 + 0.4 * sin(t * 0.5 + TAU * hash22(id + g));
      float d = length(g + o - f);
      if (d < d1) {
        d2 = d1;
        d1 = d;
        cid = id + g;
      } else if (d < d2) {
        d2 = d;
      }
    }
  }
  float edge = d2 - d1;
  float h = hash21(cid);
  vec3 col = pal(h + d1 * 0.8 + t * 0.05,
                 vec3(0.5), vec3(0.5), vec3(1.0, 0.7, 0.4), vec3(0.0, 0.15, 0.2));
  col *= (1.0 - d1 * 0.8) * smoothstep(0.0, 0.08, edge);
  col += vec3(0.9, 1.0, 0.95) * (0.02 / (edge + 0.02)) * 0.5;
  col += vec3(1.0) * (1.0 - smoothstep(0.03, 0.06, d1)) * 0.8;
  return col;
}

// ---------- Tunnel ----------
vec3 sceneTunnel(vec2 p, float t) {
  float r = length(p) + 0.001;
  float a = atan(p.y, p.x);
  float z = 0.35 / r + t * 0.35;
  vec2 uv = vec2(a / TAU * 8.0 + sin(z * 0.7) * 1.2, z * 2.0);
  vec2 c = fract(uv) - 0.5;
  vec2 id = floor(uv);
  float h = hash21(vec2(mod(id.x, 8.0), id.y));
  float d = max(abs(c.x), abs(c.y));
  vec3 tint = pal(h * 0.6 + z * 0.08,
                  vec3(0.5), vec3(0.5), vec3(1.0, 0.9, 0.8), vec3(0.55, 0.7, 0.9));
  float tile = step(0.3, h) * (1.0 - smoothstep(0.38, 0.42, d));
  float wire = 0.15 / (abs(d - 0.46) * 40.0 + 1.0);
  vec3 col = tint * (tile + wire) * smoothstep(0.0, 0.35, r) * 1.3;
  col += vec3(0.8, 0.9, 1.0) * 0.015 / (r * r + 0.03);
  return col;
}

// ---------- Spectrum ----------
vec3 sceneSpectrum(vec2 p, float t) {
  // horizontale stroken die af en toe verspringen, zoals een kapot signaal
  float band = floor(p.y * 18.0 + fbm(vec2(p.x * 0.5, t * 0.1)) * 4.0);
  float h = hash21(vec2(band, floor(t * 1.5 + hash21(vec2(band, 3.0)) * 5.0)));
  float shift = (h - 0.5) * 1.2 * step(0.55, hash21(vec2(band, floor(t * 0.7))));
  vec2 q = vec2(p.x + shift, p.y);
  float arc = length(q * vec2(1.0, 1.4) + vec2(0.0, 0.5));
  float v = arc * 3.0 - t * 0.2 + fbm(q * 2.0 + t * 0.05) * 0.8;
  vec3 col = pal(v, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67));
  col *= 0.2 + 0.8 * smoothstep(0.2, 0.5, abs(fract(v * 4.0) - 0.5) * 2.0);
  col *= 0.6 + 0.8 * h;
  vec2 block = floor(q * vec2(24.0, 18.0));
  float dead = step(0.97, hash21(block + floor(t * 2.0)));
  col = mix(col, vec3(hash21(block + floor(t * 3.0))), dead * 0.8);
  return col;
}

// ---------- Helix ----------
vec3 sceneHelix(vec2 p, float t) {
  vec3 col = vec3(0.03, 0.02, 0.05);
  for (int i = 0; i < 5; i++) {
    float fi = float(i);
    float x = p.x - (fi - 2.0) * 0.38 - 0.05 * sin(t + fi);
    float ph = p.y * (9.0 + fi * 2.0) + t * (2.0 + fi * 0.7) + fi * 1.7;
    float a = 0.13 * sin(ph);
    float depth = cos(ph);
    vec3 c = pal(fi * 0.17 + p.y * 0.3 + t * 0.1, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67));
    col += c * (0.008 / (abs(x - a) + 0.008)) * (0.6 + 0.4 * depth);
    col += c.zxy * (0.008 / (abs(x + a) + 0.008)) * (0.6 - 0.4 * depth);
    // sporten tussen de twee strengen
    float inside = step(abs(x), abs(a));
    col += c * 0.5 * inside * (1.0 - smoothstep(0.1, 0.2, abs(fract(ph * 1.2732) - 0.5)));
  }
  return col;
}

// ---------- Circuit ----------
vec3 sceneCircuit(vec2 p, float t) {
  p = p * 5.0 + vec2(t * 0.4, sin(t * 0.3));
  vec2 id = floor(p);
  vec2 f = fract(p);
  // elke tegel klapt af en toe om, waardoor de buizen opnieuw aansluiten
  float h = hash21(id + floor(t * 0.4 + hash21(id) * 5.0));
  if (h > 0.5) f.x = 1.0 - f.x;
  float d = min(abs(length(f) - 0.5), abs(length(f - 1.0) - 0.5));
  vec3 c = pal(d * 6.0 - t * 1.2 + hash21(id) * 0.3, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67));
  float pipe = 1.0 - smoothstep(0.16, 0.2, d);
  vec3 col = c * pipe * (0.5 + 0.5 * cos(d * 60.0));
  col += vec3(1.0) * (1.0 - smoothstep(0.0, 0.02, abs(d - 0.18))) * 0.5;
  float chip = step(0.92, hash21(id + 3.3));
  vec3 led = vec3(0.1, 1.0, 0.4) * step(0.5, fract(f.y * 8.0 + t * 3.0)) * step(0.5, fract(f.x * 8.0));
  return mix(col, led, chip * 0.8);
}

// ---------- Bliksem ----------
vec3 sceneBolt(vec2 p, float t) {
  vec3 col = vec3(0.02, 0.02, 0.04);
  float tt = floor(t * 2.5); // de takken verspringen een paar keer per seconde
  for (int i = 0; i < 6; i++) {
    float fi = float(i);
    vec2 q = p * rot(fi * 1.047 + 0.3 * sin(t * 0.3));
    float n = fbm(vec2(q.y * 3.0 + fi * 7.0, tt * 0.37 + fi)) - 0.5;
    float n2 = noise(vec2(q.y * 14.0, tt + fi * 3.0)) - 0.5;
    float d = abs(q.x + n * abs(q.y) + n2 * 0.05) + step(q.y, 0.0) * 10.0;
    vec3 c = mix(vec3(0.6, 0.7, 1.0), vec3(0.3, 1.0, 0.5), step(3.0, fi));
    col += c * (0.004 / (d + 0.004)) * (0.5 + 0.5 * hash21(vec2(fi, tt)));
  }
  col += vec3(0.7, 0.8, 1.0) * 0.012 / (dot(p, p) + 0.03);
  return col;
}

// ---------- Stekels ----------
vec3 sceneSpikes(vec2 p, float t) {
  float r = length(p);
  float a = atan(p.y, p.x);
  vec3 col = vec3(0.03);
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float n = 24.0 + fi * 17.0;
    float aa = (a + t * (0.15 + fi * 0.1) * (mod(fi, 2.0) * 2.0 - 1.0)) / TAU * n;
    float k = mod(floor(aa), n);
    float len = (0.3 + 0.5 * hash21(vec2(k, fi))) * (0.6 + 0.4 * sin(t * 3.0 + k)) * (1.0 - fi * 0.22);
    float w = abs(fract(aa) - 0.5) * 2.0;
    float m = smoothstep(0.0, 0.08, (1.0 - r / len) - w);
    vec3 c = chrome(r * 4.0 + w * 0.8 - t * 0.3 + fi * 0.3, fi * 0.3 + t * 0.05);
    col = max(col, c * (0.3 + 0.7 * (1.0 - w)) * m);
  }
  col *= smoothstep(0.04, 0.12, r);
  return col;
}

// ---------- Ogen ----------
vec3 sceneEyes(vec2 p, float t) {
  vec2 g = p * 4.0 + vec2(t * 0.1, 0.0);
  vec2 id = floor(g);
  vec2 c = fract(g) - 0.5;
  float h = hash21(id);
  float blink = smoothstep(0.0, 0.1, abs(sin(t * (0.8 + h * 1.5) + h * 20.0)));
  float ly = 0.28 * blink;
  float e = (c.x * c.x) / 0.1764 + (c.y * c.y) / (ly * ly + 0.0001);
  float open = 1.0 - smoothstep(0.9, 1.0, e);
  vec2 look = 0.1 * vec2(sin(t * 1.3 + h * 30.0), cos(t * 1.7 + h * 17.0));
  vec2 cl = c - look;
  float d = length(cl);
  vec3 iris = pal(h + d * 4.0 - t * 0.3, vec3(0.5), vec3(0.5), vec3(1.0, 0.9, 0.8), vec3(0.55, 0.6, 0.1));
  iris *= 0.6 + 0.4 * sin(atan(cl.y, cl.x) * 24.0);
  vec3 eye = mix(vec3(0.92, 0.9, 0.88), iris, 1.0 - smoothstep(0.15, 0.17, d));
  eye *= smoothstep(0.05, 0.07, d);
  vec3 bg = pal(h * 3.0 + t * 0.1, vec3(0.2), vec3(0.2), vec3(1.0), vec3(0.6, 0.1, 0.3));
  vec3 col = mix(bg * 0.5, eye, open);
  col += vec3(1.0, 0.9, 0.7) * (1.0 - smoothstep(0.0, 0.06, abs(e - 1.0))) * 0.6;
  return col;
}

// ---------- Lotus ----------
vec3 sceneLotus(vec2 p, float t) {
  vec3 col = vec3(0.01, 0.01, 0.04);
  float water = step(p.y, -0.18);
  vec2 q = p;
  if (p.y < -0.18) {
    // spiegeling met rimpels die sterker worden naar onderen
    q.y = -0.36 - p.y;
    q.x += 0.03 * sin(p.y * 60.0 + t * 3.0) * (1.0 + (-0.18 - p.y) * 4.0);
  }
  q.y -= 0.12;
  for (int i = 0; i < 5; i++) {
    float fi = float(i);
    float n = 6.0 + fi * 3.0;
    float sc = (1.0 - fi * 0.17) * (0.9 + 0.08 * sin(t * 1.5 + fi));
    float a = atan(q.y, q.x) + fi * 0.4 + sin(t * 0.6 + fi) * 0.08;
    float r = length(q) / sc;
    float pet = abs(cos(a * n * 0.5));
    float edge = 0.42 * pow(pet, 0.6) + 0.08;
    float m = 1.0 - smoothstep(edge - 0.02, edge, r);
    vec3 c = chrome(r * 2.5 - pet * 0.6 + fi * 0.21 - t * 0.15, fi * 0.19 + t * 0.07);
    c *= 0.45 + 0.55 * smoothstep(0.0, edge, r);
    col = mix(col, c, m);
  }
  col = witness(col, q, 0.09, t);
  col *= mix(1.0, 0.55, water);
  col += vec3(0.6, 0.8, 1.0) * 0.4 * (1.0 - smoothstep(0.0, 0.006, abs(p.y + 0.18)));
  return col;
}

// ---------- Vleugels ----------
vec3 sceneWings(vec2 p, float t) {
  vec3 col = vec3(0.02, 0.02, 0.05);
  vec2 q = vec2(abs(p.x), p.y);
  float flap = 0.25 * sin(t * 1.2);
  // drie paar vleugels: omhoog, opzij en omlaag
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    vec2 w = rot((0.9 - fi * 0.75) + flap * (1.0 - fi * 0.3)) * q;
    float u = w.x / (0.85 - fi * 0.12);
    float fid = floor(u * 14.0);
    float feather = fract(u * 14.0);
    float width = 0.28 * sin(clamp(u, 0.0, 1.0) * 3.14159) * (1.0 - 0.3 * u) * (0.75 + 0.25 * feather);
    float inside = step(0.0, u) * step(u, 1.0) * (1.0 - smoothstep(width - 0.01, width, abs(w.y)));
    vec3 c = pal(fid * 0.07 + fi * 0.33 + t * 0.1, vec3(0.6), vec3(0.4), vec3(1.0), vec3(0.0, 0.33, 0.67));
    c *= 0.35 + 0.65 * feather;
    col = mix(col, c, inside);
  }
  return witness(col, p, 0.17, t);
}

// ---------- Schotel ----------
vec3 sceneSaucer(vec2 p, float t) {
  vec3 col = mix(vec3(0.9, 0.35, 0.2), vec3(0.03, 0.02, 0.15), smoothstep(-0.35, 0.5, p.y));
  vec2 si = floor(p * 30.0);
  col += step(0.985, hash21(si)) * (0.5 + 0.5 * sin(t * 3.0 + hash21(si + 1.0) * 40.0));
  float horizon = -0.3 + 0.03 * noise(vec2(p.x * 4.0, 1.0));
  if (p.y < horizon) {
    col = vec3(0.03, 0.02, 0.05) + vec3(0.2, 0.05, 0.25) * noise(vec2(p.x * 20.0, p.y * 60.0)) * 0.3;
  }
  vec2 q = p - vec2(0.25 * sin(t * 0.5), 0.2 + 0.05 * sin(t * 1.3));
  // lichtbundel onder de schijf
  float beam = (1.0 - smoothstep(0.0, 0.06 - q.y * 0.35, abs(q.x))) * step(q.y, 0.0);
  col += pal(q.y * 3.0 + t * 0.8, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67))
         * beam * 0.55 * (0.6 + 0.4 * sin(q.y * 60.0 + t * 10.0));
  float e = length(q * vec2(1.0, 3.5));
  float disc = 1.0 - smoothstep(0.3, 0.32, e);
  col = mix(col, chrome(e * 3.0 - t * 0.5, t * 0.1), disc);
  float dome = (1.0 - smoothstep(0.1, 0.11, length((q - vec2(0.0, 0.04)) * vec2(1.0, 1.3)))) * step(0.02, q.y);
  col = mix(col, vec3(0.5, 0.9, 1.0) * (0.6 + 0.4 * sin(t * 4.0)), dome);
  // lampjes die langs de rand lopen
  float lamp = q.x / 0.6 * 8.0 + t * 1.5;
  col += pal(floor(lamp) * 0.13, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67))
         * disc * step(0.7, fract(lamp)) * step(abs(q.y), 0.03) * 1.5;
  col += vec3(0.4, 0.8, 1.0) * 0.02 / (e * e + 0.03);
  return col;
}

// ---------- Leegte ----------
vec2 project(vec3 v, float t) {
  float ca = cos(t * 0.5);
  float sa = sin(t * 0.5);
  v = vec3(v.x * ca + v.z * sa, v.y, -v.x * sa + v.z * ca);
  float cb = cos(0.5);
  float sb = sin(0.5);
  v = vec3(v.x, v.y * cb - v.z * sb, v.y * sb + v.z * cb);
  return v.xy * (0.3 / (1.0 + v.z * 0.3));
}

vec3 sceneVoid(vec2 p, float t) {
  vec3 col = vec3(0.0);
  vec2 sg = p * 40.0;
  vec2 si = floor(sg);
  float star = step(0.992, hash21(si)) * (1.0 - smoothstep(0.0, 0.25, length(fract(sg) - 0.5)));
  col += vec3(star) * (0.4 + 0.6 * sin(t + hash21(si + 1.0) * 30.0));

  // een zwevend achtvlak, alleen de ribben
  p.y -= 0.03 * sin(t * 0.8);
  vec2 px = project(vec3(1.0, 0.0, 0.0), t);
  vec2 nx = project(vec3(-1.0, 0.0, 0.0), t);
  vec2 pz = project(vec3(0.0, 0.0, 1.0), t);
  vec2 nz = project(vec3(0.0, 0.0, -1.0), t);
  vec2 top = project(vec3(0.0, 1.3, 0.0), t);
  vec2 bot = project(vec3(0.0, -1.3, 0.0), t);
  float d = min(min(seg(p, px, pz), seg(p, pz, nx)), min(seg(p, nx, nz), seg(p, nz, px)));
  d = min(d, min(min(seg(p, top, px), seg(p, top, nx)), min(seg(p, top, pz), seg(p, top, nz))));
  d = min(d, min(min(seg(p, bot, px), seg(p, bot, nx)), min(seg(p, bot, pz), seg(p, bot, nz))));
  col += vec3(1.0) * (0.003 / (d + 0.003));
  return col;
}
