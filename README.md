# Ethereal

Een website zonder tekst, knoppen of menu's: alleen scrollen en klikken. Terwijl je scrolt reis je
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
- **De duik.** Elke 60 tot 90 seconden, op een onverwacht moment, word je acht seconden
  lang een eindeloze tunnel van het huidige visioen in gezogen. De snelheid loopt vloeiend
  op in drie trappen: snel, supersnel, supersonisch. Daarna rem je af en veert het beeld
  terug.
- **De engel.** Aan het eind van elke duik wacht een engel uit het boek Ezechiël, en je
  weet nooit welke: wielen in wielen vol knipperende ogen, of een ring met ogen gedragen
  door zes vleugels. Hij groeit uit het punt waar je naartoe werd gezogen, kijkt je aan en
  lost weer op.
- **Lagen van chaos.** Split-screens die in wisselend tempo naar andere visioenen springen
  (van traag tot razend), spiegelingen,
  regenbooglinten, een regen van verzonnen schrifttekens en resten van software-schermen.
- **Sla erop.** Klik of tik ergens en er loopt een schokgolf vanaf dat punt door het
  beeld: het breekt in scherven, en in de scheuren zie je even een ander visioen. Houd
  ingedrukt om op te laden (het beeld wordt naar je vinger gezogen) en laat los voor een
  grotere klap. Werkt ook op een telefoon; scrollen blijft daar gewoon scrollen.
- **De kruiper.** Elke 30 seconden kruipt er een pikzwarte figuur op handen en knieën
  door het beeld, tien tot twaalf seconden lang. Alleen zijn ogen lichten op. Hij sluipt,
  staat stil, sprint, en draait zijn hoofd als een uil helemaal om. Zijn ogen volgen je
  cursor, en van een klap vlakbij schrikt hij.
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
- **Klappen in de nabewerking.** Een klik wordt een ring en een scherfpatroon in de
  laatste tekenstap, zodat hij over alles heen werkt. Tot vier klappen lopen tegelijk.
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
│   ├── main.js           Scroll, klikken/tikken en de render-lus
│   ├── crawler.js        Wanneer en hoe de kruiper beweegt
│   ├── style.css
│   └── gl/               Hier zit bijna alle code
│       ├── stage.js           Renderer, volgorde van visioenen, mozaïek, tekenstappen
│       ├── scenes.glsl        De 21 visioenen
│       ├── scene-main.glsl    Overgangen, de duik en kleur
│       ├── common.glsl        Gedeelde functies (ruis, palet, chroom, oog)
│       ├── composite.glsl     Echo en snelheidsstrepen
│       ├── post.glsl          Glitch-nabewerking
│       ├── overlay-*.glsl     Tekenregen, regenbooglinten, de kruiper en de engelen
│       └── angel-common.glsl  Gedeeld door de twee engelen
├── vite.config.js
└── .htaccess             Doorsturen naar dist/ op Apache
```

## Een eigen visioen toevoegen

1. Schrijf in `src/gl/scenes.glsl` een blok met de kop `// ---------- Naam ----------` en
   een functie `vec3 sceneNaam(vec2 p, float t)` die een kleur teruggeeft.
2. Zet `['Naam', 'sceneNaam']` op de gewenste plek in de lijst `ORDER` in
   `src/gl/stage.js`.

De scrollhoogte, het mozaïek en de overgangen passen zich vanzelf aan.

## Testen

De duik en de engel komen op wisselende momenten. Om ze direct te zien kun je ze
vastzetten in de adresbalk: `?dive=5` start de eerste duik na 5 seconden, en `&angel=0`
(wielen) of `&angel=1` (vleugels) kiest de engel. Bijvoorbeeld
`http://localhost:5173/?dive=5&angel=1`.

## Browsers

Werkt in recente versies van Chrome, Edge, Firefox en Safari met WebGL. Zonder WebGL
verschijnt er een melding in plaats van de animaties.

## Inspiratie

De sfeer is geïnspireerd op de videomontages van
[@meme3_ctrl8](https://www.tiktok.com/@meme3_ctrl8) op TikTok. Er is geen materiaal uit
die video's gebruikt; alle beelden zijn opnieuw in code geschreven.

## Maker

Gemaakt door [Ridouan Rashid](https://ridouanrashid.com).
