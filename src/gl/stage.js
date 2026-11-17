import { Renderer, Program, Mesh, Triangle, RenderTarget } from 'ogl';
import common from './common.glsl?raw';
import scenesSource from './scenes.glsl?raw';
import sceneMain from './scene-main.glsl?raw';
import glyphsMain from './overlay-glyphs.glsl?raw';
import ribbonsMain from './overlay-ribbons.glsl?raw';
import compositeMain from './composite.glsl?raw';
import postFragment from './post.glsl?raw';
import crawlerMain from './overlay-crawler.glsl?raw';
import angelCommon from './angel-common.glsl?raw';
import angelWheels from './overlay-angel-wheels.glsl?raw';
import angelWings from './overlay-angel-wings.glsl?raw';
import { createCrawler } from '../crawler.js';

// Volgorde van de visioenen tijdens het scrollen: [kop in scenes.glsl, functienaam].
const ORDER = [
  ['Juweel', 'sceneJewel'],
  ['Lotus', 'sceneLotus'],
  ['Vloeistof', 'sceneLiquid'],
  ['Netwerk', 'sceneNet'],
  ['Ogen', 'sceneEyes'],
  ['Moiré', 'sceneMoire'],
  ['Circuit', 'sceneCircuit'],
  ['Vleugels', 'sceneWings'],
  ['Wolk', 'sceneCloud'],
  ['Oog', 'sceneEye'],
  ['Stekels', 'sceneSpikes'],
  ['Leegte', 'sceneVoid'],
  ['Cellen', 'sceneCells'],
  ['Organisme', 'sceneOrganism'],
  ['Helix', 'sceneHelix'],
  ['Schotel', 'sceneSaucer'],
  ['Tunnel', 'sceneTunnel'],
  ['Zegels', 'sceneSigils'],
  ['Bliksem', 'sceneBolt'],
  ['Spectrum', 'sceneSpectrum'],
  ['Tempel', 'sceneTemple'],
];
export const SCENE_COUNT = ORDER.length;
const NET_INDEX = ORDER.findIndex(([name]) => name === 'Netwerk');

// scenes.glsl opknippen in losse blokken, één per visioen.
const chunks = {};
scenesSource
  .split(/^\/\/ -{10} /m)
  .slice(1)
  .forEach((part) => {
    const end = part.indexOf('\n');
    const name = part.slice(0, end).replace(/ -{10}\s*$/, '').trim();
    chunks[name] = part.slice(end + 1);
  });

// Eén driehoek die het hele scherm bedekt.
const vertex = /* glsl */ `
  attribute vec2 position;
  void main() {
    gl_Position = vec4(position, 0.0, 1.0);
  }
`;

// Kleine, herhaalbare willekeur: dezelfde seed geeft dezelfde reeks getallen.
function randomFrom(seed) {
  let a = (seed * 2654435761) >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let x = Math.imul(a ^ (a >>> 15), 1 | a);
    x = (x + Math.imul(x ^ (x >>> 7), 61 | x)) ^ x;
    return ((x ^ (x >>> 14)) >>> 0) / 4294967296;
  };
}

const smooth = (a, b, x) => {
  const k = Math.min(Math.max((x - a) / (b - a), 0), 1);
  return k * k * (3 - 2 * k);
};

// De duik komt op wisselende momenten: tussen twee duiken zit 60 tot 90 seconden,
// de eerste komt na 30 tot 60 seconden. Hij duurt DIVE_TIME seconden.
const DIVE_GAP = [60, 90];
const DIVE_FIRST = [30, 60];
const DIVE_TIME = 8;
// De drie trappen: snel -> supersnel -> supersonisch.
// from = moment in de duik (0..1) waarop de trap begint, level = hevigheid,
// speed = hoe snel je door de tunnel gaat.
const DIVE_STAGES = [
  { from: 0, level: 0.4, speed: 1.6 },
  { from: 0.3, level: 0.7, speed: 5 },
  { from: 0.62, level: 1, speed: 14 },
];
const DIVE_BLEND = 0.14;  // hoe breed de overgang tussen twee trappen is (deel van de duik)
const LANDING_TIME = 2.6; // seconden afremmen na een duik

