# Presentation brief: Islamic calendars, told as a story

Written 2026-11-11 from the user's request. Nothing is built yet. This file is the starting point for the session
that builds the deck.

## Where we are (keep this section current; a fresh session starts here)

**2026-11-11, late evening: the user said go.** Build started. The user may not have 5 to 7 hours in one piece, so the
work is cut into steps that each leave finished files in `Research/presentation/`; stop after any step, and write the
state here first.

Decisions taken with the user on 2026-11-11 ("go, yes to all three, all as proposed"):

- The assumed defaults stand: general audience, English, about 20 slides for 15 to 20 minutes, dark night-sky look,
  very little text, speaker notes with a source for every fact.
- All five ideas are approved (the evening of 17 February 2026 as the spine, one sky through the deck, a real map from
  our engine, day 29 as one big question slide, a closing "one sky, many answers").
- Saudi Arabia, Malaysia and Indonesia each keep a "calculates" slide; the "those who do both" slide brings them back
  as the twist (they compute, yet still go out and look for Ramadan). Singapore keeps its slide, saying only what MUIS
  states officially. (Both were our suggestions, covered by "all as proposed"; show them again at the storyboard stop.)
- Yes to: installing one PowerPoint library into the build folder; driving Keynote by script to export previews; web
  research for the missing facts. No agents: one thread.
- If time runs short, the map (step 4) is the piece to postpone; the deck works without it.

The plan and its state:

| Step | What | Estimate | State |
|---|---|---|---|
| 0 | Read the PowerPoint skill, install the library, two-slide test opened in Keynote | 15–20 min | **done** (12 min) |
| 1 | Fact sheet: local data first, then web. **Stop for the user.** | 60–90 min | **done** (about 45 min): `Research/presentation/FACT_SHEET.md`, version 2. **Waiting for the user** on its section 7 (tone on the Saudi evening; London 2026 as the example with 2019 in the notes). |
| 2 | Storyboard: every slide's words and notes. **Stop for the user.** | 20–30 min | **done and approved 2026-11-12** ("I basically agree with all your suggestions"): `Research/presentation/STORYBOARD.md`, 21 slides as drafted. Title: "The Twenty-Ninth Evening". The Saudi evening: nothing on the slide, one plain sentence in the notes, no verdict. London: 2026 on the slide, 2019 in the notes. The three Python packages for the file checker may be installed inside the build folder (`.venv`). |
| 3 | Three sample slides for the look. **Stop for the user.** | 45–60 min | **done 2026-11-12** (25 min): `Research/presentation/samples/twenty_ninth_evening_samples.pptx` (storyboard slides 1, 6, 13). **Waiting for the user to say the look is right; do not build the other slides before that.** |
| 4 | Map of that evening from our engine | 60–90 min | **done 2026-11-12** (about 30 min): `engine/` computes every place for 17 and 18 February and a one-degree world grid; `art/world_map.py` draws the map; it is slide 3 of the sample deck. Results are in the fact sheet, section 1b. |
| 5 | All slides and notes | 90–120 min | **done 2026-11-12** (about 50 min): `deck/the_twenty_ninth_evening.pptx`, 22 slides, 17.7 MB. Pictures: `art/scenes.py` (20) and `art/world_map.py` (2); slides, words and notes: `deck/build_deck.js`. One command rebuilds it: `sh tools/build_all.sh` (pictures, deck, preview; add `engine` to recompute the numbers). The user saw the four samples first ("it looks ok") and asked how hard the background is to change (answered: one place in the code; by hand in Keynote only if built in two layers; **no change requested**). Applied without objection: the four "Proposed after approval" storyboard changes, the Mac fonts, no file checker. The Alaska point has its own slide (20), so there are 22. |
| 6 | Check every slide in Keynote and every number against the fact sheet. **Stop for the user.** | 30–45 min | **my part done 2026-11-12** (about 15 min): all 22 slides looked at as rendered by Keynote (5 layout fixes); every number and quotation in slides and notes checked against the fact sheet (4 wordings corrected); structure checks pass (opens in Keynote and python-pptx, 116 parts well-formed, 22 fades, notes on every slide, no placeholder text; 458 words on slides, about 2,500 in notes, roughly 19 minutes of speaking). **The user looked on 2026-11-12 and said: "Slide 9 is not clear to me".** Reworked the same day: slide 9 now carries one idea (the sunset line when the moon was new and every three hours after, each labelled with the moon's age, an arrow pointing west, one plain sentence under the title); the Greenwich-midnight line and the gold patch moved to a new Türkiye map slide (16, "Its two numbers were met out here. Too late.", with Alaska marked at the patch's edge); the line "east of it the moon set before the sun" is gone. **The deck now has 23 slides** (order from 15: Türkiye skyline, Türkiye map, Morocco and Pakistan, Egypt, London, the two-colour map, Alaska, the changing rules, the closing). `art/world_map.py` now writes three maps (`s09_map`, `s15b_turkiye_map`, `s19_answers`). **Waiting for the user's verdict on the new slide 9 and on the rest.** Lesson: one idea per slide; nothing on a slide that belongs to a rule the audience has not met yet. |

