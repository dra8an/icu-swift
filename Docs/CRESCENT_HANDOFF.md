# Islamic crescent rules — session handoff

Last update: 2026-11-09 (evening). Read this file first, then `Docs/CRESCENT_RULES_RESULTS.md` (same folder).

## 1. What this work is

The user is porting Foundation's calendars from ICU to Swift (swift-foundation, upstream `swiftlang/swift-foundation`).
Hebrew, Chinese, Buddhist, Japanese, ROC, Coptic, Ethiopic ×2, Persian, Indian, Dangi and Vietnamese are merged
upstream. Islamic is in progress on swift-foundation branch **`port/islamic-family`**, worked on by **another agent on
the user's other machine (macOS 26, Swift 6.4)**. That agent implements Hijri calendars whose months start by an
astronomical crescent rule — **Diyanet (Türkiye), MABIMS (Malaysia, Indonesia, Singapore; Brunei is sighting-only),
Egypt, Umm al-Qura (Saudi)** — and asks *this* machine for things it cannot do: web research, and independent checks.

This machine (Intel iMac 2019, iMac19,1, macOS 15.7.3, permanently — cannot upgrade) **cannot run swift-foundation's
upstream tests** (deployment target macOS 26). So the independent check lives in the archived, standalone package
**icu4swift** (pure date in / date out, no Foundation harness), which builds and tests here.

Our role: **research + independent verification.** We never touch the other agent's code; we deliver material
(research files, measured findings, suggestions) that the user passes on.

## 2. Where everything is

