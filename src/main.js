import 'lenis/dist/lenis.css';
import './style.css';
import Lenis from 'lenis';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { createStage, SCENE_COUNT } from './gl/stage.js';

gsap.registerPlugin(ScrollTrigger);

// Scrollafstand per visioen, in schermhoogtes.
const SCREENS_PER_SCENE = 1.5;

const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const scroll = document.getElementById('scroll');
const progress = document.getElementById('progress');

// De pagina is alleen scrollruimte: (aantal overgangen × afstand) + één scherm.
scroll.style.height = `${(SCENE_COUNT - 1) * SCREENS_PER_SCENE * 100 + 100}vh`;

// state.scene loopt van 0 tot SCENE_COUNT - 1 en is het enige dat de shader van de scroll weet.
const state = { scene: 0 };

const stage = createStage(document.getElementById('stage'), { reduce });
if (!stage) document.documentElement.classList.add('no-webgl');

// ---------- soepel scrollen ----------
if (!reduce) {
  const lenis = new Lenis({ lerp: 0.1 });
  lenis.on('scroll', ScrollTrigger.update);
  gsap.ticker.add((time) => lenis.raf(time * 1000));
  gsap.ticker.lagSmoothing(0);
}

// ---------- scroll -> scène ----------
gsap.to(state, {
  scene: SCENE_COUNT - 1,
  ease: 'none',
  scrollTrigger: {
    trigger: scroll,
    start: 'top top',
    end: 'bottom bottom',
    scrub: reduce ? true : 0.5,
  },
});

// Basisniveau van de chaos, en hoeveel erbij komt als je hard scrolt.
const CHAOS_BASE = 0.75;
const CHAOS_SCROLL = 0.75;

let lastScene = 0;
let lastTime = 0;
let velocity = 0;

// Eén gedeelde render-lus voor GSAP, Lenis en WebGL.
gsap.ticker.add((time) => {
  // Scrollsnelheid in visioenen per seconde, gedempt zodat de chaos niet schokt.
  const dt = Math.max(time - lastTime, 1 / 240);
  const raw = Math.min((Math.abs(state.scene - lastScene) / dt) * 1.2, 1);
  velocity += (raw - velocity) * 0.1;
  lastScene = state.scene;
  lastTime = time;

  progress.style.transform = `scaleY(${state.scene / (SCENE_COUNT - 1)})`;
  if (stage) stage.render(time, state.scene, CHAOS_BASE + velocity * CHAOS_SCROLL, velocity);
});

// ---------- klikken, tikken en vasthouden ----------
// Kort klikken/tikken = een klap. Vasthouden = opladen; bij loslaten een grotere klap.
// Op een telefoon blijft scrollen gewoon werken: zodra je vinger beweegt neemt de browser
// het over (pointercancel) en vervalt de lading zonder klap.
if (stage && !reduce) {
  const HOLD_DELAY = 0.08; // seconden voordat vasthouden als opladen telt
  const CHARGE_TIME = 0.6; // seconden tot volledig opgeladen
  const CHARGE_POWER = 1.5; // extra kracht bij volledig opladen
  let press = null;

  const now = () => performance.now() / 1000;
  // De lading schiet snel omhoog en vlakt daarna af: het beeld wordt meteen hard
  // naar je vinger getrokken in plaats van langzaam op te bouwen.
  const chargeOf = () => {
    if (!press) return 0;
    const x = Math.min(Math.max((now() - press.start - HOLD_DELAY) / CHARGE_TIME, 0), 1);
    return 1 - (1 - x) ** 3;
  };

  function release(blast) {
    if (!press) return;
    if (blast) {
      const charged = chargeOf();
      stage.shock(press.x, press.y, 1 + charged * CHARGE_POWER);
      // korte trilling op telefoons die dat ondersteunen (vooral Android)
      if (press.type !== 'mouse' && navigator.vibrate) {
        try {
          navigator.vibrate(charged > 0.5 ? [15, 30, 70] : 20);
        } catch (error) {
          /* trillen mag niet: geen probleem */
        }
      }
    }
    stage.charge(press.x, press.y, 0);
    press = null;
  }

  window.addEventListener('pointerdown', (event) => {
    if (!event.isPrimary || (event.pointerType === 'mouse' && event.button !== 0)) return;
    press = { id: event.pointerId, x: event.clientX, y: event.clientY, start: now(), type: event.pointerType };
  });
  window.addEventListener('pointermove', (event) => {
    if (!press || event.pointerId !== press.id) return;
    press.x = event.clientX;
    press.y = event.clientY;
  });
  window.addEventListener('pointerup', (event) => {
    if (press && event.pointerId === press.id) release(true);
  });
  window.addEventListener('pointercancel', (event) => {
    if (press && event.pointerId === press.id) release(false);
  });
  window.addEventListener('blur', () => release(false));
  // Lang drukken op een telefoon mag geen contextmenu openen; rechtsklikken met de muis wel.
  window.addEventListener('contextmenu', (event) => {
    if (press && press.type !== 'mouse') event.preventDefault();
  });

  gsap.ticker.add(() => {
    if (press) stage.charge(press.x, press.y, chargeOf());
  });
}