Step 0 result (2026-11-11), all in `Research/presentation/` (git-excluded):

- `node_modules/` holds pptxgenjs 4.0.1 (`npm install --prefix`). Write decks with it, on the `LAYOUT_WIDE` canvas
  (13.333 × 7.5 in; Keynote shows it as 960 × 540).
- **Preview through Keynote, 7 seconds:** `sh tools/preview.sh <deck.pptx> <output folder>` writes a PDF and one
  1600-px JPEG per slide, and prints slide count, each slide's transition and the length of its notes. It opens the
  file with the shell's `open -a Keynote` and closes it unsaved. **Keynote 10.1's own AppleScript `open` does not
  import a PowerPoint file** (it returns nothing and no document appears; it once hung for 170 s), so do not use it.
- `tools/add_fade.py <in.pptx> <out.pptx>` gives every slide a fade; Keynote imports it as Dissolve (PowerPoint
  stores the fade on the slide that comes in, Keynote shows it on the slide that goes out, so the last slide has none).
- Arrived whole in Keynote in the two-slide test (`smoke/`): a full-slide drawn background (Pillow PNG), a see-through
  PNG laid over it, see-through shapes, letter spacing, speaker notes, and the fonts Georgia, Baskerville, Didot,
  Hoefler Text, Iowan Old Style, Palatino, Avenir Next, Helvetica Neue, Optima.
- The PowerPoint skill's file checker (`validate.py`) and text reader need lxml, defusedxml and python-pptx, which are
  not installed. The user was asked whether to install them into a private Python environment in the build folder;
  **no answer yet, do not install without it.** Until then check files through Keynote.

**The user's slide-by-slide comments, 2026-11-12 (more may follow; the user reviews in Keynote with the deck open, and
`tools/build_all.sh preview` now renders from a separately named copy so that it never collides):**

- Slide 3: the plain yellow disc beside the dotted ring read as a moon. Now a sun with rays, labelled "the sun"; the
  ring is labelled "the moon, lost in the glare".
