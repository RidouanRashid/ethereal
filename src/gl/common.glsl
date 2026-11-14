// Etheral — gedeelde kop voor alle shaders: uniforms en gereedschap.
// Dit bestand wordt in stage.js vóór elke andere shader geplakt.
precision highp float;

uniform float uTime;
uniform vec2 uRes;
uniform vec2 uMouse;

#define TAU 6.28318530718
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

// ---- gereedschap
float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
  float n = hash21(p);
  return vec2(n, hash21(p + n + 17.1));
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
  float amp = 0.5;
  float sum = 0.0;
  for (int i = 0; i < 5; i++) {
    sum += amp * noise(p);
    p = p * 2.03 + vec2(1.7, 9.2);
    amp *= 0.5;
  }
  return sum;
}

// Cosinus-palet (Inigo Quilez): goedkoop en altijd vloeiend.
vec3 pal(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
  return a + b * cos(TAU * (c * t + d));
}

mat2 rot(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat2(c, -s, s, c);
}

// Afstand van punt p tot lijnstuk a-b.
float seg(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  float h = clamp(dot(pa, ba) / (dot(ba, ba) + 0.0001), 0.0, 1.0);
  return length(pa - ba * h);
}

// Vloeibaar chroom: donkere en felle banden met een regenboogrand.
vec3 chrome(float v, float tint) {
  float b = abs(fract(v) - 0.5) * 2.0;
  float m = smoothstep(0.1, 0.5, b) * 0.6 + pow(b, 8.0) * 1.2 + 0.08;
  vec3 ir = pal(v * 0.5 + tint, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67));
  return mix(vec3(m), ir * m * 1.6, 0.45);
}

// Het "getuige"-oog: een amandelvormig oog met regenboog-iris dat in meerdere visioenen terugkomt.
vec3 witness(vec3 col, vec2 p, float size, float t) {
  vec2 q = p / size;
  float lid = 0.55 * (0.75 + 0.25 * sin(t * 0.9));
  float e = q.x * q.x + (q.y * q.y) / (lid * lid);
  float d = length(q);
  vec3 iris = pal(d * 2.5 - t * 0.4, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67));
  iris *= 0.65 + 0.35 * sin(atan(q.y, q.x) * 28.0);
  vec3 eye = mix(vec3(0.95), iris, 1.0 - smoothstep(0.42, 0.46, d));
  eye *= smoothstep(0.14, 0.2, d);
  col = mix(col, eye, 1.0 - smoothstep(0.92, 1.0, e));
  col += vec3(1.0, 0.9, 0.8) * (1.0 - smoothstep(0.0, 0.12, abs(e - 1.0))) * 0.7;
  return col;
}

// Een verzonnen schriftteken: drie willekeurige streken in een vakje.
float glyph(vec2 p, vec2 id) {
  vec2 q = p - 0.5;
  float d = 10.0;
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    vec2 a = (floor(hash22(id + fi * 7.3) * 3.0) - 1.0) * 0.28;
    vec2 b = (floor(hash22(id + fi * 3.1 + 11.0) * 3.0) - 1.0) * 0.28;
    d = min(d, seg(q, a, b));
  }
  return 1.0 - smoothstep(0.03, 0.06, d);
}

// Kleur draaien rond de grijs-as: zo loopt alles door het hele kleurenwiel.
vec3 hueRot(vec3 c, float a) {
  const vec3 k = vec3(0.57735);
  float ca = cos(a);
  float sa = sin(a);
  return c * ca + cross(k, c) * sa + k * dot(k, c) * (1.0 - ca);
}
