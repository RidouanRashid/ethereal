// Etheral — de main() die achter elk visioen wordt geplakt.
// De aanroep van het visioen (zie "max(...)" hieronder) krijgt in stage.js de juiste functienaam.
// Dezelfde main tekent het volledige beeld én de losse mozaïekvakken.
uniform vec4 uRect;        // rechthoek waarin getekend wordt, in pixels (x, y, breedte, hoogte)
uniform float uCell;       // 0 = volledig beeld, 1 = mozaïekvak
uniform float uSeed;       // tijdverschuiving, zodat een vak er anders uitziet
uniform float uMirrorMode; // 0 = niets, 1 = gespiegeld, 2 = caleidoscoop
uniform float uRotQ;       // rotatie van het vak
uniform float uHue;        // kleurdraaiing voor dit visioen
uniform float uWarpK;      // 0..1: voortgang van de overgang naar het volgende visioen
uniform float uDissolve;   // 1 = dit is het binnenkomende visioen (alpha = oplos-masker)
uniform float uGain;       // helderheid
uniform float uChaos;
uniform float uVoid;       // 0..1: voortgang van de periodieke duik (elke 11 seconden)
uniform float uSpeed;      // 0..1,5: hoe hard je "reist"; geeft snelheidsstrepen
uniform float uFlash;      // 1 -> 0 vlak na aankomst uit een duik

