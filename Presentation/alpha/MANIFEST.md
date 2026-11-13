# The Twenty-Ninth Evening: alpha

Frozen on 2026-11-12. **Nothing in this folder is edited after that date.** Work goes on in the folders above
(`art/`, `deck/`, `tools/`, `engine/`); this is the baseline to compare with and to go back to.

## What is in it

| File | What it is |
|---|---|
| `the_twenty_ninth_evening_alpha.pptx` | The deck: 24 slides, speaker notes on every slide, a dissolve between slides; slide 16 is the film. 25.9 MB. Opens in Keynote 10.1. |
| `the_twenty_ninth_evening_alpha_film.mp4` | The film on slide 16, on its own: 40 seconds, 1920 × 1080, H.264. 6.4 MB. |
| `the_twenty_ninth_evening_alpha_script.pdf` | The printable speaker's script: 13 US Letter pages, one section per slide. |
| `source/` | Everything needed to build the three files above again (see below). |

Checksums (SHA-256):

```
46085c35ee2663c3eb4bee88eda0c236cf6f73d2340b5a06b2a7355c7e443ee5  the_twenty_ninth_evening_alpha.pptx
cfd17258973bbf2443b7c223ed3aa19ecccb4a32f8c5b3a4d204b5d9897d60f9  the_twenty_ninth_evening_alpha_script.pdf
5682834c306b48174bbbaa79258af1fe7dec8a6f908bd224e5e5276b444ea5e6  the_twenty_ninth_evening_alpha_film.mp4
```

## The deck, slide by slide

1 the title (the child on the hill) · 2 the moon as a clock · 3 the moon hides beside the sun · 4 the first crescent ·
5 29 or 30 days · 6 the question · 7 who answers · 8 the eclipse of 17 February 2026 · 9 the map: sunset travels west ·
10 Singapore · 11 Malaysia · 12 Indonesia · 13 Mecca · 14 Saudi Arabia looks · 15 Türkiye · 16 **the film** ·
17 the globe at 03:42 · 18 Morocco and Pakistan · 19 Egypt · 20 London · 21 the map in two colours · 22 Alaska ·
23 the rules change · 24 the closing.

The words and notes of every slide, as plain text: `source/deck/slide_text.md`.

## What `source/` holds

| Part | Files | What it does |
|---|---|---|
| The numbers | `engine/Package.swift`, `engine/Sources/EveningNumbers/main.swift`; results in `engine/out/` (`places.csv`, `grid.csv`, `series.csv`) | A small program that asks the icu4swift astronomy engine for every sunset, the moon's place at it, a world grid, and the moon's distance from the sun through the night |
| The pictures | `art/nightsky.py` (drawing tools), `art/scenes.py` (20 pictures), `art/world_map.py` (the maps), `art/globe.py` (the globe) | Draw every picture; nothing is taken from anywhere else |
| The film | `art/sweep_film.py` | Draws 1,195 frames and encodes them |
| The slides | `deck/build_deck.js` | All 24 slides: layouts, words, labels, speaker notes |
| Tools | `tools/build_all.sh` (one command for everything), `preview.sh` and `keynote_export.applescript` (render through Keynote), `add_fade.py`, `make_script.py` (the printable script), `notes_check.sh` | |
| The record | `docs/FACT_SHEET.md` (every fact with its source), `docs/STORYBOARD.md`, `docs/ISLAMIC_CALENDARS_DECK_BRIEF.md` (the state, the decisions, how to rebuild) | |
| Versions | `package.json`, `package-lock.json`, `python-requirements.txt` | The exact libraries used |

Not copied, because they are downloaded or rebuilt: `node_modules/`, `.venv/`, `engine/.build/`, the pictures in
`deck/art/` (the deck carries its own copies), the renders.

## Built with

- icu4swift at commit `6194df9` (branch `islamic-crescent`), engine sources unchanged since that commit.
- macOS 15.7.3, Keynote 10.1, Node 25.2.1, Python 3.9.6, Swift 6.3.1.
- pptxgenjs 4.0.1; Pillow 11.3.0, numpy 2.0.2, python-pptx 1.0.2, lxml 6.1.3, defusedxml 0.7.1, reportlab 4.2.5,
  imageio-ffmpeg 0.6.0 (ffmpeg 7.1).
- Coastline: Natural Earth, public domain (`Research/crescent/naturalearth/ne_10m_land.geojson`, not copied here: 10 MB).
- Fonts: Iowan Old Style and Avenir Next, which ship with macOS.

## To build it again

From the working folder (`Research/presentation/`), with `node_modules/` and `.venv/` in place:

```
sh tools/build_all.sh engine film pictures deck preview script
```

`engine` recomputes the numbers (65 s the first time), `film` renders the film (3 min), `pictures` draws the stills
(1 min), `deck` writes the slides, `preview` renders them through Keynote, `script` writes the printable script.
With no word after the script's name it runs `pictures deck preview script`.

## What alpha is, and is not

Done and checked: all 24 slides looked at as Keynote renders them; every number and quotation in the slides and
notes compared with the fact sheet; the file opens in Keynote and in a PowerPoint library; the film's length, format
and twelve of its frames checked; Keynote imports the film as a movie covering slide 16.

Open:

- The owner has reviewed slides 3, 9, 16, 19 (London) and 21 (Alaska) so far; the rest await review.
- How the film plays in Keynote was not seen (it may wait for a click: Format → Movie → "Start movie on click"),
  nor how the notes look on the presenter display.
- The fonts ship with Macs only; for PowerPoint on Windows the theme would move to Georgia and Arial.
- The PowerPoint skill's own file checker was not run (it needs Python 3.10 or newer; this Mac has 3.9.6).
- Some facts rest on press reports and are marked so in the notes: how Morocco and Pakistan decide, the Gulf
  countries' date, the report accepted by the Saudi court.
- Ideas not built: a short clip for the Alaska slide; "how" lines under the two answers on the Indonesia slide.
