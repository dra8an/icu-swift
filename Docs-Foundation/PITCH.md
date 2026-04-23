# Foundation Calendar Port — Pitch Plan

*Created 2026-04-17. The plan for how to pitch this project to the
`swift-foundation` team in a 3–5 minute window.*

## The frame

In 3–5 minutes you cannot sell the whole plan. You can only answer
one question: **"Is this real and worth a longer conversation?"**
Every sentence that does not advance that is wasted.

The pitch is not "here is my plan." It is "here is credible evidence
this is a direction worth pursuing, and I want to know the right way
to start."

## The structure

Four beats, roughly 60–90 seconds each. Total under 5 minutes.

### Beat 1 — Hook (30 s)

One sentence that states what you **have**, with a number. Not what
you want to build; what you have built.

> "I've built a pure-Swift calendar backend for all 26 non-Gregorian
> identifiers that Foundation currently routes to ICU. 321 tests,
> daily regression 1900–2100 against Hebcal, Hong Kong Observatory,
> KACST — zero divergences."

That is it. No setup, no preamble. They now know you have working
code, validated against authoritative sources, at meaningful scope.
If they are not interested after this, they will say so.

### Beat 2 — Why this matches Foundation's trajectory (60 s)

Position them as already going this way. You are not proposing a new
direction; you are offering to finish one that is already started.

> "Foundation already has `_CalendarGregorian` — pure Swift, no ICU.
> Every other identifier still round-trips through `ucal_open /
> ucal_get / ucal_set` with a mutex. The Swift/ICU boundary for
> calendars is one identifier deep. I'd like to help complete what
> `_CalendarGregorian` started."

This reframes the pitch from "please accept my code" to "I have
noticed a half-finished initiative and I can help with the rest."

**Internal corroboration available if needed.** Foundation-rizz
ships an internal design doc (`Docs/Calendar_Swift.md`) whose
opening sentence is *"The overall goal is to put as much of the
implementation of NSCalendar into Swift as possible,"* and which
states explicitly that *"ICU's calendrical calculations are
stateful, and initializing the data structures is expensive."* If
the conversation needs reinforcement, you can point at their own
doc — you are not introducing a new direction or a foreign
concern. Issue swiftlang/swift-foundation#1842 (filed by itingliu,
documented in `FOUNDATION_APPLE.md`) makes the same point about
specific `ucal_*` overheads. Use as backup; do not lead with it.

### Beat 3 — One proof point (60–90 s)

**Pick exactly one.** Do not tour all 23 calendars. Pick the single
example with the most "wow" per word. Options, in order of impact
for a Foundation engineer:

1. **Performance (measured, the lead recommendation).** "icu4swift
   is architected to match **Foundation's Date/Calendar API model** —
   immutable value dates, high-level queries (`range`, `ordinality`,
   `dateInterval`, `nextDate`, `enumerateDates`), no ucal-style
   per-field mutation with eager recalculation.

   **At the calendar-math layer — the layer Stage 3 replaces inside
   `_CalendarICU`:** three-way measurement, matched methodology, 100k
   iterations, release mode:
   - **Arithmetic calendars**: icu4swift 9–26 ns, ICU4C direct
     250–330 ns, Foundation's public `Calendar` API ~1,100–1,200 ns.
     **10–40× faster than raw ICU4C.**
   - **Chinese** (baked HKO data): icu4swift **42 ns**, Foundation
     ~12,000 ns, ICU4C direct ~41,000 ns. **~1,000× faster than raw ICU4C.**

   The gap is **not** a clever optimization — ICU's per-field get/set
   contract forces full recomputation of every field on every access.
   That's the cost of ucal's shape. Foundation's public API doesn't
   require it, and we don't pay for it.

   **Scoping:** this is the calendar-math layer, *below* the
   Foundation.Date + TimeZone public-API dispatch. Three-zone
   end-to-end Gregorian round-trip (Date → Y/M/D/h/m/s/ns →
   Date), full public-API stack both sides:

   | Zone | icu4swift | Foundation | Ratio |
   |---|---:|---:|---:|
   | `TimeZone.gmt` (fast-path) | **118 ns** | 1,182 ns | **10×** |
   | `TimeZone(identifier: \"UTC\")` | 3,683 ns | 4,094 ns | 1.11× |
   | `America/Los_Angeles` (DST) | 5,022 ns | 5,449 ns | 1.09× |

   The difference is 100% TimeZone dispatch cost, not calendar
   math. `secondsFromGMT(for:)` costs ~15 ns on `_TimeZoneGMT`
   but ~547–810 ns on `_TimeZoneICU`, and we make two calls per
   assembly to detect DST transitions safely. Foundation's
   **internal** `TimeZone.rawAndDaylightSavingTimeOffset(for:)`
   does both in one call — but it's `internal` to swift-foundation,
   so outside consumers can't reach it. **Inside** swift-foundation
   our backend calls it directly, same as `_CalendarGregorian`
   does today — the 2-probe tax disappears, and the 10× fast-path
   win applies to every zone."

   See `BENCHMARK_RESULTS.md` for the full tables (calendar-math,
   end-to-end apples-to-apples, three-way with ICU4C direct). See
   `AdapterPerfInvestigation.md` for why the two-layer framing.

