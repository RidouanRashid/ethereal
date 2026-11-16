// Etheral — engel 1: wielen in wielen, elk bezet met ogen, draaiend om een lichtkern.
void main() {
  vec2 q = (gl_FragCoord.xy - 0.5 * uRes) / uRes.y;
  float size = 0.4 * uAngel.x * (1.0 + 0.03 * sin(uTime * 1.3));
  vec2 l = q / max(size, 0.001);
  if (length(l) > 4.0) discard;
  float t = uTime;
  float seed = uAngel.z;

  vec4 light = halo(l, t);
  vec3 col = light.rgb;
  float alpha = light.a;

  // vier wielen, elk met een eigen kanteling, draairichting en aantal ogen
  vec4 c = ring(l, 0.95, t * 0.5 + seed, t * 0.2, 26.0, seed, t);
  col = mix(col, c.rgb, c.a);
  alpha = max(alpha, c.a);
  c = ring(l, 0.78, 1.2 + t * 0.7, 1.0 - t * 0.3, 22.0, seed + 1.0, t);
  col = mix(col, c.rgb, c.a);
  alpha = max(alpha, c.a);
  c = ring(l, 0.6, 2.0 + t * 0.9, 2.0 + t * 0.45, 16.0, seed + 2.0, t);
  col = mix(col, c.rgb, c.a);
  alpha = max(alpha, c.a);
  c = ring(l, 0.42, 0.5 - t * 1.1, -t * 0.6, 12.0, seed + 3.0, t);
  col = mix(col, c.rgb, c.a);
  alpha = max(alpha, c.a);

  gl_FragColor = vec4(col, alpha * uAngel.y);
}
