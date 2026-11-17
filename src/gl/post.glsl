// Etheral — pass 2: nabewerking over het hele beeld.
// Klappen (klik/tik), opladen (vasthouden), glitch, RGB-split en korrel.
precision highp float;

uniform sampler2D uTex;    // het samengestelde beeld
uniform sampler2D uBehind; // een ander visioen, zichtbaar in de scheuren van een klap
uniform vec2 uRes;
uniform float uTime;
uniform float uChaos;
uniform float uSpeed; // 0..1,5: hoe hard je "reist"
uniform float uCalm;  // 1 tijdens de duik: bijna geen glitch, zodat je ziet waar je in duikt

// Tot vier klappen tegelijk: xy = plek, z = leeftijd in seconden, w = kracht (0 = uit).
// De plek staat in "aspect-ruimte": midden = (0,0), y van -0,5 tot 0,5.
uniform vec4 uShock0;
uniform vec4 uShock1;
uniform vec4 uShock2;
uniform vec4 uShock3;
uniform vec3 uCharge; // opladen: xy = plek, z = 0..1 hoe ver opgeladen

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
  float n = hash21(p);
  return vec2(n, hash21(p + n + 17.1));
}

mat2 rot(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat2(c, -s, s, c);
}

const float WINDUP = 0.09; // seconden aanloop vóór de klap losbarst

// Eén klap. Geeft terug hoe ver het beeld op dit punt wordt weggeduwd, en werkt
// crack (scheuren), split (kleuren uit elkaar), glow (gloeiende randen) en spark
// (vonken) bij.
vec2 shock(vec4 s, vec2 q, inout float crack, inout float split, inout float glow, inout float spark) {
  if (s.w <= 0.0) return vec2(0.0);
  vec2 v = q - s.xy;
  float dist = length(v) + 0.0001;
  vec2 dir = v / dist;
  float power = min(s.w, 2.5);

  // aanloop: heel even wordt het beeld naar het klikpunt gezogen (en staat de tijd
  // stil, zie stage.js). Die tegenbeweging maakt de klap daarna harder.
  float windup = 1.0 - smoothstep(0.0, WINDUP, s.z);
  vec2 off = -dir * windup * power * 0.07 * exp(-dist * 3.0);

  float age = max(s.z - WINDUP, 0.0);
  float burst = step(WINDUP, s.z);
  float life = exp(-age * 2.2) * burst; // de klap dooft uit
  float radius = age * 2.3;             // de ring loopt naar buiten

  // de schokgolf: een harde ring, met een zwakkere erachteraan
  float t = (dist - radius) / 0.08;
  float ring = exp(-t * t) * life * power;
  float t2 = (dist - radius * 0.6) / 0.06;
  ring += exp(-t2 * t2) * life * power * 0.45;
  split += ring;
  off += dir * ring * 0.16;

  // binnen de ring breekt het beeld in scherven (het sterkst bij het klikpunt)
  // de breuk zelf dooft veel sneller dan de ring: de scheuren trekken meteen weer dicht
  float inside = (1.0 - smoothstep(radius - 0.12, radius + 0.02, dist)) * exp(-age * 7.0) * burst * min(power, 2.0);
  inside *= exp(-dist * (1.6 - 0.4 * min(power, 2.0)));
  vec2 g = rot(s.x * 7.0 + s.y * 3.0) * v * 4.0;
  // het raster wordt verbogen, zodat de scherven grillig zijn in plaats van nette driehoeken
  g += 0.4 * sin(g.yx * 2.3 + s.xy * 20.0) + 0.2 * sin(g * 5.1 + s.yx * 9.0);
  vec2 id = floor(g);
  vec2 f = fract(g);
  vec2 key = id + step(1.0, f.x + f.y) * 17.0 + s.xy * 31.0;
  float h = hash21(key);
  // elke scherf vliegt een eigen stuk weg en draait daarbij om het klikpunt
  off += (dir * (0.04 + 0.2 * h) + (hash22(key) - 0.5) * 0.1) * inside;
  off += rot((h - 0.5) * 1.2 * inside) * v - v;

  // scheuren op de randen van de scherven, met een gloeiende rand ernaast
  float edge = min(min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)), abs(f.x + f.y - 1.0) * 0.707);
  float width = 0.012 + 0.14 * inside;
  float gate = smoothstep(0.0, 0.12, inside);
  crack = max(crack, (1.0 - smoothstep(0.0, width, edge)) * gate);
  glow = max(glow, (1.0 - smoothstep(width, width * 2.2 + 0.03, edge)) * gate);

  // vonken: brokjes die elk met een eigen snelheid naar buiten spatten
  float a = (atan(v.y, v.x) / 6.28318 + 0.5) * 46.0;
  float sh = hash21(vec2(floor(a), s.x * 13.0 + s.y * 7.0));
  float st = (dist - age * (1.0 + 2.6 * sh)) / 0.014;
  spark += step(0.45, sh) * pow(1.0 - abs(fract(a) - 0.5) * 2.0, 3.0)
           * exp(-st * st) * exp(-age * 3.0) * burst * power;
  return off;
}

// Hoe hard een klap op dit moment "aankomt": piekt bij het losbarsten, zakt snel weg.
float hit(vec4 s) {
  return s.w * exp(-max(s.z - WINDUP, 0.0) * 9.0) * step(WINDUP, s.z);
}