2. **Code size.** "Chinese calendar in icu4swift is ~600 lines of
   Swift. ICU's `chnsecal.cpp` + `astro.cpp` is around 4,000 lines of
   C++ driving 200 KB of object code."

3. **Correctness.** "Hebrew daily regression 1900–2100 against
   Hebcal: 73,414 dates, zero divergences."

Lead with **(1)** — it is measured, not asserted, and the
7–8× number lands harder than an abstract "faster" claim. Have **(3)**
ready in case they pivot to correctness concerns.

### Beat 4 — The soft ask (30–60 s)

Do not ask for a merge commitment. They cannot give one. Ask the
question they **can** answer today.

> "I'm not asking for anything today. I'd like to know three things:
> Is this a direction swift-foundation wants? If yes, what's the
> right way to propose it — forums thread, evolution doc, design PR?
> And who's the right person to run it by next?"

Three small questions. Each has a cheap answer. If the direction is
good, they will tell you. If it is not, they will tell you that too
— and that is also a win, because you saved yourself 18 months.

## What to bring

- **One link** — the `icu4swift` repo. Have it on screen or ready
  to paste.
- **One document as backup** — prepare a one-page summary they can
  skim **afterward**, not during. Lead with the numbers, not the
  architecture. `00-Overview.md` is close but a bit long; consider
  trimming.

**Do not bring:** slides, architecture diagrams, the full plan doc,
the four tracking docs. These are for *after* they say "tell me more."

## What to cut

- **Any "I think we should…"** — prescriptive. Replace with "I've
  built…" or "Would you want…".
- **The 4-stage roadmap.** Too much. If they ask how, answer:
  "Extend icu4swift first, then plumb behind a per-identifier router,
  then port calendar-by-calendar behind a parity gate. Each PR is
  scoped to one calendar and independently revertable."
- **The open-issues list.** Do **not** list risks unprompted. If they
  raise concerns (and they will), respond with the relevant issue
  from `OPEN_ISSUES.md`. That is also how you demonstrate you have
  thought about it without looking alarmist.
- **Baked data strategy, specific calendars, architectural details.**
  All tangential. Only pull into the conversation if asked.

## Anti-stranding rules

Three likely rabbit holes, and the one-sentence deflection for each:

| If they ask… | Say… |
|---|---|
| "How do you handle [specific calendar edge case]?" | "I'd rather agree on direction first — happy to go deep on any calendar in a follow-up." |
| "How would you prove no perf regression?" | "Three-level parity gate — per-PR, per-calendar port, per-release. Thresholds on CPU mean, P99, mallocs, throughput, peak memory. Baseline JSON checked into the repo, re-captured only on ICU / toolchain / hardware changes. Design in `05-PerformanceParityGate.md`, happy to walk through it." |
| "ICU handles this differently, are you sure you match?" | "Daily regression 1900–2100 against [authoritative source]. Zero divergences where I've measured. Known quirks I'd want to discuss case-by-case." |
| "What about Hindu lunisolar performance?" | "Slow tier — ~3,500 µs/date, fully astronomical, not yet baked. The 20 of 22 other calendars are sub-3 µs. Baking design for lunisolar is a documented backlog item." |
| "What about arithmetic calendars like Hebrew?" | "Foundation is 1.3–1.7× faster there today, both sides sub-3 µs. Swift micro-optimization headroom, not a design limit. Closeable with inlining and specialization work." |
| "Can I see your benchmark methodology?" | "Release mode, 100k iterations, warm-up excluded, checksum to prevent dead-code elimination, **no assertion macros in the timed loop** (applies to perf benchmarks only — normal correctness tests use `#expect` freely). Swift Testing's `#expect` costs ~1.5 µs per call, which dominated our own measurements before we caught it. See `05-PerformanceParityGate.md` for the formal spec and `BENCHMARK_RESULTS.md` § 'The #expect overhead finding' for the cautionary tale." |
| "Won't removing `ucal_*` break code that depends on its mutation/recompute semantics?" | "Foundation's public API doesn't expose those semantics. The clearest example: `Calendar.date(bySetting: .year, value: 2027, of: <Apr 21, 2026>)` returns Jan 1, 2027 — not April 21, 2027. It's a forward search via `enumerateDates`, not a `ucal_set` + reconcile. Has been since NSCalendar. `_CalendarICU` doesn't even route this method through ucal. Removing ucal's mutation contract from the implementation doesn't change anything visible at the Foundation surface. Full trace in `04-icu4swiftGrowthPlan.md` § 'Worked example: `date(bySetting:)` already diverges from `ucal_set`'." |

Each deflection is "yes I've thought about this, but not in the next
90 seconds."

## The hidden-value outcome

The most valuable outcome of the pitch is **not** them saying yes. It
is them telling you **what their biggest concern is.** If they say
"we can't take a calendar port because we're reworking TimeZone in
Q3," that is gold — that is 6 months of wasted work avoided. Leave
room for that by keeping your part tight.

## Pre-pitch checklist

- [ ] The 4 beats rehearsed — you can say each under time, without
      notes.
- [ ] The one proof point chosen in advance (and the backup in case
      the conversation pivots).
- [ ] `icu4swift` repo link accessible in one action.
- [ ] A trimmed one-page summary ready to send afterward.
- [ ] A one-line note to yourself: "Leave the last 60 seconds for
      them to talk."
