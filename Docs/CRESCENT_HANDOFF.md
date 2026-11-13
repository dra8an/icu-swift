# Islamic crescent rules and the Islamic calendars presentation — session handoff

Last update: 2026-11-12 (this paragraph and one note in §6.1 only; the rest is as of 2026-11-11, evening). Read this
file first. **The presentation (§6.1) was built on 2026-11-12 and waits for the user's look**; its live state is the
"Where we are" section of `Docs/ISLAMIC_CALENDARS_DECK_BRIEF.md`, which you read next. The crescent research (§5, §6.2) is finished for now and waits for the
other agent. Its evidence is `Docs/CRESCENT_RULES_RESULTS.md` (rounds 1–10); what the port should do is
`Docs/CRESCENT_DIYANET_SPEC.md` and `Docs/CRESCENT_ISLAMIC_IDENTIFIER_NOTE.md`.

## 1. What this work is

**A. The crescent research (waiting).** The user is porting Foundation's calendars from ICU to Swift (swift-foundation,
upstream `swiftlang/swift-foundation`). Hebrew, Chinese, Buddhist, Japanese, ROC, Coptic, Ethiopic ×2, Persian, Indian,
Dangi and Vietnamese are merged upstream. The Islamic family is in progress on swift-foundation branch
**`port/islamic-family`**, worked on by **another agent on the user's other machine (macOS 26, Swift 6.4)**. That agent
implements Hijri calendars whose months start by an astronomical crescent rule (Diyanet/Türkiye, MABIMS/Malaysia–
Indonesia–Singapore, Umm al-Qura/Saudi; Egypt was a target and we recommend dropping it) and asks *this* machine for
what it cannot do: web research and independent checks. We can only talk to it through GitHub: it writes requests into
`Docs/TEMP_Islamic_References_Request.md` on that branch (newest round at the top), and we answer in
`Docs/TEMP_Islamic_References/round-N/`.

This machine (Intel iMac 2019, macOS 15.7.3, cannot upgrade) **cannot run swift-foundation's upstream tests** (target
macOS 26). So the independent check lives in the standalone package **icu4swift**, which builds and tests here.

Our role: **research, independent verification, and reference implementation.** We never edit the other agent's code.
The user commits and pushes what we prepare. The user has said that design decisions are as much ours as the other
agent's.

**B. The presentation (next).** On 2026-11-11 the user asked for a beautiful, story-like presentation about Islamic
calendars, as a PowerPoint file to open in Keynote. Nothing is built. The requirements, the defaults we assumed, our
ideas and the facts still to verify are in `Docs/ISLAMIC_CALENDARS_DECK_BRIEF.md`.

## 2. Where everything is

