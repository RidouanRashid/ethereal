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