- Slide 9: see step 6 in the table (one idea per slide; Türkiye's line and patch moved to a new slide 16).
- Slide 19 (London): the user asked how East London Mosque declared Ramadan and what it follows. Its own site says it
  uses the Umm al-Qura calendar and "waits for news of the sighting of the new crescent moon"; it never says whose news,
  and no statement by the London committee of mosques was found (fact sheet, section 3). The slide now carries one line
  under each answer on how it was reached; the notes give the quotations. The user then chose the wording for the
  mosque: simply that it uses the Umm al-Qura Islamic calendar, "which is what they say" (the notes keep, in brackets,
  the page's other sentence about waiting for news of a sighting). **Never write that the mosque "follows Saudi
  Arabia": no source says so.** Offered, not done: the same how-lines on slide 12 (Indonesia).
- Slide 16 (Türkiye's second slide): "underwhelming". The flat map with the gold patch at its edge was replaced by a
  globe (`art/globe.py`, added to the `pictures` step): the Earth seen from over the Pacific at 03:42, the sunset line
  glowing, the deadline line dashed, one light at the first place to meet both numbers (about 4°N 142°W), Alaska and
  Hawaii marked, and "3 h 42 min after the deadline" in large type. The sun's place is fitted to the engine's own sunset
  line, not taken from a formula. `s15b_turkiye_map.jpg` is still written by `art/world_map.py` but no longer used.
- **The film (asked for by the user after seeing the globe, 2026-11-12): slide 16 is now a 40-second film, and the deck
  has 24 slides.** `art/sweep_film.py` draws 1,195 frames (full HD, 30 a second) and pipes them to ffmpeg (the
  `imageio-ffmpeg` package in `.venv`); `sh tools/build_all.sh film` re-renders it in about 3 minutes (it is not part of
  the default run). The camera stands still relative to the sun, so the sunset line stays put and the Earth turns under
  it; a place has its sunset when it crosses the line. Beside the globe: a clock, the moon's age, a gauge of the moon's
  distance from the sun (needs 8°), and a "western sky" window showing the moon's height at each place's sunset (needs
  5°). Stops: Singapore/Malaysia/Indonesia, the new moon, Pakistan, Mecca, Egypt/Türkiye, London, Morocco, New York,
  the deadline, Los Angeles, the first place in the Pacific. Film time slows at each stop. Every figure is read from
  `engine/out` (the engine program gained directions, four more places and `series.csv`). In the deck: the film covers
  the slide, its first frame is the slide's picture, kicker and title sit on top (`addMedia` wants a PNG cover with a
  `data:image/png;base64,` header). Keynote imports it as one movie on slide 16 (checked by script). **Not checked: how
  it plays; in Keynote a film may wait for a click (Format → Movie → "Start movie on click").** The still globe slide
  ("The numbers were met out here. Too late.") follows as slide 17. Slides after it moved up by one: 18 Morocco and
  Pakistan, 19 Egypt, 20 London, 21 the two-colour map, 22 Alaska, 23 the changing rules, 24 the closing.
- Slide 21 (Alaska): the user asked what the notes' first sentence, "Here is why Indonesia had two first days", meant.
  It was a look back to slide 12 with nothing to remind the listener. Reworded: "Remember Indonesia: the government
  began Ramadan on Thursday, and Muhammadiyah ... on Wednesday. Here is where that Wednesday came from." Lesson: when the
  notes point back to an earlier slide, say again what that slide showed.

**Speaker notes were nearly invisible in Keynote (found by the user, fixed 2026-11-12).** Cause: the theme's "dark 1"
slot held the cream so that slide text defaulted to cream; notes take that slot too, and Keynote's notes area is white.
Fix in `deck/build_deck.js`: "dark 1" is black again, and the words on the slides ask for the cream by name
(`C.background1`, `C.background2`). Checked: all 23 slides render pixel-identical to before; Keynote's "slide with
notes" export shows black notes (`sh tools/notes_check.sh <deck> <folder>`). Keep notes pure black: Keynote shows black
notes as white on its dark presenter display and leaves other colours as they are (not checked on this machine). The
old sample script `samples/build_samples.js` still has the old theme; it is not used any more.

The printable speaker's script (asked for by the user on 2026-11-12, after asking whether each slide has its
narrative): `deck/the_twenty_ninth_evening_script.pdf`, 12 US Letter pages, made by `tools/make_script.py` from the
deck's own notes and the Keynote renders (step `script` of `tools/build_all.sh`; reportlab 4.2.5 in `.venv`, the last
version for Python 3.9). Per slide: a small picture, the words on it, what to say, the sources, and a time estimate at
130 words a minute. **Spoken length: about 16 minutes** (2,090 spoken words); the "19 to 20 minutes" told to the user
earlier wrongly counted the source lines too.