void main() {
  vec2 screen = gl_FragCoord.xy / uRes;
  vec2 aspect = vec2(uRes.x / uRes.y, 1.0);
  vec2 q = (screen - 0.5) * aspect;
  float ch = uChaos;

  // ---- impact: het hele scherm schudt en veert in op het moment van de klap
  float impact = min(hit(uShock0) + hit(uShock1) + hit(uShock2) + hit(uShock3), 2.5);
  q += impact * 0.018 * vec2(sin(uTime * 83.0), cos(uTime * 97.0));
  q *= 1.0 - 0.05 * impact;

  // ---- klappen
  float crack = 0.0;
  float split = 0.0;
  float glow = 0.0;
  float spark = 0.0;
  vec2 off = shock(uShock0, q, crack, split, glow, spark);
  off += shock(uShock1, q, crack, split, glow, spark);
  off += shock(uShock2, q, crack, split, glow, spark);
  off += shock(uShock3, q, crack, split, glow, spark);

  // ---- opladen: het beeld wordt naar je vinger gezogen, draait mee en trilt
  float charge = uCharge.z;
  float chargeDist = length(q - uCharge.xy);
  if (charge > 0.0) {
    vec2 v = q - uCharge.xy;
    float pull = charge * exp(-chargeDist * 2.2);
    off += v - rot(pull * 1.8) * v * (1.0 + pull * 0.9);
    off += charge * charge * 0.008 * vec2(sin(uTime * 90.0), cos(uTime * 71.0));
    split += charge * 0.5 * exp(-chargeDist * 2.0);
  }

  vec2 uv = (q - off) / aspect + 0.5;

  // ---- horizontale stroken die opzij schieten
  float tk = floor(uTime * 7.0);
  float band = floor(uv.y * mix(6.0, 40.0, hash21(vec2(tk, 1.0))));
  // bij snelheid verspringen veel meer stroken, en verder: het beeld wordt uiteengerukt
  float torn = min(uSpeed, 1.0) * (1.0 - uCalm); // uiteenrukken hoort bij scrollen, niet bij de duik
  float on = step(1.0 - 0.18 * ch - 0.4 * torn, hash21(vec2(band, tk)));
  uv.x += on * (hash21(vec2(band, tk + 3.0)) - 0.5) * (0.25 + 0.35 * torn);

  // ---- blokken die verpixelen of van kleur wisselen
  vec2 bid = floor(uv * vec2(6.0, 4.0));
  float bh = hash21(bid + floor(uTime * 2.3) * 3.0);
  if (bh < 0.07 * ch) {
    float n = mix(20.0, 90.0, hash21(bid + 1.0));
    uv = (floor(uv * n) + 0.5) / n;
  }

  // ---- RGB-split: rood en blauw schuiven uit elkaar, sterker naar de rand
  vec2 d = (uv - 0.5) * (0.006 + 0.03 * ch * (0.5 + 0.5 * sin(uTime * 3.0))) * step(0.01, ch);
  d *= 1.0 + mix(7.0, 1.5, uCalm) * uSpeed; // bij snelheid trekken de kleuren verder uit elkaar
  d.x += 0.004 * ch * sin(uTime * 11.0);
  d += normalize(q + 0.0001) * split * 0.035; // en langs de ring van een klap
  vec3 col = vec3(texture2D(uTex, uv + d).r, texture2D(uTex, uv).g, texture2D(uTex, uv - d).b);

  if (bh > 1.0 - 0.05 * ch) col = 1.0 - col;
  else if (bh > 1.0 - 0.1 * ch) col = col.gbr;

  // ---- in de scheuren van een klap zie je een ander visioen
  if (crack > 0.001) col = mix(col, texture2D(uBehind, screen).rgb * 1.2, crack);
  // ring, scherfranden en vonken lichten op in de kleuren van het beeld zelf
  // (geen witte flits over het hele scherm)
  col *= 1.0 + min(split, 1.5) * 0.6 + glow * 1.6;
  col += (col * 2.0 + 0.25) * min(spark, 1.5);
  // opladen: de randen worden donker, het punt onder je vinger gloeit
  col *= 1.0 - 0.45 * charge * smoothstep(0.15, 0.9, chargeDist);
  col *= 1.0 + charge * 1.2 * exp(-chargeDist * 9.0);

  // meer contrast en verzadiging, zodat de lagen niet dichtslibben
  col = pow(max(col, 0.0), vec3(1.3)) * 1.15;
  float l = dot(col, vec3(0.299, 0.587, 0.114));
  col = max(mix(vec3(l), col, 1.25), 0.0);

  col *= 0.93 + 0.07 * sin(gl_FragCoord.y * 1.5);
  vec2 v = screen - 0.5; // vanaf de schermpositie, zodat verschoven stroken niet zwart worden
  col *= max(1.0 - (0.9 + mix(1.6, 0.7, uCalm) * uSpeed) * dot(v, v), 0.0); // tunnelzicht bij snelheid
  col += (hash21(gl_FragCoord.xy + fract(uTime) * 100.0) - 0.5) * 0.04;
  gl_FragColor = vec4(max(col, 0.0), 1.0);
}
