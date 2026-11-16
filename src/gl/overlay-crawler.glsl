// Etheral — overlay: de kruiper. Een pikzwart silhouet op handen en knieën waarvan
// alleen de ogen oplichten. Positie, tempo en hoofdhoek komen uit crawler.js.
uniform vec4 uCrawl;     // x, y (midden van het lichaam), schaal, richting (+1 of -1)
uniform vec4 uCrawlPose; // fase van de pas, hoofd (0..1), flip (-1 = aan het plafond), alpha
uniform vec2 uCrawlLook; // waar de ogen naar kijken

const float GROUND = -0.36;

float sdCapsule(vec2 p, vec2 a, vec2 b, float r) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  float h = clamp(dot(pa, ba) / (dot(ba, ba) + 0.00001), 0.0, 1.0);
  return length(pa - ba * h) - r;
}

// Elleboog of knie: het gewricht tussen twee botten van lengte a en b.
vec2 joint(vec2 s, vec2 e, float a, float b, float bend) {
  vec2 d = e - s;
  float len = max(length(d), 0.0001);
  vec2 n = d / len;
  float l = min(len, a + b - 0.001);
  float x = (a * a - b * b + l * l) / (2.0 * l);
  float y = sqrt(max(a * a - x * x, 0.0));
  return s + n * x + vec2(-n.y, n.x) * y * bend;
}

float arm(vec2 p, vec2 shoulder, float ph) {
  // hand op de grond schuift naar achteren, in de lucht zwaait hij naar voren
  vec2 hand = vec2(shoulder.x + 0.06 - 0.2 * cos(ph), GROUND + 0.1 * max(0.0, sin(ph)));
  vec2 elbow = joint(shoulder, hand, 0.24, 0.24, -1.0);
  return min(sdCapsule(p, shoulder, elbow, 0.045), sdCapsule(p, elbow, hand, 0.038));
}

float leg(vec2 p, vec2 hip, float ph) {
  float lift = max(0.0, sin(ph));
  vec2 knee = vec2(hip.x + 0.1 - 0.16 * cos(ph), GROUND + 0.03 + 0.07 * lift);
  vec2 foot = knee + vec2(-0.3, -0.02 + 0.06 * lift);
  return min(sdCapsule(p, hip, knee, 0.058), sdCapsule(p, knee, foot, 0.045));
}

void main() {
  vec2 q = (gl_FragCoord.xy - 0.5 * uRes) / uRes.y;
  vec2 l = (q - uCrawl.xy) / uCrawl.z;
  l.x *= uCrawl.w;
  l.y *= uCrawlPose.z;
  if (abs(l.x) > 1.3 || abs(l.y) > 0.95) discard; // buiten de figuur valt niets te tekenen

  float ph = uCrawlPose.x;
  float bob = 0.02 * sin(ph * 2.0);
  vec2 shoulder = vec2(0.3, 0.04 + bob);
  vec2 hip = vec2(-0.32, -0.02 - bob);

  // romp met een bolle rug
  float d = sdCapsule(l, hip, shoulder, 0.1);
  d = min(d, sdCapsule(l, hip + vec2(0.12, 0.05), shoulder + vec2(-0.06, 0.07), 0.085));
  // vier ledematen; diagonale paren bewegen samen, zoals bij echt kruipen
  d = min(d, arm(l, shoulder, ph));
  d = min(d, arm(l, shoulder + vec2(-0.03, 0.0), ph + 3.14159));
  d = min(d, leg(l, hip, ph + 3.14159));
  d = min(d, leg(l, hip + vec2(0.03, 0.0), ph));

  // hoofd: eerst draait het naar je toe (yaw), daarna kantelt het door tot het
  // ondersteboven staat (roll), zoals een uil
  float hh = uCrawlPose.y;
  float yaw = min(hh * 2.0, 1.0) * 1.5708;
  float roll = smoothstep(0.5, 1.0, hh) * 3.14159;
  vec2 hc = vec2(0.52, 0.2 + bob + 0.03 * sin(ph));
  d = min(d, sdCapsule(l, shoulder + vec2(0.05, 0.05), hc, 0.07));
  vec2 hl = rot(roll) * (l - hc);
  float head = length(hl * vec2(1.0, 0.88)) - 0.125;
  // de kin steekt van opzij naar voren en verdwijnt als hij je aankijkt
  head = min(head, sdCapsule(hl, vec2(0.02 * cos(yaw), -0.06), vec2(0.07 * cos(yaw), -0.11), 0.05));
  d = min(d, head);

  float body = 1.0 - smoothstep(0.0, 0.012, d);
  float aura = 0.45 * exp(-max(d, 0.0) * 16.0); // een donkere waas om hem heen

  // ogen: van opzij zie je er één, van voren twee
  float blink = step(0.05, fract(uTime * 0.31 + 0.3 * sin(uTime * 0.7)));
  float eyes = 0.0;
  float glow = 0.0;
  for (int i = 0; i < 2; i++) {
    float az = yaw + (float(i) * 2.0 - 1.0) * 0.42;
    float visible = smoothstep(-0.05, 0.2, sin(az)) * blink;
    vec2 e = vec2(0.105 * cos(az), 0.025);
    float de = length(hl - e);
    float pupil = 1.0 - smoothstep(0.006, 0.011, length(hl - e - uCrawlLook * 0.011));
    eyes += visible * (1.0 - smoothstep(0.018, 0.026, de)) * (1.0 - pupil);
    glow += visible * exp(-de * 38.0) * 0.9;
  }

  float light = clamp(eyes + glow, 0.0, 1.0);
  float alpha = max(max(body, aura), light) * uCrawlPose.w;
  gl_FragColor = vec4(vec3(1.0, 0.96, 0.75) * light, alpha);
}
