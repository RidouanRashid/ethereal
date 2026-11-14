# Prompt — Etheral

Dit is de opdracht waarmee de site is gebouwd. Je kunt hem hergebruiken of aanpassen
om een nieuwe versie te laten maken.

## Doel
Bouw een one-page website met de naam **Etheral** die een reeks abstracte,
psychedelische animaties toont. De bezoeker scrolt door zeven "visioenen"; elke
scène loopt vloeiend over in de volgende. De stijl is geïnspireerd op een TikTok-montage
van @meme3_ctrl8 (esoterische symbolen, juwelen, node-netwerken, organische wezens,
software-interfaces), maar alle beelden worden opnieuw en procedureel in code getekend.
Er worden geen beelden uit de video overgenomen.

## Scènes (in scrollvolgorde)
1. **Juweel** – caleidoscoop van edelsteenachtige ringen en facetten.
2. **Netwerk** – blauwe en gele blokjes (nodes) met verbindingslijnen die bewegen.
3. **Wolk** – een rood-witte wolk boven een kustlijn.
4. **Oog** – een rood gloeiend oog in een veld van verzonnen schrifttekens.
5. **Organisme** – een parelachtig wezen met armen en meerdere ogen.
6. **Zegels** – een raster van draaiende sigillen en mandala's.
7. **Tempel** – een gespiegelde fractal met een lichtstraal in het midden.

## Gedrag
- Eén vast canvas op de achtergrond; de scrollpositie bepaalt welke scène zichtbaar is.
- Tussen twee scènes: een "oplos"-overgang met ruis, lichte zoom en rotatie.
- Elke scène heeft een titel, één regel uitleg en een technische regel in monospace
  (wat de shader doet), als knipoog naar de software-look van de video.
- Een vaste balk toont de naam en het scènenummer; rechts een rail om naar een scène te springen.
- De muis verschuift het beeld heel licht (parallax).

## Techniek
- **Vite** als dev-server en bundler.
- **OGL** (kleine WebGL-library) met één fullscreen fragment-shader voor alle scènes.
- **GSAP + ScrollTrigger** om scroll aan de shader en de tekstanimaties te koppelen.
- **Lenis** voor soepel scrollen.
- Geen afbeeldingen of video's: alles wordt live op de GPU berekend.

## Eisen
- Vloeiend op een gemiddelde laptop: pixelratio maximaal 1,5, niet renderen als het tabblad verborgen is.
- Respecteer `prefers-reduced-motion`: geen smooth scroll, geen tekstanimaties, stilstaand beeld per scène.
- Werkt op mobiel (tekst stapelt, rail verdwijnt).
- Nette val-terug als WebGL niet beschikbaar is.
- Nederlandse teksten, code met korte uitleg in commentaar.
- Een README die uitlegt wat er gebouwd is, welke libraries waarom zijn gekozen en hoe je het start.

## Aanvulling (versie 2)
- Maak het abstracter: haal alle tekst en interface weg, zodat je alleen scrolt.
  Alleen een dunne voortgangslijn blijft staan.
- Voeg meer visioenen toe: Vloeistof, Moiré, Cellen, Tunnel en Spectrum (twaalf in totaal).
- Maak letterlijke beelden minder herkenbaar: de Wolk zonder kustlijn en gespiegeld,
  het Netwerk gebogen en vervormd, en laat het hele beeld langzaam "ademen".
- De punten hierboven over titels, uitleg, balk en rail vervallen daarmee.

## Aanvulling (versie 3)
- Zorg dat `http://localhost/etheral/` werkt in XAMPP.
- Bekijk de video opnieuw en maak eerst een plan. Daarna: meer abstractie, meer animatie,
  meer chaos en beweging, tot op het punt dat je er overprikkeld van kunt raken.
- Uit de video overnemen als principe, niet als beeld: het hoge tempo van de cuts, lagen
  over elkaar (node-netwerken, tekens, software-resten), regenboog-echo's, glitch,
  symmetrie en rasters.
- Nieuwe visioenen: Ogen, Circuit, Stekels, Helix en Bliksem (zeventien in totaal).
- Chaos neemt toe met de scrollsnelheid. Bij "minder beweging" blijft de pagina rustig.

## Aanvulling (versie 4)
- Twee extra video's bekeken. Tien woorden die eruit komen: chroom, ogen, engelen,
  lotussen, ufo's, glitch, split-screens, symmetrie, regenboog, leegte.
- Verwerk die allemaal in de bestaande visioenen, als principe en niet als kopie.
- Meer kleur: gebruik het hele RGB-spectrum en maak alles kleurrijker.
- Eerst plannen, dan bouwen.

## Aanvulling (versie 5)
- Bug: wit scherm met een droevig gezichtje en duizenden console-fouten.
- Oorzaak zoeken op de echte machine, niet gokken; daarna zo oplossen dat het niet
  opnieuw kan gebeuren als er visioenen bijkomen.

## Aanvulling (versie 6)
- Overal waar het beeld uitzoomt om een visioen te tonen: vervang dat door een oplopend
  snelheidseffect, alsof je met immense snelheid dat visioen in reist.
- Zowel bij de overgang tussen twee visioenen als bij het moment elke 11 seconden.

## Aanvulling (versie 7)
- Bij het moment elke 11 seconden: meer het gevoel dat je erin wordt gezogen en erdoorheen
  racet. Het beeld mag niet "opraken" als je erin gaat; het moet oneindig doorgaan en op
  dezelfde afstand blijven. Het moet voelen als hyperspace in een ruimteschip.
