// Etheral — engel 2: een ring met ogen rond één groot oog, gedragen door zes vleugels.
void main() {
  vec2 q = (gl_FragCoord.xy - 0.5 * uRes) / uRes.y;
  float size = 0.34 * uAngel.x * (1.0 + 0.03 * sin(uTime * 1.3));
  vec2 l = q / max(size, 0.001);
  if (length(l) > 4.5) discard;
  float t = uTime;

  vec4 light = halo(l, t);
  vec3 col = light.rgb;
  float alpha = light.a;

  // drie paar vleugels (omhoog, opzij, omlaag), gespiegeld over het midden
  vec2 m = vec2(abs(l.x), l.y);
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    // w.x loopt langs de vleugel naar de punt, w.y staat er dwars op
    vec2 w = rot((0.75 - fi * 0.72) + 0.09 * sin(t * 1.2 + fi * 1.3)) * m;
    float u = w.x / (1.9 - fi * 0.3);
    float uc = clamp(u, 0.0, 1.0);
    w.y += 0.32 * uc * uc; // de vleugel buigt naar de punt toe af
    // de veren hangen schuin aan de voorrand en worden naar de punt toe langer
    float fx = u * 15.0 + w.y * 2.2;
    float feather = fract(fx);
    float drop = 0.62 * sin(pow(uc, 0.75) * 3.14159) * (1.0 - 0.25 * uc) * (0.7 + 0.3 * feather);
    // boven de voorrand niets, eronder de veren
    float inside = step(0.0, u) * step(u, 1.0)
                 * (1.0 - smoothstep(0.02, 0.045, w.y))
                 * (1.0 - smoothstep(drop - 0.02, drop, -w.y));
    // elke veer loopt van een donkere rand naar een lichte schacht; de dekveren
    // bij de voorrand zijn lichter dan de slagpennen eronder
    vec3 fcol = mix(vec3(0.3, 0.27, 0.24), vec3(0.97, 0.94, 0.86), smoothstep(0.0, 0.7, feather));
    fcol *= 0.62 + 0.38 * smoothstep(0.35, 0.0, -w.y / max(drop, 0.001));
    fcol *= 1.0 - 0.1 * fi;
    col = mix(col, fcol, inside);
    alpha = max(alpha, inside);
  }

  // de ring met acht ogen
  vec4 c = ring(l, 0.36, 0.0, t * 0.25, 8.0, uAngel.z, t);
  col = mix(col, c.rgb, c.a);
  alpha = max(alpha, c.a);

  // het donkere hart met één groot oog dat je aankijkt
  float inner = 1.0 - smoothstep(0.29, 0.31, length(l));
  col = mix(col, vec3(0.06, 0.05, 0.08), inner * 0.9);
  alpha = max(alpha, inner * 0.9);
  col = mix(col, witness(col, l - uMouse * 0.02, 0.24, t), inner);

  gl_FragColor = vec4(col, alpha * uAngel.y);
}
