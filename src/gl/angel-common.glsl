// Etheral — gedeeld door de twee engelen aan het eind van de duik.
// Vrij naar de engelen uit het boek Ezechiël: wielen in wielen vol ogen, en een
// ring met vleugels. De vormen hier zijn zelf in code getekend.
uniform vec4 uAngel; // x = groei (0..1), y = zichtbaarheid (0..1), z = willekeurig zaad

// Eén wiel: een ring die in de ruimte kantelt (tilt) en draait (spin), bezet met ogen.
// Geeft kleur en dekking terug.
vec4 ring(vec2 l, float R, float tilt, float spin, float count, float seed, float t) {
  vec2 q = rot(spin) * l;
  float b = max(abs(cos(tilt)), 0.12); // een gekantelde cirkel wordt een ellips
  vec2 qs = vec2(q.x, q.y / b);
  float rad = length(qs) + 0.0001;
  float squash = mix(b, 1.0, (qs.x * qs.x) / (rad * rad));
  float across = (rad - R) * squash;
  float w = 0.055; // halve dikte van de ring
  float band = 1.0 - smoothstep(w, w + 0.012, abs(across));
  if (band <= 0.0) return vec4(0.0);

  // positie langs de ring; de ogen schuiven langzaam rond
  float th = atan(qs.y, qs.x) / TAU * count + t * 0.12 * (0.5 + fract(seed));
  float id = floor(th);
  float arc = TAU * R / count;
  float along = (fract(th) - 0.5) * arc;

  // de ring zelf: een bolle buis met een gekerfd oppervlak
  vec3 col = vec3(0.93, 0.88, 0.74) * (0.5 + 0.5 * cos(across / w * 1.5708));
  col *= 0.82 + 0.18 * sin(th * TAU * 3.0);

  // een amandelvormig oog dat af en toe knippert
  float h = hash21(vec2(id, seed + R * 10.0));
  float blink = step(0.07, fract(h * 7.0 + t * 0.21 * (0.5 + h)));
  float ew = arc * 0.42;
  float eh = w * 0.64;
  float lid = eh * blink + 0.004;
  float e = (along * along) / (ew * ew) + (across * across) / (lid * lid);
  if (e < 1.0) {
    vec2 look = uMouse * eh * 0.25; // de ogen volgen je cursor
    float dd = length(vec2(along, across) - look);
    vec3 iris = pal(h + t * 0.05, vec3(0.5), vec3(0.5), vec3(1.0, 0.8, 0.6), vec3(0.0, 0.15, 0.3));
    vec3 eye = mix(vec3(0.97), iris, 1.0 - smoothstep(eh * 0.52, eh * 0.6, dd));
    eye *= smoothstep(eh * 0.18, eh * 0.26, dd);
    col = mix(eye, vec3(0.05), smoothstep(0.78, 1.0, e)); // donkere rand van het ooglid
  }
  return vec4(col, band);
}

// Lichtkrans: stralen en een gloeiende kern achter de engel.
vec4 halo(vec2 l, float t) {
  float r = length(l);
  float a = atan(l.y, l.x);
  float rays = pow(0.5 + 0.5 * sin(a * 14.0 + sin(a * 5.0 + t * 0.4) * 2.0), 3.0) * exp(-r * 1.2);
  float core = 0.1 / (r * r + 0.09);
  vec3 col = vec3(1.0, 0.93, 0.75) * rays * 0.9 + vec3(1.0, 0.97, 0.9) * core;
  return vec4(col, clamp(rays * 0.75 + core * 0.9, 0.0, 1.0));
}
