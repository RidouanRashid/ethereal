// Etheral — samenvoegen: software-resten en de feedback-echo (ook de snelheidsstrepen).
uniform sampler2D uSceneTex; // de visioenen van dit frame
uniform sampler2D uPrev;     // het vorige eindbeeld
uniform float uFeedback;     // 0 = geen echo
uniform float uChaos;
uniform float uSpeed;      // 0..1,5: hoe hard je "reist"
uniform float uCalm;       // 1 tijdens de duik: minder smeren, zodat het visioen leesbaar blijft

void main() {
  vec2 uv = gl_FragCoord.xy / uRes;
  float asp = uRes.x / uRes.y;
  float ch = uChaos;
  vec3 col = texture2D(uSceneTex, uv).rgb;

  // software-resten: histogram onderin, kleurstalen links, een scanlijn
  float bin = floor(uv.x * 72.0);
  float hh = (0.02 + 0.13 * noise(vec2(bin * 0.35, uTime * 2.0 + bin))) * ch;
  if (uv.y < hh) {
    col += pal(bin / 72.0 + uTime * 0.2, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67)) * 0.6;
  }
  if (uv.x < 0.012 * step(0.01, ch)) {
    col = pal(floor(uv.y * 24.0) / 24.0 + uTime * 0.3, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67));
  }
  float scan = fract(uTime * 0.35);
  col += vec3(0.4, 0.6, 1.0) * 0.25 * ch * (1.0 - smoothstep(0.0, 0.004, abs(uv.y - scan)));

  col = clamp(col, 0.0, 1.0);
  float sp = min(uSpeed, 1.0);

  // feedback: het vorige frame zoomt, draait, golft en verkleurt, en blijft als
  // regenboog-echo achter in de donkere delen
  float kick = exp(-fract(uTime * 1.5) * 5.0) * ch;
  vec2 fuv = uv - 0.5;
  float dir = hash21(vec2(floor(uTime * 0.5), 9.0)) > 0.5 ? 1.0 : -1.0;
  fuv.x *= asp;
  fuv *= rot((0.012 + 0.03 * kick) * dir * ch);
  fuv.x /= asp;
  // bij snelheid schuift het vorige frame hard naar buiten: alles trekt uit tot strepen
  fuv *= 1.0 - (0.012 + 0.03 * kick) * ch - 0.07 * uSpeed;
  fuv += 0.003 * ch * vec2(sin(uv.y * 20.0 + uTime * 2.0), cos(uv.x * 20.0 - uTime * 2.0));
  vec3 prev = texture2D(uPrev, fuv + 0.5).rgb;
  prev = max(hueRot(prev, 0.25 * ch), 0.0);
  // echo's verzadigen en snel laten doven, anders wordt alles een grijze waas
  float pl = dot(prev, LUMA);
  prev = max(mix(vec3(pl), prev, 1.35), 0.0);
  float dark = 1.0 - smoothstep(0.15, 0.6, dot(col, LUMA));
  float keep = mix(0.87, 0.95, sp);                       // strepen blijven langer hangen
  float weight = mix(0.35 + 0.65 * dark, 1.0, sp * (0.6 - 0.4 * uCalm));  // en mogen ook over lichte delen
  col = max(col, (prev * keep - 0.012) * uFeedback * weight);

  gl_FragColor = vec4(col, 1.0);
}
