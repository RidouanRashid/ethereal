// Etheral — overlay: regen van verzonnen tekens (wordt bij het beeld opgeteld).
void main() {
  vec2 p = (gl_FragCoord.xy - 0.5 * uRes) / min(uRes.x, uRes.y);
  float t = uTime * 1.7;
  vec2 g = p * vec2(20.0, 13.0);
  float cx = floor(g.x);
  g.y += t * (1.0 + 3.0 * hash21(vec2(cx, 2.0)));
  float on = step(0.72, hash21(vec2(cx, floor(uTime * 0.9))));
  float fade = fract(g.y * 0.07 + hash21(vec2(cx, 5.0)));
  vec3 ink = pal(cx * 0.09 + uTime * 0.2, vec3(0.6), vec3(0.4), vec3(1.0), vec3(0.0, 0.33, 0.67));
  gl_FragColor = vec4(ink * glyph(fract(g), floor(g)) * on * fade, 1.0);
}