void main() {
  vec2 p = (gl_FragCoord.xy - (uRect.xy + 0.5 * uRect.zw)) / min(uRect.z, uRect.w);
  float t = uTime * 1.7 + uSeed;
  float ch = uChaos;
  float rs = length(p); // afstand tot het midden van het scherm, vóór alle vervorming
  vec2 ps = p;          // schermpositie, vóór alle vervorming
  float rib = 1.0;      // schaduw op de ribben van de tunnel

  if (uCell < 0.5) {
    // duik: een eindeloze tunnel. Het visioen wordt in ringen om het midden herhaald
    // (logaritmisch, dus elke ring is een even grote kopie), en die ringen schuiven
    // versnellend naar buiten. Je wordt naar binnen gezogen, maar het beeld blijft
    // op dezelfde afstand en raakt nooit "op".
    if (uVoid > 0.0) {
      float d = uVoid;
      // het beeld schudt steeds harder
      p += d * d * 0.05 * vec2(sin(uTime * 47.0), cos(uTime * 61.0));
      float r = length(p) + 0.0001;
      float screenAng = atan(p.y, p.x);
      // aanzuigen: de randen rekken uit en het beeld schroeft de diepte in
      float ang = screenAng + d * d * 0.3 * (0.6 - log(r));
      // uit elkaar getrokken: het beeld breekt in 16 scherven die elk met een eigen
      // snelheid wegschieten, waardoor het langs de naden openscheurt
      float sector = (screenAng / TAU + 0.5) * 16.0;
      float shard = hash21(vec2(floor(sector), 3.0)) - 0.5;
      float tear = smoothstep(0.25, 1.0, d);
      float z = 13.0 * pow(d, 2.5) * (1.0 + tear * 1.2 * shard); // afgelegde afstand
      // log(r) wordt platter gemaakt: de ringen rekken uit naar de rand (spaghettificatie)
      float u = log(r) * (1.0 - 0.55 * d * d) - z + tear * shard * 0.8;
      // driehoeksgolf: opeenvolgende ringen zijn elkaars spiegelbeeld, dus zonder naad
      // Elke ring bevat bijna het hele visioen (van 0,12 tot 0,89 van het beeld),
      // zodat je blijft zien door welk visioen je reist.
      float m = abs(mod(u, 4.0) - 2.0);
      vec2 tunnel = vec2(cos(ang), sin(ang)) * 0.12 * exp(m);
      p = mix(p, tunnel, smoothstep(0.0, 0.12, d));
      rib = mix(1.0, 0.75 + 0.25 * sin(m / 2.0 * 3.14159265), smoothstep(0.0, 0.2, d));
      // donkere scheuren op de naden tussen de scherven
      rib *= 1.0 - tear * 0.85 * smoothstep(0.42, 0.5, abs(fract(sector) - 0.5));
    }
    // bij aankomst is het beeld heel even te groot en veert het terug
    p *= 1.0 - 0.25 * uFlash;
    // snelheidsstrepen: per richting een andere rek, sterker naar de rand
    float streak = noise(normalize(p + 0.0001) * 12.0 + uTime * 9.0);
    p *= 1.0 - uSpeed * 0.3 * streak * smoothstep(0.0, 0.5, length(p));
    // hartslag: 1,5 keer per seconde een zoomstoot en een tik aan de rotatie
    float beat = uTime * 1.5;
    float kick = exp(-fract(beat) * 5.0) * ch;
    p *= 1.0 - 0.07 * kick;
    p *= rot(0.05 * sin(uTime * 0.7) * ch + 0.16 * kick * (hash21(vec2(floor(beat), 1.0)) - 0.5));
    p += uMouse * 0.03;
    p += 0.03 * (1.0 + ch) * vec2(sin(p.y * 3.0 + uTime * 0.4), cos(p.x * 3.0 - uTime * 0.34));
  } else {
    p *= 1.1;
  }
  vec2 pn = p;

  if (uMirrorMode > 1.5) {
    float slice = TAU / 6.0;
    float a = abs(mod(atan(p.y, p.x) + uTime * 0.2, slice) - slice * 0.5);
    p = vec2(cos(a), sin(a)) * length(p);
  } else if (uMirrorMode > 0.5) {
    p.x = abs(p.x);
  }
  p *= rot(uRotQ);

  // overgang = reizen: het oude visioen schiet versnellend op je af (inzoomen),
  // het nieuwe komt uit de verte aanvliegen tot het op zijn plek valt
  float k = uWarpK;
  float warp = sin(k * 3.14159265);
  if (uDissolve > 0.5) {
    p *= exp(2.4 * (1.0 - k) * (1.0 - k));
    p *= rot(-0.5 * (1.0 - k) * (1.0 - k));
  } else {
    p *= exp(-3.2 * k * k);
    p *= rot(0.5 * k * k);
  }

  vec3 col = max(__SCENE__(p, t), 0.0);

  // het binnenkomende visioen opent zich vanuit het midden: het punt waar je
  // naartoe vliegt wordt een gat dat versnellend groter wordt, met een lichtrand
  float alpha = 1.0;
  if (uDissolve > 0.5) {
    float rr = length(pn);
    float radius = k * k * 1.9;
    float n = fbm(pn * 3.0 + t * 0.05);
    alpha = (1.0 - smoothstep(radius - 0.2, radius + 0.02, rr + (n - 0.5) * 0.25)) * smoothstep(0.0, 0.15, k);
    col += vec3(1.0, 0.95, 0.85) * exp(-abs(rr - radius) * 12.0) * warp * 0.8;
  }
  // bij aankomst uit een duik licht het midden van het visioen even op
  col *= 1.0 + uFlash * 2.5 * exp(-length(pn) * 2.0);

  // ---- kleur: door het hele kleurenwiel, met een verloop over het beeld
  float hue = uHue + p.x * 1.5 + length(p) * 2.5 * sin(uTime * 0.23);
  col = max(hueRot(col, hue), 0.0);
  // grijze en witte delen krijgen een tint uit het volle spectrum
  float hi = max(col.r, max(col.g, col.b));
  float lo = min(col.r, min(col.g, col.b));
  float sat = (hi - lo) / (hi + 0.001);
  vec3 tint = pal(hue * 0.16 + hi * 0.5, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67));
  col = mix(col, col * tint * 1.9, (1.0 - sat) * 0.6);
  float lum = dot(col, LUMA);
  col = max(mix(vec3(lum), col, 1.6), 0.0);

  // ---- snelheidsstrepen van het visioen zelf: langs stralen vanuit het midden licht
  //      het visioen in pulsen op. Er komt geen losse witte laag overheen; de strepen
  //      hebben dus altijd de kleuren van het visioen waar je doorheen reist.
  if (uCell < 0.5 && uVoid > 0.0) {
    float d = uVoid;
    col *= rib;
    float a = atan(ps.y, ps.x) / TAU * 260.0;
    float h = hash21(vec2(floor(a), 7.0));
    float line = step(0.6, h) * (1.0 - abs(fract(a) - 0.5) * 2.0);
    // elke streep is een reeks pulsen die naar buiten rent, langer bij meer snelheid
    float pulse = smoothstep(0.35 - 0.3 * d, 1.0, fract(log(rs + 0.001) * 0.9 - uTime * (2.0 + 6.0 * h) * d - h * 10.0));
    col *= 1.0 + line * pulse * d * d * 4.0 * smoothstep(0.03, 0.25, rs);
    // het punt waar je naartoe wordt gezogen gloeit in de kleur van het visioen
    col *= 1.0 + d * d * 0.12 / (rs * rs + 0.03);
  }

  // wit kader om een mozaïekvak
  if (uCell > 0.5) {
    vec2 l = abs((gl_FragCoord.xy - uRect.xy) / uRect.zw - 0.5);
    col += vec3(1.0) * step(0.49, max(l.x, l.y)) * 0.6;
  }

  // belichting op helderheid: felle kleuren blijven verzadigd
  col = min(col * 1.7 / (1.0 + dot(col, LUMA) * 1.1), 1.0) * uGain;
  gl_FragColor = vec4(col, alpha);
}