Step 3 result (2026-11-12), the look and how it is made (all paths under `Research/presentation/`):

- **Pictures** are drawn by `art/nightsky.py` (tools: sky, stars, moon, dashed ring, land cut-outs, minaret, dome,
  houses, lit windows, the child) and composed per slide in `art/samples.py`; 2560 × 1440 JPEG at quality 97 (at 92
  the dark sky showed block edges). Same star field on every slide. Run: `.venv/bin/python art/samples.py samples/art`.
- **Deck** is built by `samples/build_samples.js` on a theme (titles Iowan Old Style, labels Avenir Next; cream words on
  night; gold = Wednesday, moonlight blue = Thursday) and three layouts (Title, Question, Place) with live text and
  speaker notes. Run: `NODE_PATH=<build>/node_modules PPTX_SKILL=<the PowerPoint skill's folder> node
  samples/build_samples.js`, then `tools/add_fade.py`, then `tools/preview.sh`. Do not `cd` anywhere; use full paths.
- **Motifs to keep:** a fine dashed ring marks where the moon is or would be (empty on the question slide, a sliver
  inside it at Mecca, with a small "the moon" label); every place slide ends on a rounded stamp, WEDNESDAY or THURSDAY.
- **The fonts ship with every Mac but not with Windows.** If the file must travel to PowerPoint on Windows, switch the
  theme to Georgia and Arial (one place in the script). Not yet asked.
- **The skill's file checker cannot run here:** it needs Python 3.10 or newer and this Mac has only 3.9.6 (no newer one
  installed; Homebrew is present). Used instead: Keynote's import, opening the file with python-pptx, a well-formed
  check of every part, and the skill's text reader (which works). The user has not been asked to allow a newer Python.
- `.venv/` (Python 3.9) holds lxml, defusedxml, python-pptx, Pillow, numpy.

Step 1 result (2026-11-11): the fact sheet is the only source for slide content; read it before writing any slide.
What it found, in short: the new moon of 17 February 2026 was an annular solar eclipse (NASA); that evening was day 29
for Türkiye, Saudi Arabia, Egypt, Malaysia, Indonesia and Singapore, but day 28 for Morocco, Pakistan and part of
Britain; first days were Wednesday 18 February (Saudi Arabia and the Gulf, Muhammadiyah in Indonesia, East London
Mosque) and Thursday 19 February (Türkiye, Malaysia, Indonesia's government, Singapore, Egypt, Oman, Morocco, Pakistan,
Wifaqul Ulama in Britain). Web pages were read one at a time through the page-reading helper (the `web-fetch` agent
type; the user was told; it is not a research agent). The Saudi Press Agency's pages return only their headline.

Step 4 result (2026-11-12), all under `Research/presentation/`:

- `engine/` is a small Swift package that uses the repository as a library (`.package(path: "../../..")`) and calls
  `CrescentRules.evening`; it changes no tracked file. Build: `swift build -c release --package-path <build>/engine`
  (65 s the first time). Run: `engine/.build/release/EveningNumbers engine/out/places.csv engine/out/grid.csv` (2 s).
  Checks: the Mecca row equals the committed fixture to the second; Singapore's "moon down 4.1 min before the sun"
  agrees with the mufti's "4 minutes earlier"; the gold zone begins at 03:42 UTC, the time Diyanet prints.
- **The sun set in Singapore, Malaysia and Indonesia before the new moon** (40, 24 and 10 minutes before).
- The map: `.venv/bin/python art/world_map.py engine/out/grid.csv <Research/crescent/naturalearth/ne_10m_land.geojson>
  samples/art` writes the picture and `s09_map_points.json` (label positions in inches, read by the deck script).