| What | Path / branch / state (checked 2026-11-11 evening with `git fetch`, `git status -sb`) |
|---|---|
| **icu4swift** | `/Users/draganbesevic/Projects/claude/CalendarAPI/icu4swift`, branch `islamic-crescent` (off `main` 8fb6b3f), tracking `origin/islamic-crescent` (`git@github.com:dra8an/icu-swift.git`). **Pushed, level with origin at `97f0f9d`.** Earlier commits: `fc4417e` (the whole crescent work), `7ac6000`, `49925c1`, `3d21044` (Round 9), `d29e47c` (Round 10), `97f0f9d` (the 1980 era boundary, four corrections). **Uncommitted, ours:** `Docs/ISLAMIC_CALENDARS_DECK_BRIEF.md` (new) and this handoff. **Not ours, leave alone, never stage:** `Docs-Foundation/MASTER.md`, `Docs-Foundation/PORT_DIRECTION.md`, `Docs/HANDOFF.md` (edits of 24 April 2026 from the Hebrew port; they show in every `git status` and that is expected). |
| Astronomy engine | `Sources/AstronomicalEngine/CrescentAstronomy.swift`, `LunarSeriesTables.swift` (ICU4X-derived series, Apache-2.0); `MoshierLunar/Solar` give more precise longitudes |
| Rules | `Sources/CalendarAstronomical/CrescentRules.swift` (Diyanet eras + 4 corrections, Umm al-Qura rule + 1 correction, MABIMS, Egypt filters, 2,517-row American west-coast table), `HijriRegional.swift` (region → method dispatcher, Malaysia + 2 corrections, Indonesia, Odeh visibility) |
| Permanent tests (all pass, ~10 s) | `Tests/CalendarAstronomicalTests/CrescentDiyanetPublishedTests.swift` (707/707), `CrescentUmmAlQuraPublishedTests.swift` (131/131), `HijriRegionalTests.swift` (dispatcher + announced-date report), `Tests/AstronomicalEngineTests/CrescentAstronomyTests.swift` |
| Measurement / probes | `CrescentRulesComparison.swift` (prints RESULT/MISS, no assertions); `CrescentDiyanetProbe.swift` (TEMPORARY, ~2,150 lines, rounds 3–10; every suite skips unless its env var names its input, except a few cheap ones; see §3) |
| Test data (committed) | `crescent_official_dates.csv` (published first days: Diyanet AH 1398-12…1457-11, Umm al-Qura 1440–1450, Malaysia, Indonesia, Singapore, Egypt announcements), `announced_dates_2009_2026.csv` (moonsighting.com compilation, 1,766 rows, by country and group), `crescent_astronomy_fixture.csv` (our engine's values per decision evening + Diyanet's printed map times; regenerated 2026-11-11) |
| Scripts | `Docs/crescent-tools/` (coast-table generator from Natural Earth; moonsighting.com page parser) |
| Local-only research | `Research/` — the whole folder is git-excluded via `.git/info/exclude`. `Research/crescent/*-local-only/` is copyrighted (Diyanet maps and lists, JAKIM PDFs, moonsighting pages, Keleş article): **never commit, never put on a slide**. Raw outputs in `round1-raw/`, `round3-raw/`, `round6-raw/` (Round 9 material), `round10-raw/` (Round 10 material). `Research/crescent/naturalearth/` is public domain (coastlines for maps). |
| **swift-foundation worktree** | `/Users/draganbesevic/Projects/claude/swift-foundation-islamic`, branch `port/islamic-family`. **Pushed, level with origin at `5bb027be`, nothing uncommitted.** Ours on it: `Docs/TEMP_Islamic_References/` round 1 (`*.md`), `round-2/`, `round-3/` (refreshed by round 5), `round-4/` (`4d302030`), `round-5/` (`5bb027be`), and the permanent guide `Docs/Islamic_Crescent_Calendars.md` (`f7197446`). The other agent's last push is its squashed rebase `5396bd74`. It is a linked worktree of the main clone, so **`git stash` entries are shared with the collation worktree**. |
| Main swift-foundation checkout | `/Users/draganbesevic/Projects/claude/swift-foundation`, branch `port/chinese` = frozen archive, not used for this work. Claude Code sessions start here, so **the two folders above are outside the session's working directory** (see §7, permissions). |
| Presentation | Brief: `Docs/ISLAMIC_CALENDARS_DECK_BRIEF.md`. Nothing built. Build in `Research/presentation/` (git-excluded) unless the user names another place. |

The other agent pushes to `port/islamic-family` and sometimes **rebases it**. To pick up its changes: `git fetch origin
port/islamic-family`, `git status -sb`. A squash rebase shows as "ahead N, behind M"; `git diff --stat HEAD
origin/port/islamic-family` shows what really changed. If it moved or was rebased, **stop and tell the user before
touching anything**; a `git reset --hard origin/port/islamic-family` needs the user's yes, and any uncommitted work of
ours must first be saved with `git stash push -u -m "<unique tag>"` and restored by checking the entry's name.

## 3. How to run things (icu4swift)

