# Presentation brief: Islamic calendars, told as a story

Written 2026-11-11 from the user's request. Nothing is built yet. This file is the starting point for the session
that builds the deck.

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