- Sample deck, four slides in story order (title, question, map, Mecca):
  `samples/twenty_ninth_evening_samples.pptx`, 3.2 MB.

The four checks owed on 2026-11-11 are done (fact sheet version 3). What they changed is proposed in the storyboard
under "Proposed after approval" and **waits for the user's yes**: Singapore's line ("the moon was not even new yet");
Muhammadiyah uses the same rule as Türkiye and the two differed over one point in Alaska; Morocco and Pakistan are
"witnesses decide", not "only look"; the map. Both follow-ups are done (Muhammadiyah's article read at the source; the fixture's "mainland margin" read in the code:
the American mainland's best point came within 0.04° of Türkiye's numbers). Nothing is owed on facts.

The user pushed `6194df9` on 2026-11-11 or 12: icu4swift is level with origin; only this brief is modified.

Found on 2026-11-11 before building (checked, not from memory):

- **Tools on this machine:** Keynote 10.1, Node 25 with npm, Python 3.9.6 with Pillow 11.3 and numpy 2.0, `pdftoppm`,
  `qlmanage`, `sips`, Swift. **Missing:** python-pptx, pptxgenjs, LibreOffice, matplotlib, lxml, ImageMagick, PowerPoint.
  So a library must be installed into the build folder, and previews come from Keynote itself (export to PDF by script,
  then `pdftoppm`).
- **17 February 2026 as day 29 holds in our own official rows** (`crescent_official_dates.csv`): Sha'ban 1447 began on
  20 January 2026 for Diyanet, Umm al-Qura, Malaysia, Indonesia and Egypt, so 17 February was day 29 for all five.
- **First day of Ramadan 1447 in the same file:** Umm al-Qura 18 February 2026; Diyanet 19 February; Indonesia 19
  February (the row's scope is "unknown", its source is the ministry's Aceh office); Egypt 19 February (announced).
  **Not in the file:** Saudi Arabia's actual announcement, Malaysia, Singapore, any observing country, the UK in 2026.
- **`announced_dates_2009_2026.csv` holds only AH 1429–1442** (first days from August 2008 to July 2021; no rows for
  1436, 1437, 1441 or 1443–1447), whatever its name says. Saved pages `1446*.html` and `1447*.html` are in
  `Research/crescent/announcements-local-only/moonsighting/` but are not parsed into the file; why was not looked into.
- **The London rows are in the file as stated below** (`1440rmd`: 6 May 2019 "calculation", 7 May 2019 "sighting");
  still to be checked against the saved page `1440rmd.html`.
- icu4swift is one commit ahead of origin: `6194df9` (the handoff and this brief), checked clean, not pushed. The
  handoff's §2 still calls both files uncommitted; correct that line at the next handoff update.

## What the user asked for (their words, lightly ordered)

- A presentation "like a story", to be opened in Keynote. **Format: a PowerPoint file** (the user confirmed that is
  fine; Keynote 10.1 is installed on this machine and opens it).
- **Opening:** in line with our guide: the month starts with a new moon. "Ideally, some kid looking at the sky."
- **The hinge:** the whole story is about what happens on **day 29**, when someone must decide whether the next day is
  a new month or not.
- **The plot:** how that decision diverged across countries.
  - One slide for **each country that calculates**.
  - One slide for **those who just observe**.
  - Cover **those that do both**.
  - Then the countries with **no central authority**, which rely on one or more local authorities. The user's example:
    **London, where Ramadan was observed on different days** depending on which Islamic authority in the UK a mosque
    follows.
- **Ending:** a conclusion about how tricky it is to do this properly.
- **Quality bar:** "Make it BEAUTIFUL. I want the audience to immerse in this topic!"
- "If you have any other idea how to make it better, just bring it up."

## Defaults assumed (the user has not specified these; confirm or change)

