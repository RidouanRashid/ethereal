// De kruiper: wanneer hij verschijnt, hoe snel hij kruipt en hoe zijn hoofd staat.
// Dit bestand rekent alleen; tekenen gebeurt in gl/overlay-crawler.glsl.

const EVERY = 30;        // om de hoeveel seconden hij verschijnt
const MIN_VISIBLE = 10;  // hoe lang hij minimaal in beeld is (seconden)
const MAX_VISIBLE = 12;  // en maximaal
const STARTLE_RADIUS = 0.55; // een klap binnen deze afstand laat hem schrikken (0 = nooit)

// Tempo's waar hij tussen wisselt: stilstaan, sluipen en sprinten.
const PACES = [0, 0.35, 0.35, 0.5, 2.6, 3];

export function createCrawler() {
  let active = null;
  let nextAt = EVERY;

  function spawn(now, aspect) {
    const duration = MIN_VISIBLE + Math.random() * (MAX_VISIBLE - MIN_VISIBLE);
    const scale = 0.42 + Math.random() * 0.24; // grootte: deel van de schermhoogte
    const dir = Math.random() < 0.5 ? 1 : -1;
    const ceiling = Math.random() < 0.25; // soms kruipt hij ondersteboven langs de bovenkant
    const margin = scale * 1.2;
    const distance = aspect + 2 * margin;
    const startX = -dir * (aspect / 2 + margin);
    const lift = 0.36 * scale + Math.random() * 0.3 * (1 - scale);
    const y = ceiling ? 0.5 - lift : -0.5 + lift;

    // Negen stukken met elk een eigen tempo en duur. Hij begint en eindigt in beweging.
    const segments = [];
    for (let i = 0; i < 9; i++) {
      let pace = PACES[Math.floor(Math.random() * PACES.length)];
      if ((i === 0 || i === 8) && pace === 0) pace = 0.5;
      segments.push({ pace, time: 0.6 + Math.random() * 0.8 });
    }
    // Schalen zodat de stukken samen precies de duur en de afstand vullen.
    const totalTime = segments.reduce((sum, s) => sum + s.time, 0);
    segments.forEach((s) => (s.time *= duration / totalTime));
    const totalPace = segments.reduce((sum, s) => sum + s.pace * s.time, 0);
    segments.forEach((s) => (s.speed = (s.pace * distance) / totalPace));
    const maxSpeed = Math.max(...segments.map((s) => s.speed));

    active = {
      start: now, duration, scale, dir, flip: ceiling ? -1 : 1,
      x: startX, y, endX: startX + dir * distance,
      segments, maxSpeed, speed: 0, phase: 0, head: 0, startled: 0, bolt: false,
    };
  }

  return {
    /**
     * Eén stap in de tijd. Geeft de toestand van de kruiper terug, of null als hij
     * niet in beeld is.
     */
    update(now, dt, aspect) {
      if (!active) {
        if (now < nextAt) return null;
        spawn(now, aspect);
        nextAt = (Math.floor(now / EVERY) + 1) * EVERY;
      }
      const c = active;
      const t = now - c.start;

      // welk tempo hoort bij dit moment?
      let target = c.maxSpeed * 1.5; // voorbij de geplande duur: wegwezen
      let elapsed = 0;
      for (const segment of c.segments) {
        if (t < elapsed + segment.time) {
          target = segment.speed;
          break;
        }
        elapsed += segment.time;
      }
      // geschrokken: eerst verstijven en je aanstaren, daarna wegsprinten
      if (c.startled > 0) {
        c.startled -= dt;
        target = 0;
        if (c.startled <= 0) c.bolt = true;
      } else if (c.bolt) {
        target = c.maxSpeed * 1.6;
      }

      c.speed += (target - c.speed) * Math.min(1, dt * 8);
      c.x += c.dir * c.speed * dt;
      // de passen volgen de snelheid: één volle pas is 0,8 lichaamslengte
      c.phase += ((c.speed * dt) / (0.8 * c.scale)) * Math.PI * 2;

      // hoofd: stilstaand draait het helemaal om, sluipend kijkt hij je aan,
      // sprintend kijkt hij vooruit. Omdraaien gaat met een ruk, terug gaat trager.
      const headTarget = target === 0 ? 1 : c.speed > c.maxSpeed * 0.5 ? 0 : 0.5;
      c.head += (headTarget - c.head) * Math.min(1, dt * (headTarget > c.head ? 9 : 4));

      const gone = c.dir > 0 ? c.x > c.endX : c.x < c.endX;
      if (gone || t > c.duration + 3) {
        active = null;
        return null;
      }
      return c;
    },

    /** Een klap op (x, y): schrikt hij ervan? */
    startle(x, y) {
      if (!active || active.bolt || active.startled > 0) return;
      if (Math.hypot(x - active.x, y - active.y) < STARTLE_RADIUS) active.startled = 0.45;
    },
  };
}
