// Etheral — pass 2: glitch over het hele beeld (stroken, blokken, RGB-split, korrel).
precision highp float;

uniform sampler2D uTex;
uniform vec2 uRes;
uniform float uTime;
uniform float uChaos;
uniform float uSpeed; // 0..1,5: hoe hard je "reist"

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

void main() {
  vec2 uv = gl_FragCoord.xy / uRes;
  float ch = uChaos; // valt tijdens de "leegte" vanzelf naar 0 (zie stage.js)

  // horizontale stroken die opzij schieten
  float tk = floor(uTime * 7.0);
  float band = floor(uv.y * mix(6.0, 40.0, hash21(vec2(tk, 1.0))));
  // bij snelheid verspringen veel meer stroken, en verder: het beeld wordt uiteengerukt
  float on = step(1.0 - 0.18 * ch - 0.4 * min(uSpeed, 1.0), hash21(vec2(band, tk)));
  uv.x += on * (hash21(vec2(band, tk + 3.0)) - 0.5) * (0.25 + 0.35 * uSpeed);

  // blokken die verpixelen of van kleur wisselen
  vec2 bid = floor(uv * vec2(6.0, 4.0));
  float bh = hash21(bid + floor(uTime * 2.3) * 3.0);
  if (bh < 0.07 * ch) {
    float n = mix(20.0, 90.0, hash21(bid + 1.0));
    uv = (floor(uv * n) + 0.5) / n;
  }

  // RGB-split: rood en blauw schuiven uit elkaar, sterker naar de rand
  vec2 d = (uv - 0.5) * (0.006 + 0.03 * ch * (0.5 + 0.5 * sin(uTime * 3.0))) * step(0.01, ch);
  d *= 1.0 + 7.0 * uSpeed; // bij snelheid trekken de kleuren verder uit elkaar
  d.x += 0.004 * ch * sin(uTime * 11.0);
  vec3 col = vec3(texture2D(uTex, uv + d).r, texture2D(uTex, uv).g, texture2D(uTex, uv - d).b);

  if (bh > 1.0 - 0.05 * ch) col = 1.0 - col;
  else if (bh > 1.0 - 0.1 * ch) col = col.gbr;

  // meer contrast en verzadiging, zodat de lagen niet dichtslibben
  col = pow(max(col, 0.0), vec3(1.3)) * 1.15;
  float l = dot(col, vec3(0.299, 0.587, 0.114));
  col = max(mix(vec3(l), col, 1.25), 0.0);

  col *= 0.93 + 0.07 * sin(gl_FragCoord.y * 1.5);
  vec2 v = uv - 0.5;
  col *= max(1.0 - (0.9 + 1.6 * uSpeed) * dot(v, v), 0.0); // tunnelzicht bij snelheid
  col += (hash21(gl_FragCoord.xy + fract(uTime) * 100.0) - 0.5) * 0.04;
  gl_FragColor = vec4(max(col, 0.0), 1.0);
}