General audience, English, about 20 slides for a 15 to 20 minute talk, dark night-sky look, very little text per
slide, speaker notes under every slide with the facts and their sources.

## Ideas proposed to the user (not yet approved)

1. **One real evening as the spine of the story.** Ramadan 2026: the evening of 17 February 2026. One moon, one
   evening, different first days. Each country's slide then shows what it decided that evening and why. Dates must be
   verified first (see below).
2. **One sky through the whole deck.** The same night sky on every slide; the crescent thickens as the story moves on;
   each country gets its own horizon silhouette and its numbers in large type.
3. **A real map from our own calculation.** The sunset line sweeping the Earth and the zone where the crescent is
   visible on that evening, drawn from our engine and the public-domain Natural Earth coastline we already hold.
4. **Day 29 as one big question slide:** "Tomorrow: day 1, or day 30?"
5. **A closing picture:** one sky, many answers, and what that means for anyone who has to put it in software.

## Facts that must be verified before they go on a slide (rule: no guessing, state the source)

- Which countries calculate, which only observe, which do both. What we have verified: Türkiye (Diyanet, computed),
  Saudi Arabia (computed civil calendar; the Supreme Court decides Ramadan, Shawwal and Dhu al-Hijjah by sighting),
  Malaysia and Indonesia (computed calendar, with sighting sessions that can override), Singapore (computed), Egypt
  (observational), and 27 sighting countries measured in `announced_dates_2009_2026.csv` (moonsighting.com compilation).
- The United Kingdom example. Our announced-dates file already holds one (source: moonsighting.com's compilation, a
  secondary source): **Ramadan 1440, 2019**. "UK [Coordinated by Major Islamic Centres of London]" began on 6 May 2019;
  "UK [Wifaaqul ulama] (Sighting from countries east of UK)" began on 7 May 2019. The same split appears for Eid al-Fitr
  2011 and 2013 and Eid al-Adha 2019. Check the row against the saved source page before using it: 504 of the file's
  1,766 rows are mis-parsed (handoff §6.2).
- The first day of Ramadan 1447 (2026) for each country shown, and whether 17 February 2026 was day 29 for each of
  them (a country whose month before started a day later looks on the 18th).
- Two choices for the user: where Saudi Arabia, Malaysia and Indonesia belong (they compute a calendar but announce
  Ramadan after a sighting), and whether Singapore gets its own slide (we could not verify its calendar ourselves; the
  other agent matched 33 months).

## Where the material is

- Plain-words guide: `Docs/Islamic_Crescent_Calendars.md` in the swift-foundation-islamic worktree (the story's voice).
- Rules and numbers: `Docs/CRESCENT_DIYANET_SPEC.md`, `Docs/CRESCENT_RULES_RESULTS.md`, `Docs/CRESCENT_HANDOFF.md` §5.
- Announced dates by country: `Tests/CalendarAstronomicalTests/announced_dates_2009_2026.csv`.
- Round 1 research on each authority: `Docs/TEMP_Islamic_References/*.md` in the swift-foundation-islamic worktree.
- Coastline for maps: `Research/crescent/naturalearth/` (public domain). Diyanet's maps are copyrighted: never put
  them on a slide.

## Working notes for the build

- Use the PowerPoint skill. Draw the art as vector shapes or render our own images; no copyrighted pictures.
- Not yet checked: which tools for building and previewing slides are on this machine. Check before estimating.
- Build in `Research/presentation/` of icu4swift (the `Research/` folder is git-excluded) unless the user names another
  place, and give the user the full path of the finished file.
- First step: ask the user to confirm or change the assumed defaults and the five ideas, propose a build plan with time
  estimates, and wait for "go". The user's "go" on 2026-11-11 was for the handoff only.
- The illustration of a child looking at the sky will be stylised art that we draw, not a photograph.
- The user's working rules apply (handoff §7): a status line before and after every step, ask before launching agents.
