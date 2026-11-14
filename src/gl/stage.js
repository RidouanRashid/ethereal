import { Renderer, Program, Mesh, Triangle, RenderTarget } from 'ogl';
import common from './common.glsl?raw';
import scenesSource from './scenes.glsl?raw';
import sceneMain from './scene-main.glsl?raw';
import glyphsMain from './overlay-glyphs.glsl?raw';
import ribbonsMain from './overlay-ribbons.glsl?raw';
import compositeMain from './composite.glsl?raw';
import postFragment from './post.glsl?raw';

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

// De duik: om de hoeveel seconden, en welk deel daarvan de duik duurt.
const DIVE_EVERY = 11;
const DIVE_PART = 0.14;

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
    uSpeed: { value: 0 },
    uFlash: { value: 0 },
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
  const postUniforms = { ...shared, uTex: { value: null } };

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
    if (best < 0) return; // alles klaar
    compileScene(best);
    setTimeout(compileNext, 60);
  }

  compileScene(0);
  setTimeout(compileNext, 60);

  // Overlays worden pas gemaakt als ze voor het eerst nodig zijn.
  let glyphMesh;
  let ribbonMesh;

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
  let feedback = [];
  function disposeTarget(target) {
    if (!target) return;
    gl.deleteFramebuffer(target.buffer);
    if (target.texture && target.texture.texture) gl.deleteTexture(target.texture.texture);
  }
  function makeTargets() {
    [sceneTarget, ...feedback].forEach(disposeTarget);
    const options = { width: gl.canvas.width, height: gl.canvas.height, depth: false };
    sceneTarget = new RenderTarget(gl, options);
    feedback = [new RenderTarget(gl, options), new RenderTarget(gl, options)];
  }

  function resize() {
    renderer.setSize(window.innerWidth, window.innerHeight);
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
    renderer.render({ scene: mesh, target: sceneTarget, clear: !!options.clear });
  }

  // ---------- mozaïek en overlays: per "cut" opnieuw gekozen ----------
  let lastCut = -1;
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
      if (lost || document.hidden) return;

      mouse[0] += (target[0] - mouse[0]) * 0.05;
      mouse[1] += (target[1] - mouse[1]) * 0.05;
      shared.uMouse.value = [mouse[0], mouse[1]];

      // Bij "minder beweging" staat de tijd stil en is er geen chaos.
      const now = reduce ? 12 : time;
      // De duik: elke 11 seconden schiet je ruim anderhalve seconde lang met oplopende
      // snelheid het visioen in. dive loopt van 0 naar 1; daarna volgt de aankomst.
      const phase = (now / DIVE_EVERY) % 1;
      const dive = reduce ? 0 : Math.max(0, (phase - (1 - DIVE_PART)) / DIVE_PART);
      const flash = reduce || now < DIVE_EVERY ? 0 : Math.exp(-phase * DIVE_EVERY * 5);
      const ch = reduce ? 0 : chaos;
      shared.uTime.value = now;
      shared.uChaos.value = ch;
      shared.uVoid.value = dive;
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
      shared.uSpeed.value = reduce ? 0 : Math.min(1.5, Math.max(travel, dive * dive * 1.3));

      const cut = Math.floor(now * 1.4);
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
      if (dive < 0.05 && layout.cells.length) { // tijdens een duik geen vakken: dan leest de vaart beter
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

      // 4. samenvoegen met de echo van het vorige frame ("ping-pong" tussen twee buffers)
      const [read, write] = feedback;
      compositeUniforms.uSceneTex.value = sceneTarget.texture;
      compositeUniforms.uPrev.value = read.texture;
      renderer.render({ scene: compositeMesh, target: write });

      // 5. glitch-nabewerking naar het scherm
      postUniforms.uTex.value = write.texture;
      renderer.render({ scene: postMesh });

      feedback.reverse();
    },
  };
}