// De engel: verschijnt vlak voor het einde van de duik en blijft daarna nog even.
const ANGEL_LEAD = 1.8; // seconden vóór het einde van de duik
const ANGEL_STAY = 4.5; // seconden na het einde

// Het mozaïek wisselt van tempo: indelingen per seconde, van traag tot razend.
const MOSAIC_TEMPOS = [0.25, 0.4, 0.8, 1.4, 2.5, 4.5, 7];

// Indelingen van het mozaïek: [kolommen, rijen, kans dat deze gekozen wordt].
const GRIDS = [
  [1, 3, 0.25], // drie banden boven elkaar
  [3, 1, 0.17], // drieluik
  [2, 2, 0.16],
  [1, 2, 0.14],
  [4, 3, 0.14],
  [1, 1, 0.14], // geen mozaïek
];

/**
 * Zet het WebGL-canvas op en geeft een render-functie terug.
 * Geeft null terug als WebGL niet beschikbaar is.
 *
 * Elk visioen is een eigen kleine shader. Per frame gebeurt dit:
 *   1. het visioen van de scrollpositie naar een buffer (en het volgende eroverheen
 *      tijdens een overgang)
 *   2. mozaïekvakken met andere visioenen, elk in zijn eigen rechthoek (scissor)
 *   3. eventueel een overlay: netwerk, tekens of linten
 *   4. samenvoegen met de echo van het vorige frame
 *   5. glitch-nabewerking naar het scherm
 */
