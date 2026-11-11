# Islamic crescent rules — session handoff

Last update: 2026-11-11, midday. Read this file first, then `Docs/CRESCENT_RULES_RESULTS.md` (the evidence,
rounds 1–9), then `Docs/CRESCENT_DIYANET_SPEC.md` and `Docs/CRESCENT_ISLAMIC_IDENTIFIER_NOTE.md` (what the port should do).

## 1. What this work is

The user is porting Foundation's calendars from ICU to Swift (swift-foundation, upstream `swiftlang/swift-foundation`).
Hebrew, Chinese, Buddhist, Japanese, ROC, Coptic, Ethiopic ×2, Persian, Indian, Dangi and Vietnamese are merged
upstream. The Islamic family is in progress on swift-foundation branch **`port/islamic-family`**, worked on by **another
agent on the user's other machine (macOS 26, Swift 6.4)**. That agent implements Hijri calendars whose months start by
an astronomical crescent rule (Diyanet/Türkiye, MABIMS/Malaysia–Indonesia, Umm al-Qura/Saudi; Egypt was a target and
we recommend dropping it) and asks *this* machine for what it cannot do: web research and independent checks.

This machine (Intel iMac 2019, macOS 15.7.3, cannot upgrade) **cannot run swift-foundation's upstream tests** (target
macOS 26). So the independent check lives in the standalone package **icu4swift**, which builds and tests here.

Our role: **research, independent verification, and reference implementation.** We never edit the other agent's code.
We deliver material (documents, reference code, data) into `Docs/TEMP_Islamic_References/round-N/` of the swift-foundation
worktree; the user commits and pushes it. The user has said that design decisions are as much ours as the other agent's.

## 2. Where everything is

