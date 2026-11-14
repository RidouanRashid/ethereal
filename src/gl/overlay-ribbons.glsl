// Etheral — overlay: regenbooglinten (wordt met alpha over het beeld getekend).
// Regenbooglinten die door het beeld slingeren. Alpha zegt waar een lint ligt.
vec4 ribbons(vec2 p, float t) {
  vec4 c = vec4(0.0);
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    vec2 q = rot(fi * 1.1 + 0.4 * sin(t * 0.2 + fi)) * p;
    float y = q.y - 0.35 * sin(q.x * 2.2 + t * (0.8 + fi * 0.3) + fi * 2.0) - (fi - 1.0) * 0.25;
    float m = 1.0 - smoothstep(0.065, 0.07, abs(y));
    vec3 stripe = pal(floor((y / 0.07 * 0.5 + 0.5) * 7.0) / 7.0,
                      vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67));
    c = mix(c, vec4(stripe, 1.0), m);
  }
  return c;
}

void main() {
  vec2 p = (gl_FragCoord.xy - 0.5 * uRes) / min(uRes.x, uRes.y);
  vec4 rb = ribbons(p, uTime * 1.7);
  gl_FragColor = vec4(min(rb.rgb * 1.1, 1.0), rb.a);
}