export function createStage(canvas, { reduce = false } = {}) {
  let renderer;
  try {
    renderer = new Renderer({
      canvas,
      dpr: Math.min(window.devicePixelRatio || 1, 1.25),
      alpha: false,
      antialias: false,
      depth: false,
      powerPreference: 'high-performance',
    });
    if (!renderer.gl) return null;
  } catch (error) {
    return null;
  }

  const gl = renderer.gl;
  const geometry = new Triangle(gl);

  // Als de videokaart het canvas afbreekt: stoppen en een melding tonen.
  let lost = false;
  canvas.addEventListener('webglcontextlost', (event) => {
    event.preventDefault();
    lost = true;
    document.documentElement.classList.add('no-webgl');
  });

  // ---------- uniforms ----------
  const shared = {
    uTime: { value: 0 },
    uRes: { value: [1, 1] },
    uMouse: { value: [0, 0] },
    uChaos: { value: 0 },
    uVoid: { value: 0 },
    uDiveZ: { value: 0 },
    uDiveGate: { value: 0 },
    uSpeed: { value: 0 },
    uFlash: { value: 0 },
    uBounce: { value: 0 },
    uCalm: { value: 0 },
  };
  // Deze waarden verschillen per tekenstap en worden vlak voor elke stap gezet.
  const draw = {
    uRect: { value: [0, 0, 1, 1] },
    uCell: { value: 0 },
    uSeed: { value: 0 },
    uMirrorMode: { value: 0 },
    uRotQ: { value: 0 },
    uHue: { value: 0 },
    uWarpK: { value: 0 },
    uDissolve: { value: 0 },
    uGain: { value: 1 },
  };
  const compositeUniforms = {
    ...shared,
    uSceneTex: { value: null },
    uPrev: { value: null },
    uFeedback: { value: reduce ? 0 : 1 },
  };
  const postUniforms = {
    ...shared,
    uTex: { value: null },
    uBehind: { value: null },
    uShock0: { value: [0, 0, 0, 0] },
    uShock1: { value: [0, 0, 0, 0] },
    uShock2: { value: [0, 0, 0, 0] },
    uShock3: { value: [0, 0, 0, 0] },
    uCharge: { value: [0, 0, 0] },
  };

  /** Maakt een shader + mesh. Geeft null terug als de videokaart hem weigert. */
  function makeMesh(fragment, uniforms, label) {
    const program = new Program(gl, { vertex, fragment, uniforms, depthTest: false, depthWrite: false });
    if (!program.uniformLocations) {
      console.warn(`Etheral: shader "${label}" kon niet gecompileerd worden en wordt overgeslagen.`);
      return null;
    }
    return new Mesh(gl, { geometry, program });
  }

  const compositeMesh = makeMesh(`${common}\n${compositeMain}`, compositeUniforms, 'composite');
  const postMesh = makeMesh(postFragment, postUniforms, 'post');
  if (!compositeMesh || !postMesh) return null;

  // ---------- visioenen: één voor één compileren ----------
  // Alles tegelijk compileren laat de pagina haperen (en kan op Windows de
  // videokaart-driver laten vastlopen). Daarom: het eerste meteen, de rest om de beurt.
  const sceneMeshes = new Array(SCENE_COUNT).fill(null);
  const failed = new Array(SCENE_COUNT).fill(false);
  let focus = 0; // rond dit visioen wordt het eerst gecompileerd

  function compileScene(index) {
    const [name, fn] = ORDER[index];
    const chunk = chunks[name];
    if (!chunk) {
      console.warn(`Etheral: geen blok "${name}" gevonden in scenes.glsl.`);
      failed[index] = true;
      return;
    }
    const fragment = `${common}\n${chunk}\n${sceneMain.replace('__SCENE__', fn)}`;
    const mesh = makeMesh(fragment, { ...shared, ...draw }, name);
    if (mesh) sceneMeshes[index] = mesh;
    else failed[index] = true;
    // Handig bij het debuggen: in DevTools zie je op het canvas hoeveel visioenen klaar zijn.
    canvas.dataset.ready = String(sceneMeshes.filter(Boolean).length);
    canvas.dataset.failed = String(failed.filter(Boolean).length);
  }

  function compileNext() {
    if (lost) return;
    let best = -1;
    for (let i = 0; i < SCENE_COUNT; i++) {
      if (sceneMeshes[i] || failed[i]) continue;
      if (best < 0 || Math.abs(i - focus) < Math.abs(best - focus)) best = i;
    }
    if (best < 0) {
      // alle visioenen zijn klaar: nu alvast de kruiper en de engelen, zodat er geen
      // hapering is op het moment dat ze voor het eerst verschijnen
      if (crawlerMesh === undefined) {
        crawlerMesh = makeMesh(`${common}\n${crawlerMain}`, crawlUniforms, 'kruiper');
      } else {
        const todo = angelMeshes.indexOf(undefined);
        if (todo < 0) return; // echt alles klaar
        angelMeshes[todo] = makeMesh(`${common}\n${angelCommon}\n${angelSources[todo]}`, angelUniforms, 'engel');
      }
      setTimeout(compileNext, 60);
      return;
    }
    compileScene(best);
    setTimeout(compileNext, 60);
  }

  compileScene(0);
  setTimeout(compileNext, 60);

  // Overlays worden pas gemaakt als ze voor het eerst nodig zijn.
  let glyphMesh;
  let ribbonMesh;

  // De kruiper: de logica zit in crawler.js, hier alleen het tekenen.
  const crawler = createCrawler();
  const crawlUniforms = {
    ...shared,
    uCrawl: { value: [0, 0, 1, 1] },
    uCrawlPose: { value: [0, 0, 1] },
    uCrawlLook: { value: [0, 0] },
  };
  let crawlerMesh;

  /** Het dichtstbijzijnde visioen dat al klaar is (of -1). */
  function nearestReady(index) {
    for (let d = 0; d < SCENE_COUNT; d++) {
      if (sceneMeshes[index - d]) return index - d;
      if (sceneMeshes[index + d]) return index + d;
    }
    return -1;
  }

  // ---------- buffers ----------
  let sceneTarget = null;
  let behindTarget = null; // het visioen dat je in de scheuren van een klap ziet
  let feedback = [];
  function disposeTarget(target) {
    if (!target) return;
    gl.deleteFramebuffer(target.buffer);
    if (target.texture && target.texture.texture) gl.deleteTexture(target.texture.texture);
  }
  function makeTargets() {
    [sceneTarget, behindTarget, ...feedback].forEach(disposeTarget);
    const options = { width: gl.canvas.width, height: gl.canvas.height, depth: false };
    sceneTarget = new RenderTarget(gl, options);
    behindTarget = new RenderTarget(gl, options);
    feedback = [new RenderTarget(gl, options), new RenderTarget(gl, options)];
  }

  let lastWidth = -1;
  let lastHeight = -1;
  const touchScreen = window.matchMedia('(pointer: coarse)').matches;
  function resize() {
    // Op een telefoon verandert de hoogte steeds een beetje doordat de adresbalk in- en
    // uitschuift. Dan alle buffers opnieuw maken geeft haperingen (en wist de echo),
    // dus daar slaan we kleine hoogteverschillen bij gelijke breedte over. Op een
    // computer niet: daar zou het beeld anders uitgerekt blijven na het verkleinen.
    const width = window.innerWidth;
    const height = window.innerHeight;
    if (width === lastWidth && height === lastHeight) return;
    if (touchScreen && width === lastWidth && Math.abs(height - lastHeight) < 160) return;
    lastWidth = width;
    lastHeight = height;
    renderer.setSize(width, height);
    shared.uRes.value = [gl.canvas.width, gl.canvas.height];
    makeTargets();
  }
  window.addEventListener('resize', resize);
  resize();

  // De muis verschuift het beeld licht; de waarde loopt vertraagd achter de cursor aan.
  const target = [0, 0];
  const mouse = [0, 0];
  if (!reduce) {
    window.addEventListener('pointermove', (event) => {
      target[0] = (event.clientX / window.innerWidth) * 2 - 1;
      target[1] = -((event.clientY / window.innerHeight) * 2 - 1);
    });
  }

  // ---------- tekenstappen ----------
  function setBlend(program, mode) {
    if (mode === 'alpha') program.setBlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    else if (mode === 'add') program.setBlendFunc(gl.ONE, gl.ONE);
    else program.blendFunc = {};
    program.transparent = mode !== 'none';
  }

  function drawScene(index, options) {
    const mesh = sceneMeshes[index];
    if (!mesh) return;
    draw.uRect.value = options.rect;
    draw.uCell.value = options.cell || 0;
    draw.uSeed.value = options.seed || 0;
    draw.uMirrorMode.value = options.mirror || 0;
    draw.uRotQ.value = options.rot || 0;
    draw.uHue.value = options.hue || 0;
    draw.uWarpK.value = options.warpK || 0;
    draw.uDissolve.value = options.dissolve || 0;
    draw.uGain.value = options.gain === undefined ? 1 : options.gain;
    setBlend(mesh.program, options.blend || 'none');
    renderer.render({ scene: mesh, target: options.target || sceneTarget, clear: !!options.clear });
  }

  // ---------- mozaïek en overlays: per "cut" opnieuw gekozen ----------
  let lastCut = -1;
  let mosaicClock = 0;   // loopt sneller of trager, afhankelijk van het tempo
  let mosaicTempo = 1.4;
  let mosaicTarget = 1.4;
  let tempoUntil = 0;    // tot wanneer het huidige tempo geldt

  // toestand van de duik
  // Om te testen kun je de eerste duik en de engel vastzetten in de adresbalk,
  // bijvoorbeeld ?dive=5&angel=1 (duik na 5 seconden, engel 0 = wielen, 1 = vleugels).
  const params = new URLSearchParams(window.location.search);
  const forcedAngel = params.has('angel') ? Number(params.get('angel')) % 2 : -1;
  const forcedDive = Number(params.get('dive'));
  let diveStart = params.has('dive') && Number.isFinite(forcedDive)
    ? forcedDive
    : DIVE_FIRST[0] + Math.random() * (DIVE_FIRST[1] - DIVE_FIRST[0]);
  let diveEndsAt = -100; // einde van de lopende of laatste duik
  let wasDiving = false;
  let landSpeed = 0;
  let landLevel = 0;
  canvas.dataset.nextDive = diveStart.toFixed(1); // handig bij het testen: seconde waarop de duik begint

  // de engel aan het eind van de duik
  const angelUniforms = { ...shared, uAngel: { value: [0, 0, 0] } };
  const angelSources = [angelWheels, angelWings];
  const angelMeshes = [undefined, undefined];
  let angelKind = 0;
  let angelSeed = 0;
  let diveZ = 0;
  let diveLevel = 0;
  let diveSpeed = 0;
  let landedAt = -100;   // moment waarop de laatste duik eindigde
  let layout = { mirror: 0, cells: [] };
  function makeLayout(cut, chaos) {
    const rnd = randomFrom(cut + 1);
    let pick = rnd();
    let grid = GRIDS[GRIDS.length - 1];
    for (const option of GRIDS) {
      if (pick < option[2]) {
        grid = option;
        break;
      }
      pick -= option[2];
    }
    const [cols, rows] = grid;
    const chance = (cols * rows < 3.5 ? 0.5 : 0.38) * chaos;
    const cells = [];
    if (cols * rows > 1) {
      for (let y = 0; y < rows; y++) {
        for (let x = 0; x < cols; x++) {
          const r = rnd();
          const cell = {
            x, y, cols, rows,
            scene: Math.floor(rnd() * SCENE_COUNT),
            seed: r * 50,
            hue: r * 40,
            mirror: rnd() > 0.5 ? 1 : 0,
            rot: Math.floor(rnd() * 4) * (Math.PI / 2),
          };
          if (r < chance) cells.push(cell);
        }
      }
    }
    const m = rnd();
    return { mirror: m < 0.3 * chaos ? 1 : m < 0.5 * chaos ? 2 : 0, cells };
  }

  // ---------- klappen (klik/tik) en opladen (vasthouden) ----------
  const SHOCK_LIFE = 1.3; // seconden dat een klap zichtbaar is
  const shockSlots = [postUniforms.uShock0, postUniforms.uShock1, postUniforms.uShock2, postUniforms.uShock3];
  let shocks = []; // { x, y, start, power }
  const HIT_STOP = 0.09; // seconden dat het beeld bevriest bij een klap
  let freezeUntil = 0;
  let timeLag = 0;       // hoeveel de visioenen achterlopen door die bevriezingen
  let lastTime = 0;
  let layoutBump = 0;    // elke klap gooit de indeling van het mozaïek om
  let behindScene = 0;
  const seconds = () => performance.now() / 1000;

  /** Schermpositie in pixels -> de ruimte waarin de shader rekent (midden = 0,0). */
  function toShaderSpace(clientX, clientY) {
    const w = window.innerWidth;
    const h = window.innerHeight;
    return [(clientX / w - 0.5) * (w / h), 0.5 - clientY / h];
  }

  let lastOverlayTick = -1;
  let overlay = 'none';
  function pickOverlay(tick, chaos) {
    const r = randomFrom(tick + 77)();
    if (r < 0.25 * chaos) return 'net';
    if (r < 0.5 * chaos) return 'glyphs';
    if (r < 0.75 * chaos) return 'ribbons';
    return 'none';
  }

  return {
    /**
     * @param {number} time   seconden sinds de start
     * @param {number} scene  0 .. SCENE_COUNT - 1
     * @param {number} chaos  0 = rustig, hoger = meer cuts, echo en glitch
     * @param {number} velocity  0..1: hoe hard er gescrold wordt
     */
    render(time, scene, chaos, velocity = 0) {
      if (lost || document.hidden || !sceneTarget) return;

      // Hit-stop: tijdens de aanloop van een klap staat de tijd van de visioenen stil.
      const frame = Math.min(Math.max(time - lastTime, 0), 0.1);
      lastTime = time;

      // het beeld loopt vertraagd achter de cursor aan, even snel bij 60 en 144 Hz
      const follow = 1 - Math.exp(-frame * 3);
      mouse[0] += (target[0] - mouse[0]) * follow;
      mouse[1] += (target[1] - mouse[1]) * follow;
      shared.uMouse.value = [mouse[0], mouse[1]];
      if (seconds() < freezeUntil) timeLag += frame;

      // Bij "minder beweging" staat de tijd stil en is er geen chaos.
      const now = reduce ? 12 : time - timeLag;
      // De duik: op een wisselend moment word je acht seconden een eindeloze tunnel in
      // gezogen. Dat gaat in drie trappen (snel, supersnel, supersonisch), die vloeiend
      // in elkaar overlopen. Aan het eind wacht een engel.
      const diveT = reduce ? -1 : (now - diveStart) / DIVE_TIME; // 0..1 tijdens de duik
      const diving = diveT >= 0 && diveT < 1;
      let gate = 0;
      let bounce = 0;
      let flash = 0;
      if (diving) {
        if (!wasDiving) {
          wasDiving = true;
          diveZ = 0;
          diveEndsAt = diveStart + DIVE_TIME;
          // welke engel er komt, is elke keer een gok
          angelKind = forcedAngel >= 0 ? forcedAngel : Math.random() < 0.5 ? 0 : 1;
          angelSeed = Math.random() * 10;
        }
        // Hevigheid en snelheid lopen van trap naar trap via een vloeiende curve in
        // plaats van een sprong. "shift" is een zachte bult midden in elke overgang:
        // daar voel je het opschakelen.
        let level = DIVE_STAGES[0].level;
        let speed = DIVE_STAGES[0].speed;
        let shift = 0;
        for (let i = 1; i < DIVE_STAGES.length; i++) {
          const at = DIVE_STAGES[i].from;
          const k = smooth(at - DIVE_BLEND / 2, at + DIVE_BLEND / 2, diveT);
          level += (DIVE_STAGES[i].level - DIVE_STAGES[i - 1].level) * k;
          speed += (DIVE_STAGES[i].speed - DIVE_STAGES[i - 1].speed) * k;
          shift += 4 * k * (1 - k);
        }
        const ease = smooth(0, 0.14, diveT); // rustig op gang komen
        diveLevel = level * ease;
        diveSpeed = speed * (1 + 0.3 * diveT) * ease;
        diveZ += diveSpeed * frame;
        gate = smooth(0, 1.2, diveT * DIVE_TIME); // de tunnel komt er in ruim een seconde in
        bounce = 0.2 * shift;
        flash = 0.35 * shift;
      } else {
        if (wasDiving) {
          wasDiving = false; // de duik is voorbij: afremmen
          landedAt = now;
          landSpeed = diveSpeed;
          landLevel = diveLevel;
          // de volgende duik komt 60 tot 90 seconden na het begin van deze
          diveStart += DIVE_GAP[0] + Math.random() * (DIVE_GAP[1] - DIVE_GAP[0]);
          canvas.dataset.nextDive = diveStart.toFixed(1);
        }
        // Was het tabblad op de achtergrond tijdens de hele duik, dan is hij gemist.
        // Zonder dit zou er daarna nooit meer een duik komen.
        while (!reduce && now >= diveStart + DIVE_TIME) {
          diveStart += DIVE_GAP[0] + Math.random() * (DIVE_GAP[1] - DIVE_GAP[0]);
          canvas.dataset.nextDive = diveStart.toFixed(1);
        }
        const since = now - landedAt;
        if (!reduce && since < LANDING_TIME + 3) {
          // Afremmen: de snelheid loopt uit in plaats van te stoppen, de tunnel lost
          // geleidelijk op, en het beeld veert één keer ruim door en komt dan tot rust.
          diveSpeed = landSpeed * Math.exp(-since * 2.4);
          diveZ += diveSpeed * frame;
          diveLevel = landLevel * (1 - smooth(0, 1.6, since));
          gate = since < LANDING_TIME ? 1 - smooth(0.15, LANDING_TIME - 0.6, since) : 0;
          // de vering begint op nul (sinus), dus zonder schok
          bounce = 0.9 * Math.exp(-since * 2) * Math.sin(since * 5.2);
          flash = 0.6 * smooth(0, 0.2, since) * Math.exp(-since * 3.5);
        } else {
          diveLevel = 0;
          diveSpeed = 0;
        }
      }
      const dive = diveLevel;

      // de engel: groeit uit het punt waar je naartoe werd gezogen, blijft even hangen,
      // en lost dan op terwijl hij verder op je af komt
      const angelT = now - (diveEndsAt - ANGEL_LEAD);
      const angelLife = ANGEL_LEAD + ANGEL_STAY;
      const angelOn = !reduce && angelT >= 0 && angelT < angelLife;
      if (angelOn) {
        const fade = smooth(angelLife - 1.5, angelLife, angelT);
        const grow = smooth(0, ANGEL_LEAD + 0.8, angelT) * (1 + 0.5 * fade);
        angelUniforms.uAngel.value = [grow, smooth(0, 1, angelT) * (1 - fade), angelSeed];
      }
      // een klap geeft ook even extra chaos (meer glitch en echo), die snel wegzakt
      const energy = shocks.reduce((sum, shock) => sum + shock.power * Math.exp(-(seconds() - shock.start) * 2.2), 0);
      // tijdens de duik juist minder chaos: dan blijft zichtbaar waar je in duikt
      const ch = reduce ? 0 : (chaos + 0.35 * Math.min(energy, 1.5)) * (1 - 0.6 * gate);
      shared.uTime.value = now;
      shared.uChaos.value = ch;
      shared.uVoid.value = dive;
      shared.uBounce.value = bounce;
      shared.uCalm.value = gate;
      shared.uDiveZ.value = diveZ;
      shared.uDiveGate.value = gate;
      shared.uFlash.value = flash;

      const width = gl.canvas.width;
      const height = gl.canvas.height;
      const full = [0, 0, width, height];

      const s = Math.min(Math.max(scene, 0), SCENE_COUNT - 1);
      const base = Math.floor(s);
      const k = smooth(0.3, 0.7, s - base); // voortgang van de overgang
      focus = Math.round(s);

      // Snelheid: het hoogst halverwege een overgang (meer als je hard scrolt) en
      // tegen het einde van een duik.
      const travel = Math.sin(k * Math.PI) * (0.6 + 0.8 * velocity);
      shared.uSpeed.value = reduce ? 0 : Math.min(1.5, Math.max(travel, dive * 1.5 * gate));

      // Het tempo van het mozaïek wisselt elke paar seconden tussen traag en razend.
      if (now >= tempoUntil) {
        mosaicTarget = MOSAIC_TEMPOS[Math.floor(Math.random() * MOSAIC_TEMPOS.length)];
        tempoUntil = now + 2 + Math.random() * 5;
      }
      mosaicTempo += (mosaicTarget - mosaicTempo) * Math.min(1, frame * 2);
      mosaicClock += mosaicTempo * frame;
      const cut = Math.floor(mosaicClock) + layoutBump * 1000;
      if (cut !== lastCut) {
        lastCut = cut;
        layout = makeLayout(cut, ch);
      }
      const hueTime = reduce ? 0 : now * 0.5;
      const hueOf = (index) => index * 2.399 + hueTime;

      // 1. het visioen van de scrollpositie, en het volgende eroverheen
      const current = nearestReady(base);
      if (current < 0) return; // nog niets gecompileerd
      drawScene(current, { rect: full, mirror: layout.mirror, hue: hueOf(current), warpK: k, clear: true });
      if (k > 0.001 && base + 1 < SCENE_COUNT) {
        const next = nearestReady(base + 1);
        if (next !== current) {
          drawScene(next, {
            rect: full, mirror: layout.mirror, hue: hueOf(next), warpK: k, dissolve: 1, blend: 'alpha',
          });
        }
      }

      // 2. mozaïekvakken, elk beperkt tot zijn eigen rechthoek
      if (gate < 0.05 && layout.cells.length) { // tijdens een duik geen vakken: dan leest de vaart beter
        gl.enable(gl.SCISSOR_TEST);
        for (const cell of layout.cells) {
          const index = nearestReady(cell.scene);
          const x0 = Math.round((cell.x * width) / cell.cols);
          const x1 = Math.round(((cell.x + 1) * width) / cell.cols);
          const y0 = Math.round((cell.y * height) / cell.rows);
          const y1 = Math.round(((cell.y + 1) * height) / cell.rows);
          gl.scissor(x0, y0, x1 - x0, y1 - y0);
          drawScene(index, {
            rect: [x0, y0, x1 - x0, y1 - y0], cell: 1, seed: cell.seed, mirror: cell.mirror,
            rot: cell.rot, hue: hueOf(index) + cell.hue,
          });
        }
        gl.disable(gl.SCISSOR_TEST);
      }

      // 3. overlay
      const tick = Math.floor(now * 0.9);
      if (tick !== lastOverlayTick) {
        lastOverlayTick = tick;
        overlay = pickOverlay(tick, ch);
      }
      if (ch > 0.01 && overlay === 'net') {
        drawScene(NET_INDEX, { rect: full, seed: 30, hue: hueTime + 2, gain: 0.55, blend: 'add' });
      } else if (ch > 0.01 && overlay === 'glyphs') {
        if (glyphMesh === undefined) glyphMesh = makeMesh(`${common}\n${glyphsMain}`, { ...shared }, 'tekens');
        if (glyphMesh) {
          setBlend(glyphMesh.program, 'add');
          renderer.render({ scene: glyphMesh, target: sceneTarget, clear: false });
        }
      } else if (ch > 0.01 && overlay === 'ribbons') {
        if (ribbonMesh === undefined) ribbonMesh = makeMesh(`${common}\n${ribbonsMain}`, { ...shared }, 'linten');
        if (ribbonMesh) {
          setBlend(ribbonMesh.program, 'alpha');
          renderer.render({ scene: ribbonMesh, target: sceneTarget, clear: false });
        }
      }

      // klappen: leeftijd bijwerken, uitgedoofde klappen weggooien
      const clock = seconds();
      shocks = shocks.filter((shock) => clock - shock.start < SHOCK_LIFE);
      shockSlots.forEach((slot, i) => {
        const shock = shocks[i];
        slot.value = shock ? [shock.x, shock.y, clock - shock.start, shock.power] : [0, 0, 0, 0];
      });
      // het visioen achter de scheuren wordt alleen getekend zolang er een klap loopt
      if (shocks.length) {
        const behind = nearestReady(behindScene);
        drawScene(behind, { rect: full, hue: hueOf(behind) + 3, target: behindTarget, clear: true });
      }
      postUniforms.uBehind.value = behindTarget.texture;

      // 4. samenvoegen met de echo van het vorige frame ("ping-pong" tussen twee buffers)
      const [read, write] = feedback;
      compositeUniforms.uSceneTex.value = sceneTarget.texture;
      compositeUniforms.uPrev.value = read.texture;
      renderer.render({ scene: compositeMesh, target: write });

      // de kruiper komt óver de echo heen, anders vult de echo zijn zwarte lijf op
      const crawl = reduce ? null : crawler.update(now, frame, width / height);
      if (crawl) {
        if (crawlerMesh === undefined) crawlerMesh = makeMesh(`${common}\n${crawlerMain}`, crawlUniforms, 'kruiper');
        if (crawlerMesh) {
          // zijn ogen volgen de cursor of vinger
          const lookX = (target[0] * width) / height / 2 - crawl.x;
          const lookY = target[1] / 2 - crawl.y;
          const lookLength = Math.hypot(lookX, lookY) || 1;
          crawlUniforms.uCrawl.value = [crawl.x, crawl.y, crawl.scale, crawl.dir];
          crawlUniforms.uCrawlPose.value = [crawl.phase, crawl.head, crawl.flip];
          crawlUniforms.uCrawlLook.value = [(lookX / lookLength) * crawl.dir, (lookY / lookLength) * crawl.flip];
          setBlend(crawlerMesh.program, 'alpha');
          renderer.render({ scene: crawlerMesh, target: write, clear: false });
        }
      }

      if (angelOn) {
        if (angelMeshes[angelKind] === undefined) {
          angelMeshes[angelKind] = makeMesh(
            `${common}\n${angelCommon}\n${angelSources[angelKind]}`, angelUniforms, 'engel');
        }
        const angel = angelMeshes[angelKind];
        if (angel) {
          setBlend(angel.program, 'alpha');
          renderer.render({ scene: angel, target: write, clear: false });
        }
      }

      // 5. glitch-nabewerking naar het scherm
      postUniforms.uTex.value = write.texture;
      renderer.render({ scene: postMesh });

      feedback.reverse();
    },

    /**
     * Een klap op een plek op het scherm (klik of tik).
     * @param {number} clientX  pixels vanaf links
     * @param {number} clientY  pixels vanaf boven
     * @param {number} power    1 = gewone klik, tot ~2,5 na volledig opladen
     */
    shock(clientX, clientY, power = 1) {
      if (reduce || lost) return;
      const [x, y] = toShaderSpace(clientX, clientY);
      shocks.push({ x, y, start: seconds(), power });
      freezeUntil = seconds() + HIT_STOP;
      layoutBump += 1;
      crawler.startle(x, y);
      if (shocks.length > shockSlots.length) shocks.shift(); // maximaal vier tegelijk
      // kies een ander visioen om in de scheuren te laten zien
      behindScene = (focus + 1 + Math.floor(Math.random() * (SCENE_COUNT - 1))) % SCENE_COUNT;
    },

    /**
     * Opladen terwijl de muisknop of vinger wordt vastgehouden.
     * @param {number} amount  0 = uit, 1 = volledig opgeladen
     */
    charge(clientX, clientY, amount) {
      if (reduce || lost) return;
      const [x, y] = toShaderSpace(clientX, clientY);
      postUniforms.uCharge.value = [x, y, amount];
    },
  };
}