| What | Path / branch / state (checked 2026-11-09 late evening) |
|---|---|
| **icu4swift** | `/Users/draganbesevic/Projects/claude/CalendarAPI/icu4swift`, branch `islamic-crescent` (off `main` 8fb6b3f), tracking `origin/islamic-crescent` (`git@github.com:dra8an/icu-swift.git`). Pushed commits: `fc4417e` (the whole crescent work), `7ac6000` (handoff record), `49925c1` (self-contained: announced-dates CSV, scripts, §6b). **Uncommitted, ours** (see §6): `Docs/CRESCENT_HANDOFF.md`, `Docs/CRESCENT_RULES_RESULTS.md`, `Tests/CalendarAstronomicalTests/CrescentDiyanetProbe.swift`, and the two CSV files `announced_dates_2009_2026.csv` and `crescent_official_dates.csv` (line endings only). **Not ours, leave alone:** `Docs-Foundation/MASTER.md`, `Docs-Foundation/PORT_DIRECTION.md`, `Docs/HANDOFF.md` (old uncommitted edits from before this work). |
| Astronomy engine | `Sources/AstronomicalEngine/CrescentAstronomy.swift`, `LunarSeriesTables.swift` (ICU4X-derived series, Apache-2.0) |
| Rules | `Sources/CalendarAstronomical/CrescentRules.swift` (Diyanet eras + 5 corrections, Umm al-Qura rule + 1 correction, MABIMS, Egypt filters, 2,517-row American west-coast table), `HijriRegional.swift` (region → method dispatcher, Malaysia + 2 corrections, Indonesia, Odeh visibility) |
| Permanent tests (all pass, ~10 s) | `Tests/CalendarAstronomicalTests/CrescentDiyanetPublishedTests.swift` (707/707), `CrescentUmmAlQuraPublishedTests.swift` (131/131), `HijriRegionalTests.swift` (dispatcher + announced-date report), `Tests/AstronomicalEngineTests/CrescentAstronomyTests.swift` |
| Measurement / probes | `CrescentRulesComparison.swift` (prints RESULT/MISS, no assertions); `CrescentDiyanetProbe.swift` (TEMPORARY, ~1,900 lines, rounds 3–9; its last suite `CrescentUmmAlQuraRound4Check` runs only with `UQ_ROUND4_OUT=<file>` (the two rules of the other agent against ICU's table, one row per month, about 30 s) or `UQ_FIRSTDAYS_CSV=<file>` (the same rules against any other list of month starts); every suite skips unless its env var names its input, except a few cheap ones) |
| Test data (committed) | `crescent_official_dates.csv` (published first days: Diyanet AH 1398-12…1457-11, Umm al-Qura 1440–1450, Malaysia, Indonesia, Singapore, Egypt announcements), `announced_dates_2009_2026.csv` (moonsighting.com compilation, 1,766 rows), `crescent_astronomy_fixture.csv` (our engine's values per decision evening + Diyanet's printed map times) |
| Scripts | `Docs/crescent-tools/` (coast-table generator from Natural Earth; moonsighting.com page parser) |
| Local-only research | `Research/crescent/` — git-excluded via `.git/info/exclude`; `*-local-only/` folders are copyrighted (Diyanet maps and lists, JAKIM PDFs, moonsighting pages, Keleş article) — **never commit**. Raw outputs in `round1-raw/`, `round3-raw/`, `round6-raw/` (README in each). |
| **swift-foundation worktree** | `/Users/draganbesevic/Projects/claude/swift-foundation-islamic`, branch `port/islamic-family`, in sync with origin at `5396bd74` (the other agent's squashed rebase of 2026-11-11; our round 1–3 material is unchanged in it). It is a linked worktree of the main clone, so **`git stash` entries are shared with the collation worktree**: check the entry's name before any `git stash pop`. Delivered: `Docs/TEMP_Islamic_References/` round 1 (`*.md`), `round-2/`, `round-3/`. **Uncommitted, ours:** `round-4/` (new) and the line endings of `round-3/data/*.csv`. The other agent's requests are in `Docs/TEMP_Islamic_References_Request.md` (newest round at the top). |
| Main swift-foundation checkout | `/Users/draganbesevic/Projects/claude/swift-foundation`, branch `port/chinese` = frozen archive, not used for this work |

The other agent pushes to `port/islamic-family` and sometimes **rebases it**. To pick up its changes: `git fetch origin
port/islamic-family`, `git status -sb`; if diverged, `git range-diff`, and only after asking the user `git reset --hard
origin/port/islamic-family` — **first `git stash push -u -- Docs/TEMP_Islamic_References`** (the uncommitted `round-4/` and `round-3/data` edits) or they are lost; the stash list is shared with the collation worktree, so check the top entry's name before `git stash pop`. A squash rebase shows as "ahead N, behind M"; `git diff --stat HEAD origin/port/islamic-family` shows what really changed.

## 3. How to run things (icu4swift)

- Build: `swift build` (~50 s; Xcode's default toolchain, Swift 6.2.x).
- **The checks that matter** (~10 s): `swift test --filter 'CrescentDiyanetPublishedTests|CrescentUmmAlQuraPublishedTests|HijriRegionalTests|CrescentAstronomyTests'`
  → 15 tests, 4 suites, all pass. Expected prints: `DIYANET|published decisions 707|era rules 702|with corrections 707|…`,
  `UMMALQURA|…|rule 130|with corrections 131|…`, `REGIONAL|Umm al-Qura table|131/131`, `Malaysia (MY)|98/98 …`,
  `Indonesia (ID)|25/25`, `Diyanet (TR)|707/707`, `REGIONGROUP|…|77%`, `90%`, `81%`.
- Full suite: `swift test` (~5 min). **Known pre-existing failure:** "Chinese Regression" (3 of 2,461 Hong Kong
  Observatory months, 1908; documented as an ICU-vs-HKO data disagreement, not something to fix). Do not run the full
  suite as a gate for crescent work; `--filter 'Crescent|HijriRegional'` is also slow (minutes) because it includes the
  measurement and the probes.
- `CrescentRulesComparison` prints measurements only; its `/diyanet` scores the plain 2016 rule over 1978–2035 (not the
  era rules) and is not an assertion.
- Probes need env vars: `DIYANET_CSV=$PWD/Tests/CalendarAstronomicalTests/crescent_official_dates.csv`,
  `ANNOUNCED_CSV=$PWD/Tests/CalendarAstronomicalTests/announced_dates_2009_2026.csv`, and local-only
  `DIYANET_HISTORY`, `COAST_CSV`, `LAND_ROWS`, `MAPS_CSV`, `FIXTURE_OUT` (see `Research/crescent/round6-raw/README.md`).

## 4. Method (keep it)

For each pair of consecutive published month starts P, S: evaluate the rule on the evening of day 29 (P + 28) → 29- or
30-day month; compare with S − P. Each decision is independent, so a miss cannot cascade. Published dates are the
authority; a rule is right when it reproduces them, and a month it cannot reproduce becomes a **named correction with
its reason**, never a silent table. For observational authorities (announcements by sighting) only match *rates* are
measured; no rule is expected to reach 100% there.

## 5. Results

| Calendar | Method | Verified | Corrections | Test |
|---|---|---|---|---|
| **Diyanet (TR)** | era rules by Gregorian year of the first day: ≤2008 criterion met at a sunset before 00:00 UTC anywhere; 2009–2013 also after 00:00 UTC if the zone reaches 10° N west of 30° W; 2014–2016 none; 2017+ the 2016 rule (American mainland at 0.05°, conjunction before Wellington −18° dawn). Apparent altitude ≥ 5°, geocentric elongation ≥ 8°, no grid | **707/707**, AH 1399–1457; rule alone 702 | 5: 1399-9 (1979, last pre-rule year), 1401-8 (1981, 14 min, 1980s program), 1411-5 (1990, 43 s), 1444-11 (2023, that run's mainland definition), 1453-12 (2032, 3.6 min of sunset) — proven non-derivable, results doc Round 6 | `CrescentDiyanetPublishedTests` |
| **Umm al-Qura (SA)** | the table for AH 1300–1600 as ICU has it (printed official table for 1420–1450; KACST's site shows its dates after 1450); rule (conjunction before sunset and moonset after sunset at the Kaaba) beyond the table | **131/131**, AH 1440–1450 | 1: 1446-6 (Dec 2024, moonset 4 s before sunset in our engine) | `CrescentUmmAlQuraPublishedTests`, `HijriRegionalTests` |
| **Malaysia (MY)** | MABIMS 1992 to the 2021 takwim, MABIMS 2021 from 2022, at Tanjung Chinchin to AH 1443 then Pulau Perak, elongation between refracted positions | **98/98** | 2: 1443-10 (Labuan sighting override), 1449-8 (0.015°) | `HijriRegionalTests` |
| **Indonesia (ID)** | MABIMS 2021 from Ramadan 1443 at Banda Aceh, geocentric altitude | **25/25** | 0 | `HijriRegionalTests` |
| Egypt (Dar al-Ifta) | best rule: conjunction before sunset, moonset ≥ 5 min after sunset, Cairo | 83/92; announcements follow no threshold (months started on 0.8° crescents, others refused on 3.3°) | — | **our position: do not ship** (spec §8). Egypt's computed civil calendar (Egyptian Survey Authority) is a different calendar and itself disagrees with the announcements (Ramadan 1447: ESA 18 Feb 2026, announced 19 Feb); it would need its own multi-year data, which the ESA site's terms forbid copying |
| Singapore | Tuas | not verifiable (9 non-consecutive dates) | — | include only if MUIS's calendar is confirmed computed |
| 27 sighting countries | Odeh visibility at a national reference point (zone B or A as measured) | 81% of 255 announced dates (Morocco 11/12, Pakistan 11/13, Australia 11/11 …; India 6/13, Bangladesh 5/11 weak) | — | `HijriRegionalTests` report |
| ICU's `.islamic` (reference) | conjunction clock at 00:00 UTC | 20% of 510 announced dates, early in 80% | — | results doc Round 7 |

**Round 9 finding (2026-11-11), which corrects Round 8:** outside AH 1420–1450 ICU's Umm al-Qura table follows one
exact rule that no text publishes (found by the other agent; in our engine 1,799/1,799 for 1451–1600/11 and 1,438/1,440
for 1300–1419): 29 days if the new moon came before 00:00 Mecca time of day 29, or if at the geometric sunset the moon
is at least 5.5 h old and its centre sets at least 19.515 min after the sun's. Today's official rule matches only 65%
there, always erring one way. **KACST's site shows the table's dates** in all ten months the user looked up
by hand (nine after AH 1450, and 1 Muharram 1400), so the table stays. A second table with a Saudi source, Microsoft's .NET (AH 1318–1500), follows today's
rule for 1451–1500 (600/600) and the documented older rule before 1420, and so differs from ICU's in a third of the
months after 1450 and four fifths before 1420: a recorded open point, not a divergence to take. Evidence: results doc
Round 9; `Research/crescent/round6-raw/`.

Rejected hypotheses (do not retry) are listed in the results doc, Rounds 3–6: grids, land tests, refraction scales,
elongation definitions, coastline resolution, time-sampled mainland tests, Wellington imsak offsets (Diyanet's imsak is
the −18° dawn to the minute, measured at Ankara), Umm al-Qura as a bound on Diyanet, and more.

## 6. NEXT STEP

**State on 2026-11-11, midday: Round 9 is finished and nothing is committed.** The user said "go" for a five-step plan
(sync, line endings, verify the other agent's rules, write round 4, correct Round 8) plus two optional checks; all of
it is done. What happened, in order:

1. The user asked whether official KACST tables exist beyond AH 1450, then looked up six months on KACST's site by
   hand: the site shows **ICU's dates**, not the dates of today's rule. Round 8's conclusion fell with that. (Later
   the same day the user looked up four more, with the same result; see below.)
2. The other agent's "Round 4" request arrived (`Docs/TEMP_Islamic_References_Request.md`, top section) on a
   **rebased** `port/islamic-family` (`5396bd74`). The worktree was synced to it (stash, hard reset, pop; the user
   approved). Its request: which dates KACST publishes after AH 1450, and our rule's count against the table.
3. Its two Umm al-Qura rules were checked in our engine and hold (results doc Round 9): its current rule 336/336 for
   AH 1423–1450 with no correction; its fitted table rule 1,799/1,799 for 1451–1600/11 and 1,438/1,440 for 1300–1419.
4. Microsoft's .NET table and the attachment of ICU ticket ICU-10695 were compared (results doc Round 9, parts 3–4).
5. Our answer was written to the swift-foundation worktree: `Docs/TEMP_Islamic_References/round-4/` (README, two
   Markdown files, three data files). The uncommitted Round 8 refresh of `round-3/` was discarded (never delivered);
   `round-3/` is as delivered except for the line endings of its two CSV files.
6. In icu4swift the Round 8 restriction in `HijriRegional.swift` and the Round 8 edits of the spec and the identifier
   note were undone (those three files equal their committed versions again); the results doc got a correction note
   on Round 8 and a new Round 9.

**Uncommitted now, all ours, ready to commit when the user says so** (one-line messages, no attribution):

```
cd /Users/draganbesevic/Projects/claude/CalendarAPI/icu4swift
git add Docs/CRESCENT_HANDOFF.md Docs/CRESCENT_RULES_RESULTS.md Tests/CalendarAstronomicalTests/CrescentDiyanetProbe.swift Tests/CalendarAstronomicalTests/announced_dates_2009_2026.csv Tests/CalendarAstronomicalTests/crescent_official_dates.csv
git commit -m "crescent: Umm al-Qura table checked against KACST's site, .NET and the other agent's two rules (Round 9); Round 8 corrected; unix line endings in two data files"
cd /Users/draganbesevic/Projects/claude/swift-foundation-islamic
git add Docs/TEMP_Islamic_References/round-3/data Docs/TEMP_Islamic_References/round-4
git commit -m "TEMPORARY: round 4 research results for the Umm al-Qura months after AH 1450, and unix line endings in two round 3 data files, do not merge upstream"
```
followed in each repo by `git log -1 --format='%an <%ae>'` (dra8an) and `git log -1 --format=%B | grep -ci 'claude\|co-authored\|anthropic'` (0); the user pushes. Before committing in swift-foundation, `git fetch origin port/islamic-family` and `git status -sb` again: the other agent rebases.

**Waiting for, after the push:** the other agent's reaction to round 4.

**Lookups by the user on ummulqura.org.sa, all done (2026-11-11, two sittings):** six of our test months, then the
remaining three of the other agent's list (1 Dhu al-Qa'da 1451, 1 Ramadan 1453, 1 Shawwal 1454) and 1 Muharram 1400.
All ten show ICU's date; `round-4/` and the results doc already say so. Nothing is waiting on the user except the
commit and push, and the decision below.

**Proposed, needs the user's go (not started):** take the other agent's definitions into `CrescentRules.ummAlQura`
(new moon before the geometric sunset; the moon's topocentric centre against the same line as the sun's centre, 34′ +
dip below the horizon). In our engine they give 336/336 for AH 1423–1450, so the named correction for 1446-6 would go.
It changes a verified rule, its test (`CrescentUmmAlQuraPublishedTests` prints `rule 130|with corrections 131`), the
spec §7 and the reference copy in `round-3/`.

**Local raw material of Round 9** (git-excluded, `Research/crescent/round6-raw/`): `uq_round4_check.csv` (one row per
month, our engine), `dotnet-umalqura/` (Microsoft's source file, the month starts computed from it, the rules against
it), `icu-10695/` (ticket JSON and both attachments), `uq_site_check_months_2026-11-11.txt` (the ten test months),
`round3-refresh-backup-2026-11-11/` and `round8-uncommitted-backup-2026-11-11/` (the discarded Round 8 versions).

**Open in the port (its work, not ours):** route `.islamic` without region to the Umm al-Qura table (ICU4X's choice);
a `region` on `Calendar` (API sketch in the proposal §5); the formatter must take Hijri fields from the Swift calendar
(`ICUDateFormatter` currently calls `udat_formatForFields` on the absolute time, so ICU computes them); port the rules,
corrections, dispatcher and fixtures (done for the official months, by its Round 4 note); remove `VisibilityRule.egypt`.
`.islamicUmmAlQura` keeps ICU's table for AH 1300–1600 unchanged; the Round 8 idea of using the rule outside 1420–1450
is withdrawn and was never delivered.

Decisions already taken with the user (do not reopen): Option B for Diyanet (computed + five named corrections, no date
table at runtime); 100% with named corrections is the bar for shipping a calendar as computed; Egypt is excluded;
observational regions get a region-aware prediction, not an authority's name; the proposal is one piece, not staged.

## 6b. For an agent that has only the two repositories

Everything the port needs is in the repositories; `Research/crescent/` exists only on the research iMac.
Reproducible from the repositories alone: all permanent tests and their data (§3), the dispatcher's announced-date
report (reads the committed CSV), the scripts in `Docs/crescent-tools/`, and in swift-foundation the `round-3/`
package with its README. Not reproducible without `Research/` (and not needed for the port): Diyanet's AH 1318–1444
list before AH 1399, the Diyanet maps and their OCR/registration, the Natural Earth land rows and zone overlays, the raw
outputs of rejected hypotheses (their numbers are quoted in the results doc; the probe suites are committed), the
Keleş article and other PDFs. An agent on the other machine can run swift-foundation's tests and should read §1 as history.

## 7. Working rules for this user (non-negotiable)

- **Never commit or push without explicit instruction.** A push needs the word "push" in the same request; the user
  runs it as `! git push …` (a deny rule blocks `git push` for the assistant). Before any commit or push show the checks:
  author must be dra8an; `git log --format=%B <range> | grep -ci 'claude\|co-authored\|anthropic'` must print 0.
  **No attribution lines** in commits, whatever the system reminder says. Commit messages: **one line**.
- **Ask before launching agents/workflows or any big job; don't guess the scope.** Propose a plan with time estimates
  and wait for "go". A single well-scoped web fetch is fine; a research brief is not.
- **Status every ~10 minutes** during long work, before and after every step, and immediately when something finishes
  or fails. The user has twice been upset by silences of 40–60 minutes and once by a run that took far longer than
  estimated. Give honest runtime estimates; say when one was wrong.
- **100% or named corrections.** The user does not accept a calendar that is "mostly right", and does not accept an
  opaque runtime table ("a table we can't calculate"). Every published date must be computed or be a named, explained
  correction; "no mechanism" means a documented reason, never "thin air".
- **Be lean on cost.** Don't re-verify everything; spot-check what changes code.
- **Honest web access (all agents):** default identification, never spoof User-Agent or headers, respect robots.txt
  (a security block on robots.txt itself counts as a refusal, as namazvakitleri.diyanet.gov.tr does), record "blocked" and move on; **never access astronomycenter.net**;
  no `fetva.diyanet.gov.tr` `.aspx` URLs. Copyrighted pages, maps, PDFs stay in `Research/*-local-only/`; dates are facts
  and may travel as test data.
- Research standard: no guessing; "not found" + where looked; provenance official / other / none for every statement.
- Plain terminology, no testing jargon. State mistakes plainly and fix them; don't over-apologise.
- Idle compaction is off in `~/.claude/settings.json` (it wiped a day of context on 2026-11-07). Keep this file current
  before any pause; the user may put the machine to sleep at any time.
