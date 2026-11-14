# Ethereal

Een website zonder tekst, knoppen of menu's: alleen scrollen. Terwijl je scrolt reis je
door 21 abstracte, psychedelische visioenen die live door je videokaart worden getekend.
Ze knippen door elkaar, laten regenboogsporen achter en vallen uiteen in glitches. Hoe
harder je scrolt, hoe meer chaos.

**Bekijk het live:** [ethereal.ridouanrashid.com](https://ethereal.ridouanrashid.com)

> **Waarschuwing:** deze site bevat snelle beeldwisselingen, flitsende vlakken, felle
> kleuren en sterke zoombewegingen. Dat kan klachten geven bij fotosensitieve epilepsie,
> migraine of gevoeligheid voor prikkels en beweging. Heb je in je besturingssysteem
> "minder beweging" aanstaan, dan krijg je automatisch een stilstaande, rustige versie.

## Wat je ziet

- **21 visioenen**, van een caleidoscopisch juweel en een chromen lotus tot een veld vol
  knipperende ogen, een DNA-helix, een vliegende schotel en een gespiegelde tempel.
- **Reizen in plaats van bladeren.** Bij elke overgang schiet het oude visioen op je af en
  opent het nieuwe zich vanuit het midden.
- **De duik.** Elke 11 seconden word je een eindeloze tunnel van het huidige visioen in
  gezogen, terwijl het beeld schudt, uitrekt en in scherven uit elkaar wordt getrokken.
- **Lagen van chaos.** Split-screens die naar andere visioenen springen, spiegelingen,
  regenbooglinten, een regen van verzonnen schrifttekens en resten van software-schermen.
- **Kleur door het hele spectrum.** Elk visioen draait door het volledige kleurenwiel.

Alles is procedureel: er zit geen enkele afbeelding of video in. Elk beeld is wiskunde in
een shader.

## Zelf draaien

Je hebt [Node.js](https://nodejs.org) 18 of hoger nodig.

```bash
git clone https://github.com/RidouanRashid/ethereal.git
cd ethereal
npm install
npm run dev
```

Open daarna `http://localhost:5173`.

Voor een versie die je op een server kunt zetten:

```bash
npm run build
```

De uitvoer staat dan in `dist/`. Die map kun je op elke statische host plaatsen. Draai je
het project in een Apache-map (bijvoorbeeld XAMPP), dan stuurt de meegeleverde
`.htaccess` bezoekers vanzelf door naar `dist/`.
git
## Hoe het werkt

- **Scroll stuurt alles.** De pagina is lege scrollruimte. De scrollpositie wordt één
  getal van 0 tot 20: het hele deel kiest het visioen, de rest stuurt de overgang.
- **Elk visioen is een eigen kleine shader.** Ze worden één voor één gecompileerd, het
  dichtst bij je scrollpositie eerst, zodat de pagina snel start en ook op eenvoudige
  videokaarten werkt.
- **Vijf tekenstappen per frame:** het visioen van je scrollpositie, mozaïekvakken met
  andere visioenen, een overlay, samenvoegen met de echo van het vorige frame, en als
  laatste de glitch-nabewerking.
- **Eén chaoswaarde.** Alle effecten luisteren naar één getal dat oploopt met je
  scrollsnelheid.

## Gebouwd met

| Onderdeel | Waarvoor |
|-----------|----------|
| [Vite](https://vite.dev) | Dev-server en bundler |
| [OGL](https://github.com/oframe/ogl) | Lichte WebGL-library voor de shaders en buffers |
| [GSAP + ScrollTrigger](https://gsap.com) | Scroll koppelen aan de animatie |
| [Lenis](https://lenis.darkroom.engineering) | Soepel scrollen |
| GLSL | Alle visioenen en effecten |

De hele site is ongeveer 80 kB (gzip).

## Mapstructuur

```
ethereal/
├── index.html            Canvas en scrollruimte
├── src/
│   ├── main.js           Scroll, scrollsnelheid en de render-lus
│   ├── style.css
│   └── gl/               Hier zit bijna alle code
│       ├── stage.js           Renderer, volgorde van visioenen, mozaïek, tekenstappen
│       ├── scenes.glsl        De 21 visioenen
│       ├── scene-main.glsl    Overgangen, de duik en kleur
│       ├── common.glsl        Gedeelde functies (ruis, palet, chroom, oog)
│       ├── composite.glsl     Echo en snelheidsstrepen
│       ├── post.glsl          Glitch-nabewerking
│       └── overlay-*.glsl     Tekenregen en regenbooglinten
├── vite.config.js
└── .htaccess             Doorsturen naar dist/ op Apache
```

## Een eigen visioen toevoegen

1. Schrijf in `src/gl/scenes.glsl` een blok met de kop `// ---------- Naam ----------` en
   een functie `vec3 sceneNaam(vec2 p, float t)` die een kleur teruggeeft.
2. Zet `['Naam', 'sceneNaam']` op de gewenste plek in de lijst `ORDER` in
   `src/gl/stage.js`.

De scrollhoogte, het mozaïek en de overgangen passen zich vanzelf aan.

## Browsers

Werkt in recente versies van Chrome, Edge, Firefox en Safari met WebGL. Zonder WebGL
verschijnt er een melding in plaats van de animaties.

## Inspiratie

De sfeer is geïnspireerd op de videomontages van
[@meme3_ctrl8](https://www.tiktok.com/@meme3_ctrl8) op TikTok. Er is geen materiaal uit
die video's gebruikt; alle beelden zijn opnieuw in code geschreven.

## Maker

Gemaakt door [Ridouan Rashid](https://ridouanrashid.com).