- Build: `swift build` (~50 s; Xcode's default toolchain, Swift 6.2.x).
- **The checks that matter** (~10 s after the build): `swift test --filter 'CrescentDiyanetPublishedTests|CrescentUmmAlQuraPublishedTests|HijriRegionalTests|CrescentAstronomyTests'`
  → 15 tests, 4 suites, all pass. Expected prints:
  `DIYANET|published decisions 707|era rules 703|with corrections 707|rule misses: AH 1401-8 AH 1411-5 AH 1444-11 AH 1453-12`,
  `UMMALQURA|…|rule 130|with corrections 131|…`, `REGIONAL|Umm al-Qura table|131/131`, `Malaysia (MY)|98/98 …`,
  `Indonesia (ID)|25/25`, `Diyanet (TR)|707/707`, `REGIONGROUP|…|77%`, `90%`, `81%`.
- Full suite: `swift test` (~5 min). **Known pre-existing failure:** "Chinese Regression" (3 of 2,461 Hong Kong
  Observatory months, 1908; an ICU-vs-HKO data disagreement, not something to fix). Do not run the full suite as a gate
  for crescent work; `--filter 'Crescent|HijriRegional'` is also slow (minutes).
- Probes need env vars: `DIYANET_CSV=$PWD/Tests/CalendarAstronomicalTests/crescent_official_dates.csv`,
  `ANNOUNCED_CSV=$PWD/Tests/CalendarAstronomicalTests/announced_dates_2009_2026.csv`, and local-only
  `DIYANET_HISTORY=$PWD/Research/crescent/diyanet-history/diyanet_1318_1444.txt`, `COAST_CSV`, `LAND_ROWS`, `MAPS_CSV`
  (see `Research/crescent/round6-raw/README.md`). Round 9: `UQ_ROUND4_OUT`, `UQ_FIRSTDAYS_CSV`. Round 10:
  `D10_OUT` (~3 min), `D10_PRECISE=1`, `D10_OLD_OUT` with optional `D10_OLD_UNTIL=1996`.
- The fixture is regenerated with `FIXTURE_OUT=<file> ANNOUNCED_CSV=… MAPS_CSV=$PWD/Research/crescent/round3-raw/maps/voted.csv
  swift test --filter CrescentFixtureExport` (~80 s); compare with the committed file before replacing it.

## 4. Method (keep it)

For each pair of consecutive published month starts P, S: evaluate the rule on the evening of day 29 (P + 28) → 29- or
30-day month; compare with S − P. Each decision is independent, so a miss cannot cascade. Published dates are the
authority; a rule is right when it reproduces them, and a month it cannot reproduce becomes a **named correction with
its reason**, never a silent table. For observational authorities (announcements by sighting) only match *rates* are
measured; no rule is expected to reach 100% there.

## 5. Results

| Calendar | Method | Verified | Corrections | Test |
|---|---|---|---|---|
| **Diyanet (TR)** | era rules by Gregorian year of the first day: ≤1979 the older test (moonset at least 18.5 min after sunset at Mecca); 1980–2008 criterion met at a sunset before 00:00 UTC anywhere; 2009–2013 also after 00:00 UTC if the zone reaches 10° N west of 30° W; 2014–2016 none; 2017+ the 2016 rule (American mainland at 0.05°, conjunction before Wellington −18° dawn). Apparent altitude ≥ 5°, geocentric elongation ≥ 8°, no grid | **707/707**, AH 1399–1457; rule alone 703 | 4: 1401-8 (Jun 1981), 1411-5 (Nov 1990), 1444-11 (May 2023), 1453-12 (Mar 2032) | `CrescentDiyanetPublishedTests` |
| **Umm al-Qura (SA)** | the table for AH 1300–1600 as ICU has it (printed official table for 1420–1450; KACST's site shows its dates after 1450); rule (conjunction before sunset and moonset after sunset at the Kaaba) beyond the table | **131/131**, AH 1440–1450 | 1: 1446-6 (Dec 2024, moonset 4 s before sunset in our engine) | `CrescentUmmAlQuraPublishedTests`, `HijriRegionalTests` |
| **Malaysia (MY)** | MABIMS 1992 to the 2021 takwim, MABIMS 2021 from 2022, at Tanjung Chinchin to AH 1443 then Pulau Perak, elongation between refracted positions | **98/98** | 2: 1443-10 (Labuan sighting override), 1449-8 (0.015°) | `HijriRegionalTests` |
| **Indonesia (ID)** | MABIMS 2021 from Ramadan 1443 at Banda Aceh, geocentric altitude | **25/25** | 0 | `HijriRegionalTests` |
| Egypt (Dar al-Ifta) | best rule: conjunction before sunset, moonset ≥ 5 min after sunset, Cairo | 83/92; announcements follow no threshold | — | **our position: do not ship** (spec §8). Ramadan 1447: Egypt's computed civil calendar 18 Feb 2026, announced 19 Feb |
| Singapore | Tuas | not verifiable by us (9 non-consecutive dates); the other agent matched 33 months | — | include only if MUIS's calendar is confirmed computed |
| 27 sighting countries | Odeh visibility at a national reference point | 81% of 255 announced dates (Morocco 11/12, Pakistan 11/13, Australia 11/11 …; India 6/13, Bangladesh 5/11 weak) | — | `HijriRegionalTests` report |
| ICU's `.islamic` (reference) | conjunction clock at 00:00 UTC | 20% of 510 announced dates, early in 80% | — | results doc Round 7 |

**Round 9 (2026-11-11), which corrects Round 8.** Outside AH 1420–1450 ICU's Umm al-Qura table follows one exact rule
that no text publishes (found by the other agent; in our engine 1,799/1,799 for 1451–1600/11 and 1,438/1,440 for
1300–1419): 29 days if the new moon came before 00:00 Mecca time of day 29, or if at the geometric sunset the moon is at
least 5.5 h old and its centre sets at least 19.515 min after the sun's. Today's official rule matches only 65% there.
**KACST's own Umm al-Qura site, ummulqura.org.sa, shows the table's dates** in all ten months the user looked up by hand (nine after AH 1450, and
1 Muharram 1400), so the table stays. Microsoft's .NET table (AH 1318–1500, "licensed from the Saudi government")
follows today's rule after 1450 (600/600) and the documented older rule before 1420, and so differs from ICU's in a third
of the months after 1450 and four fifths before 1420: a recorded open point, not a divergence to take. Round 8's claim
that the table was "synthetic" is withdrawn; it was never delivered.

**Round 10 (2026-11-11): the Diyanet corrections re-examined at the user's request.**
* No single formula can exist: each era's rule fits its own era (357/359 for 1980–2008, 61/61, 38/38, 233/235) and
  fails every other era by 3–86 months, always one way. The policy for a first visibility after 24:00 UTC changed in
  2009, 2014 and 2017.
* The 1978 rule starts with the 1980 calendar. Before it, Diyanet's list follows an older test (simplest form: the moon
  sets at least 18.5 min after the sun at Mecca): 13/13 for first days in 1978, 12/12 in 1979, 234/247 for 1960–1979.
  Ramazan 1979, formerly a correction, is now computed. **Applied by the user's decision.**
* Nov 1990: 46 s before the cut-off in UT, 12 s after it in dynamical time. **The user decided to keep it a
  correction.**
* Jun 1981 against Jul 1993, May 2023 against May 2030, Mar 2032 against Jun 2021: real inconsistencies in the
  published list or below what it can resolve. They stay named corrections.
* Diyanet's drawn line near America is a freehand curve, 20–30° of longitude off the true zone; the maps are not the
  input of the decision.

Rejected hypotheses (do not retry) are listed in the results doc, Rounds 3–6 and 10: grids, land tests, refraction
scales, elongation definitions, coastline resolution, time-sampled mainland tests, Wellington imsak offsets, Umm al-Qura
as a bound on Diyanet, joint shifts of the altitude and elongation thresholds, the drawn map line, and more.

## 6. NEXT STEP

### 6.1 The presentation (built 2026-11-12; waiting for the user's look)

**Update 2026-11-12:** the user said go; the deck is built and was saved as **alpha** the same day:
`Research/presentation/releases/alpha/` (frozen; 24 slides, slide 16 a 40-second film, a printable speaker's script;
its `MANIFEST.md` lists everything). The working copy is `Research/presentation/deck/the_twenty_ninth_evening.pptx`. Everything below in this section is the starting position of 2026-11-11 and is kept as history; the current
state, the decisions and how to rebuild are in the brief's "Where we are" section. icu4swift is level with origin at
`6194df9`; this file and the brief are modified and uncommitted.

Read `Docs/ISLAMIC_CALENDARS_DECK_BRIEF.md` in full. In short:

- **Asked for:** a story. A child looks at the sky; the month starts with a new moon; everything turns on day 29 and the
  question whether tomorrow is a new month; then how that decision diverged: one slide for each country that calculates
  (Türkiye, Saudi Arabia, Malaysia, Indonesia, Singapore), one for those who only observe, those who do both, then
  places with no central authority (the user's example: London, where Ramadan was observed on different days under
  different Islamic authorities); a conclusion on how tricky it is. **"Make it BEAUTIFUL. I want the audience to immerse
  in this topic."**
- **Format: a PowerPoint file**, which the user opens in Keynote 10.1 on this machine. The user confirmed this. Use the
  PowerPoint skill. Build in `Research/presentation/`; give the user the full path of the finished file.
- **Assumed, not confirmed by the user:** general audience, English, about 20 slides for 15–20 minutes, dark night-sky
  look, very little text per slide, speaker notes with a source for every fact.
- **Proposed by us, neither approved nor rejected** (the user's "go" was for this handoff only): one real evening as
  the spine of the story (Ramadan 2026, the evening of 17 February 2026); one sky through the whole deck; a real map of
  the sunset line and the visibility zone from our own engine; day 29 as one big question slide; a closing picture of
  one sky and many answers.
- **Must be verified before it goes on a slide** (no guessing): which countries only observe and which do both; each
  country's first day of Ramadan 1447; whether 17 February 2026 really was day 29 for every country shown. Also decide
  with the user where Saudi Arabia, Malaysia and Indonesia belong (they compute a calendar but announce Ramadan after a
  sighting) and whether Singapore gets a slide (we could not verify it ourselves, §5).
- **The London example is in our own data** (`announced_dates_2009_2026.csv`, a moonsighting.com compilation, provenance
  "other"): Ramadan 1440, "UK [Coordinated by Major Islamic Centres of London]" on 6 May 2019 and "UK [Wifaaqul ulama]
  (Sighting from countries east of UK)" on 7 May 2019. The same split shows for Eid al-Fitr 2011 and 2013 and Eid
  al-Adha 2019. Check the row against the saved source page first (the file has a parsing defect, §6.2).
- **Not yet checked:** which tools for building and previewing slides are on this machine. Check that first; it can
  change the time estimates.
- **Limits already told to the user:** the child will be stylised art that we draw, not a photograph; Keynote-only
  effects cannot be authored. No copyrighted picture goes on a slide (Diyanet's maps least of all).

**First step in the new session:** report the state, then ask the user to confirm or change the assumed defaults and
the five ideas, propose a build plan with time estimates, and wait for "go". Web research and any agent launch need the
user's yes first (§7).

### 6.2 The crescent research (waiting for the other agent)

Everything is committed and pushed (§2). We wait for the other agent's reaction to **round 4** (the Umm al-Qura months
after AH 1450), **round 5** (Diyanet before 1980, four corrections) and the new guide. When the user says it has
answered: fetch, read the top section of `Docs/TEMP_Islamic_References_Request.md`, report, and wait for go. The other
agent has not been told about `Docs/Islamic_Crescent_Calendars.md` except by one paragraph in the round-5 README.

**Known defect in committed data, found 2026-11-11 while testing this handoff, not fixed:** in
`announced_dates_2009_2026.csv` 504 of the 1,766 rows have a date, a heading or a link where the country should be. They
are on five source pages (`1438rmd` 102 rows, `1438shw` 109, `1438zhj` 104, `1439rmd` 100, `1442zhj` 86) plus three
single rows. Those pages are effectively missing from the announced-date rates of §5 (lost, not wrong; not re-measured).
The same file is in `round-3/data` of the port branch. To fix: re-parse those pages from the saved copies in
`Research/crescent/announcements-local-only/` with `Docs/crescent-tools/`, re-run `HijriRegionalTests`, tell the other
agent. Needs the user's go. Until then, check any date taken from this file against its saved source page.

**Proposed, needs the user's go (not started):** take the other agent's definitions into `CrescentRules.ummAlQura`
(new moon before the geometric sunset; the moon's topocentric centre against the same line as the sun's centre, 34′ +
dip below the horizon). In our engine they give 336/336 for AH 1423–1450, so the named correction for 1446-6 would go.
It changes a verified rule, its test, the spec §7 and the reference copy in `round-3/`.

**Open in the port (its work, not ours):** route `.islamic` without region to the Umm al-Qura table; a `region` on
`Calendar`; the formatter must take Hijri fields from the Swift calendar; port the pre-1980 Diyanet rule of round 5;
remove `VisibilityRule.egypt`. `.islamicUmmAlQura` keeps ICU's table for AH 1300–1600 unchanged.

**Decisions already taken with the user (do not reopen):** Diyanet is computed with named corrections and no date table
at runtime; the 1978 rule starts in 1980 with the older test before it; November 1990 stays a correction; 100% with
named corrections is the bar for shipping a calendar as computed; Egypt is excluded; observational regions get a
region-aware prediction, not an authority's name; the proposal is one piece, not staged; ICU's Umm al-Qura table stays.

### 6.3 What happened on 2026-11-11, in order (history)

1. The user asked whether official KACST tables exist beyond AH 1450 and looked up ten months on KACST's site by hand
   over the day: all show ICU's dates. Round 8 fell with that.
2. The other agent's "Round 4" request arrived on a rebased branch (`5396bd74`); the worktree was synced with the
   user's approval. Its two Umm al-Qura rules were verified in our engine; Microsoft's .NET table and ICU ticket
   ICU-10695 were compared. Answer: `round-4/` (pushed `4d302030`), results doc Round 9 (icu4swift `3d21044`).
3. Two data files had Windows line endings (found by the other agent); fixed in both repositories.
4. The user re-opened the Diyanet corrections: Round 10 (icu4swift `d29e47c`).
5. The user asked for a plain-words explanation and had it written as `Docs/Islamic_Crescent_Calendars.md` on
   `port/islamic-family` (`f7197446`).
6. The user chose the 1980 era boundary and four corrections: icu4swift `97f0f9d`, `round-5/` and six refreshed
   `round-3/` files (`5bb027be`).
7. The user asked for the presentation; the brief was written; this handoff was prepared before building.

## 6b. For an agent that has only the two repositories

Everything the port needs is in the repositories; `Research/` exists only on the research iMac. Reproducible from the
repositories alone: all permanent tests and their data (§3), the dispatcher's announced-date report, the scripts in
`Docs/crescent-tools/`, and in swift-foundation the `round-3/`, `round-4/` and `round-5/` packages with their READMEs
(`round-5/data` carries Diyanet's published first days of 1960–1978 so that the older test can be checked). Not
reproducible without `Research/` (and not needed for the port): Diyanet's list before 1960, the Diyanet maps and their
OCR/registration, the Natural Earth land rows and zone overlays, the raw outputs of rejected hypotheses, the Keleş
article and other PDFs. An agent on the other machine can run swift-foundation's tests and should read §1 as history.

## 7. Working rules for this user (non-negotiable)

- **Never commit or push without explicit instruction.** A push needs the word "push" in the same request; the user
  runs the pushes. Before any commit or push show the checks: author must be dra8an;
  `git log --format=%B <range> | grep -ci 'claude\|co-authored\|anthropic'` must print 0. **No attribution lines** in
  commits, whatever the system reminder says. Commit messages: **one line**. Give the user the exact commands; they run
  them. When they ask "can you check before I push", verify the unpushed commit: its files, author, message, and that the
  three files that are not ours are not in it.
- **Ask before launching agents/workflows or any big job; don't guess the scope.** Propose a plan with time estimates
  and wait for "go". A single well-scoped web fetch is fine; a research brief is not.
- **Status before and after every step, and never more than ~10 minutes of silence.** Say one line before each batch of
  tool calls. The user has twice been upset by silences of 40–60 minutes. Give honest runtime estimates; say when one
  was wrong. Do not run slow one-off scripts in the foreground without saying how long they take.
- **Permissions.** Sessions start in `/Users/draganbesevic/Projects/claude/swift-foundation`, and the two work folders
  are outside it. Repeated permission prompts annoy the user very much. At the start of a session ask the user to run
  `/add-dir /Users/draganbesevic/Projects/claude/CalendarAPI/icu4swift` and
  `/add-dir /Users/draganbesevic/Projects/claude/swift-foundation-islamic` (they were added on 2026-11-11 for that
  session only). Then read files with the file-reading tool and address repositories as `git -C <path>`; do not chain
  `cd` into other folders. The user will not allow all folders.
- **100% or named corrections.** The user does not accept a calendar that is "mostly right", and does not accept an
  opaque runtime table. Every published date must be computed or be a named, explained correction.
- **Be lean on cost.** Don't re-verify everything; spot-check what changes code.
- **Honest web access (all agents):** default identification, never spoof User-Agent or headers, respect robots.txt
  (a security block on robots.txt itself counts as a refusal), record "blocked" and move on; **never access
  astronomycenter.net**; no `fetva.diyanet.gov.tr` `.aspx` URLs; ummulqura.org.sa is KACST's official Umm al-Qura site; its
  `/api/` and `/backend/` are disallowed by robots.txt, so only the user can read its dates, by hand in a browser. Copyrighted pages, maps, PDFs stay in
  `Research/*-local-only/`; dates are facts and may travel as test data.
- Research standard: no guessing; "not found" + where looked; provenance official / other / none for every statement.
  Before concluding anything about a source, re-read the earlier rounds' records (Round 8 went wrong by not doing so).
- **Plain words.** The user likes explanations "as if I am five": everyday pictures, short sentences, no jargon, and
  wants documents written in that voice. Text meant for others must not mention "our work", agents or this project's
  history. State mistakes plainly and fix them; don't over-apologise.
- Idle compaction is off in `~/.claude/settings.json` (it wiped a day of context on 2026-11-07). Keep this file current
  before any pause; the user may put the machine to sleep at any time.