| What | Path / branch |
|---|---|
| icu4swift package | `/Users/draganbesevic/Projects/claude/CalendarAPI/icu4swift`, branch **`islamic-crescent`** (off `main` 8fb6b3f). Committed as `fc4417e` and pushed to `origin/islamic-crescent` on 2026-11-09 (first push of the branch). `main` has 3 old uncommitted doc edits (Docs-Foundation/MASTER.md, PORT_DIRECTION.md, Docs/HANDOFF.md) that are NOT ours — leave them. |
| Moon/sun astronomy (new) | `Sources/AstronomicalEngine/CrescentAstronomy.swift`, `LunarSeriesTables.swift` (generated from ICU4X astronomy.rs, Apache-2.0) |
| The rules (new) | `Sources/CalendarAstronomical/CrescentRules.swift` |
| Tests | `Tests/AstronomicalEngineTests/CrescentAstronomyTests.swift` (8 reference checks), `Tests/CalendarAstronomicalTests/CrescentRulesComparison.swift` (measurement), data `crescent_official_dates.csv`, `CrescentDiyanetProbe.swift` (TEMPORARY, ~1,400 lines, rounds 3–6; suites take env `DIYANET_HISTORY`, `DIYANET_CSV`, `COAST_CSV`, `LAND_ROWS`, see `Research/crescent/round6-raw/README.md`; the authoritative scored run is `swift test --filter CrescentDiyanetFinalScore`, ~5 min) |
| Results report | `Docs/CRESCENT_RULES_RESULTS.md` (rounds 1–6) |
| Diyanet spec for the port | `Docs/CRESCENT_DIYANET_SPEC.md` (Option B: era rules + five corrections, 707/707); permanent test `Tests/CalendarAstronomicalTests/CrescentDiyanetPublishedTests.swift` |
| Proposal on `.islamic` for the port | `Docs/CRESCENT_ISLAMIC_IDENTIFIER_NOTE.md` (one proposal, no stages: region-aware `.islamic`, default Umm al-Qura; ICU's clock matches 20% of announced dates; work items: routing, region on Calendar, formatter, rules+data). Reference implementation `Sources/CalendarAstronomical/HijriRegional.swift` + `Tests/CalendarAstronomicalTests/HijriRegionalTests.swift` (UQ 131/131, Diyanet 707/707, Malaysia 98/98, Indonesia 25/25; announced dates: sighting 81%, Saudi bloc 77%). Delivered in round 3. |
| Local research artifacts | `Research/crescent/` (excluded via `.git/info/exclude`; `*-local-only/` folders are copyrighted — NEVER commit): raw research JSON, Natural Earth land v5.1.2 + `west_coast.py`, Diyanet's official visibility maps, JUPEM/eKITAB PDFs, raw run outputs |
| Research files delivered to the other agent | swift-foundation worktree `/Users/draganbesevic/Projects/claude/swift-foundation-islamic` (branch `port/islamic-family`, committed + pushed, head 9c0d26d3): `Docs/TEMP_Islamic_References_Request.md` (the other agent's questions, rounds 1–2), `Docs/TEMP_Islamic_References/*.md` (round 1: Diyanet, MABIMS, Egypt, Umm_al-Qura, Archives, SUMMARY), `.../round-2/1_Diyanet.md, 2_American_west_coast.md, 3_Malaysia_JAKIM.md, 4_Umm_al-Qura.md` |
| Main swift-foundation checkout | `/Users/draganbesevic/Projects/claude/swift-foundation`, branch `port/chinese` = frozen research archive (not used for this work). `backup/HANDOFF.md` has an uncommitted rewrite (2026-11-05) of the overall calendar-port state. |

The other agent pushes to `port/islamic-family` and sometimes **rebases it**. To pick up its changes in the worktree:
`git fetch origin port/islamic-family`, check `git status -sb`; if diverged, compare with `git range-diff` and, if
nothing local is unique, `git reset --hard origin/port/islamic-family` (ask the user first).

## 3. How to run things (icu4swift)

- Build: `swift build` (~50 s, Xcode's default Swift 6.2.3 toolchain works).
- Full suite: `swift test` (~5 min). **Known pre-existing failure:** "Chinese Regression" — 3 of 2,461 Hong Kong
  Observatory months (1908), documented in icu4swift `Docs/HANDOFF.md` as an ICU-vs-HKO disagreement in the source
  data: "not something to fix". Unrelated to the crescent work. Everything else passes (450 tests).
- Astronomy reference checks: `swift test --filter CrescentAstronomyTests`.
- The measurement: `swift test --filter CrescentRulesComparison` prints `RESULT|name|matched/total|...` and `MISS|...`
  lines. Diyanet grid step via env `DIYANET_STEP` (default 3; 1 takes ~8 min, 3 takes ~1 min; results identical).
  Sub-tests: `/ummAlQura`, `/egypt`, `/mabims`, `/diyanet`, `/malaysiaJupemStyle`, `/jupemElongationCalibration`.
  Since 2026-11-09 the CSV holds Diyanet rows for AH 1398-12 … 1457-11, so `/diyanet` there now scores the plain 2016
  rule over all of 1978–2035 (a measurement only, no assertion); the authoritative Diyanet check is
  `swift test --filter CrescentDiyanetPublishedTests` (era rules + corrections, 707/707, 7 s).

## 4. Method (keep it)

For each pair of consecutive official month starts P, S: evaluate the rule on the evening of day 29 (P + 28) →
predicts a 29- or 30-day month; compare with S − P. Each decision is scored independently, so one miss cannot cascade.

## 5. Results so far (official dates AH 1440–1460)

| Rule | Best reading | Match | Remaining misses |
|---|---|---|---|
| Umm al-Qura (AH 1440–1450) | conjunction before sunset + moon sets after the sun at the Kaaba (`ummAlQuraMonthLength`) | **131/131** with one correction (`ummAlQuraCorrections`: AH 1446-6, Jumada I 29 days); 130 by rule | 2024-12-01: moonset 7 s before sunset in our computation (independent library `calendrical` misses it too); test `CrescentUmmAlQuraPublishedTests` |
| Diyanet (AH 1399–1457, 1978–2035) | period rules: A ≤ 2008 before 00:00 UTC anywhere; B 2009–2013 + after-midnight start if the zone reaches 10° N west of 30° W; C 2014–2016 none; D 2017+ the 2016 rule (American mainland at 0.05° + Wellington −18° dawn); apparent altitude ≥ 5°, geocentric elongation ≥ 8°, no grid | **702/707** (A 370/373, B 61/61, C 38/38, D 233/235) | 1979-07 (pre-rule year per van Gent), 1981-06 (+0.118°, 1980s program), 1990-11 (+0.006° = 43 s), 2023-05 (batch definition), 2032-03 (3.6 min, twin of started Jun 2021). Proven non-derivable: results doc § Round 6 |
| Malaysia | official ref. points (Tanjung Chinchin ≤1443, Pulau Perak ≥1444), elongation between **refracted** positions, **2021 criterion only from the 2022 takwim edition** (2021 edition used 2-3-8) | **96/98** | AH 1443-10 (Labuan sighting override, unremovable); AH 1449-8 = evening 2027-12-28 (0.015° from AH 1444-5 the other way) |
| Indonesia | Banda Aceh, **geocentric** altitude | 25/25 | — |
| Egypt | conjunction before sunset + moonset ≥ 5 min after sunset, at Cairo (the fatwa's 15h40 filter does NOT match: 67%) | 83/92 | 9 sighting decisions (unremovable); Dhu al-Hijjah follows Saudi (8/8 with the rule) |
| Singapore | Tuas | not measurable | its 9 dates are not consecutive |

Rejected experiments (don't retry): ±60° limit on the America exception (breaks 2030), finer grid, whole-minute
sunset values for Malaysia, Almanak refraction scale (no effect). JUPEM's printed elongations sit ~30% between the
refracted and airless definitions (fitted blend not recommended).

## 6. STATE (2026-11-09) and what is left

**The Diyanet work is finished as far as computation can take it.** One scored run (`CrescentDiyanetFinalScore`,
`Research/crescent/round6-raw/final_score.txt`) gives **702/707** for AH 1399–1457 with the period rules in §5. The five
misses are each closed by a measurement (results doc § Round 6): 1979-07 falls in the last pre-rule year (van Gent dates
the computed rule from 1 Muharrem 1400 = 21 Nov 1979; our list shows 2–3 misses a year through AH 1398, one in 1399,
none in 1400); 1990-11 is 43 seconds and 2032-03 is 3.6 minutes of sunset (Jun 2021 started with the same 3.6 minutes
the other way), both below the precision floor of any independent implementation; 1981-06 is 14 minutes against a
1980s program whose ephemeris is unknown; 2023-05 beats a started month (May 2030) on every quantity and can only be
the 2023–2027 computation run's mainland definition. Diyanet's imsak was measured at Ankara (their 05:54 = our −18° dawn
05:53:43), which closes the Wellington route for 2032. Umm al-Qura, elongation definitions, coastline resolution,
first-visibility place and time-sampled tests were all tried and rejected today; the list of rejected hypotheses in the
results doc is the record — do not retry them.

**Decision (user, 2026-11-09): Option B.** The user accepts only 707/707 and does not want a date table at runtime
("a table we can't calculate"). So the Diyanet calendar is computed from the period rules, with the five published
months carried as named, documented corrections, and the 707 published dates kept as test data only. Asking Diyanet
for its program inputs was judged not workable.

**Option B is implemented and verified (2026-11-09, late morning).** `CrescentRules.swift` now has `DiyanetEra` (four
eras by the Gregorian year of the candidate first day), `diyanetCorrections` (the five months), `diyanetMonthLength`
and `diyanetStartsTomorrow` (lean evaluation, early exit). The permanent test
`Tests/CalendarAstronomicalTests/CrescentDiyanetPublishedTests.swift` computes every month AH 1399–1457 and asserts
707/707 with the corrections and exactly 702 without, with the five misses named; it runs in 7 s. The test data CSV
gained Diyanet's first days AH 1398-12 … 1439-12 (493 rows, dates as published facts; the user has not yet said whether
these may be committed). The spec for the other agent is `Docs/CRESCENT_DIYANET_SPEC.md` (rule, conventions, precision
table, corrections, validity range, test data). Delivered 2026-11-09 as round 3 (see below).

**Our position on scope (2026-11-09; the user: decisions are as much ours as the other agent's).** Ship as computed
calendars only what is reproducible to 100% from published data: **Diyanet** (era rules + five corrections, 707/707),
**Umm al-Qura** (the KACST table as ICU ships it; our rule + one correction as cross-check and fallback, 131/131),
**Malaysia** (rule + two corrections, 98/98; one of the two is a sighting override, so the religious months carry a
small announcement risk, documented), **Indonesia** (25/25, same risk, documented). **Egypt: exclude.** Dar al-Ifta's
monthly announcements are observational and follow no threshold (months started on 0.8° crescents, others refused on
3.3° ones); 83/92 is the ceiling and future announcements cannot be predicted, so a computed "Egypt" would be wrong one
month in ten with no remedy. Egypt's own computed civil calendar (Egyptian Survey Authority) is a different calendar
that disagrees with the announcements (Ramadan 1447: ESA 18 Feb 2026, announced 19 Feb); it could be a target only with
several years of ESA dates, which the site's terms forbid copying. The port has Egypt only as internal
`VisibilityRule.egypt` with a few fixtures, no public identifier, so removal is cheap. **Singapore:** not verifiable
(no consecutive official dates); include only if MUIS's calendar is confirmed computed. Recorded also in the spec §8.

**Round 7 (2026-11-09, afternoon): observational announcements measured.** moonsighting.com's per-country lists
(AH 1429–1448, Ramadan/Shawwal/Dhu al-Hijjah) were fetched and parsed: 1,073 country-months, 510 used (national
authorities with a reference point). Predicted-visibility rules at the capital match sighting countries 80–92% (Odeh
zone B), the Saudi-following bloc is matched by Umm al-Qura itself (70–93%), ICU's `islamic` clock matches 20%. Results
doc § Round 7, spec §9. The port's formatters compute Hijri fields in ICU (`udat_formatForFields`), so a location-aware
`.islamic` would print ICU's dates: the first blocker for the user's two-constructor idea. Data: `Research/crescent/
announcements-local-only/` (keep local), `round6-raw/announcements_measure.txt`. Dar al-Ifta's archive starts 2017.

**Package for the other agent delivered (2026-11-09): committed on `port/islamic-family` as "TEMPORARY: round 3 …" and pushed by the user.** swift-foundation worktree
`Docs/TEMP_Islamic_References/round-3/` (README, spec, proposal, results doc, reference code as `.swift.txt`, the four
tests, `crescent_official_dates.csv`, `announced_dates_2009_2026.csv`, `american_west_coast_generator.py`,
`crescent_astronomy_fixture.csv` from probe `CrescentFixtureExport`). The user reviews, then commits and pushes
(one-line message, no attribution, author dra8an). Gaps closed before packaging: astronomy fixture, API sketch
(proposal §5), validity table (spec §11).

**Umm al-Qura adjusted the same way (2026-11-09):** `ummAlQuraCorrections` (AH 1446-6: 29 days) and `ummAlQuraMonthLength`
in `CrescentRules.swift`; `Tests/CalendarAstronomicalTests/CrescentUmmAlQuraPublishedTests.swift` asserts 131/131 with
the correction and exactly 130 without (1 s). Covers AH 1440–1450 only (the rows in the CSV); the official 1420–1450
table (van Gent's PDF) is not on this machine, so the rule is not yet checked on 1420–1439. Malaysia (2 corrections)
and Egypt (9) not yet done in this form.

**When the user says the math is settled**, the material for the other agent is: the period rules and conventions
(§5 and results doc § Round 3 "rule code without a grid", § Round 5, § Round 6), `Sources/CalendarAstronomical/
CrescentRules.swift` as the reference implementation (the B-period latitude rule is in the probe's `FinalScore`, not yet
in `CrescentRules`), the official-date CSV, and the five-date list. Nothing has been passed yet.

**Housekeeping:** icu4swift work committed (`fc4417e`) and pushed; `CrescentDiyanetProbe.swift` was committed too, as the
reproducible record of every rejected hypothesis (its suites skip without their env vars); `Research/crescent/` stays git-excluded (copyrighted maps and Diyanet's list). Still open from earlier rounds:
Umm al-Qura's 7-second tie (2024-12-01) and Malaysia AH 1449-8.

**Cadence rule: a status line before and after every step; never more than ~10 minutes without one; propose and wait
before any job over 15 minutes. Idle compaction is now off in `~/.claude/settings.json` (it wiped a day of context on
2026-11-07); keep this file current before any pause.**

## 6b. For an agent that has only the two repositories

Everything the port needs is in the repositories; the `Research/crescent/` folder exists only on the research iMac and
holds copyrighted sources and exploratory outputs.

**Reproducible from the repositories alone:**
- All permanent tests: `swift test --filter 'CrescentDiyanetPublishedTests|CrescentUmmAlQuraPublishedTests|HijriRegionalTests|CrescentAstronomyTests'`
  (15 tests, ~10 s). Their data is committed: `Tests/CalendarAstronomicalTests/crescent_official_dates.csv` (published
  first days), `announced_dates_2009_2026.csv` (the moonsighting.com compilation, dates and sources), and
  `crescent_astronomy_fixture.csv` (our engine's values per decision evening, including Diyanet's printed map times).
- The regional dispatcher's announced-date report (`HijriRegionalTests.announcedDatesByRegion`) now reads the committed CSV.
- The two scripts that produced data: `Docs/crescent-tools/` (coast table from Natural Earth; parser for the
  moonsighting.com pages, which must be fetched again with plain curl).
- In swift-foundation `port/islamic-family`, `Docs/TEMP_Islamic_References/round-3/` is the same material as a package,
  with a README that says what to port and the four work items.

**Not reproducible without `Research/` (and not needed for the port):** Diyanet's AH 1318–1444 list before AH 1399
(the 617/971 pre-rule analysis), the 326 Diyanet maps and their OCR/registration (`round3-raw/`, `pre2016/`), the
Natural Earth land rows and the zone overlays, the raw outputs of the rejected hypotheses in rounds 3–6 (their numbers
are quoted in `Docs/CRESCENT_RULES_RESULTS.md`, and the probe suites that produced them are committed in
`CrescentDiyanetProbe.swift`, each gated on an env var naming its input), the Keleş article PDF.

## 7. Working rules for this user (non-negotiable)

- **Never commit or push without explicit instruction.** A push needs the word "push" in the same request; the user
  runs it as `! git push ...` (a deny rule blocks `git push` for the assistant). Before any push show the check:
  `git log --format=%B <range> | grep -ci 'claude\|co-authored\|anthropic'` must print 0; author must be dra8an.
  No attribution lines in commits. Commit messages: **one line**.
- **Ask before launching agents/workflows or any big job; don't guess the scope** — the user got upset when research
  started from a guessed brief. Propose a plan with time estimates, then wait for "go".
- **Keep the user informed:** status at least every ~10 minutes during long work, and immediately when something
  finishes or goes wrong. Never go quiet.
- **Be lean on cost.** Don't re-verify everything; spot-check what changes code.
- **Honest web access (all agents):** never spoof a User-Agent or headers, respect robots.txt, record "blocked" and move
  on; **never access astronomycenter.net (ICOP)** — its robots.txt blocks Claude agents.
- Research standard: no guessing; "not found" + where looked; provenance official / other / none for every statement.
- Plain terminology. Don't over-apologise; state mistakes plainly and fix them.
