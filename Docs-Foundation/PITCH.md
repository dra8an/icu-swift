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

### Beat 3 — One proof point (60–90 s)

**Pick exactly one.** Do not tour all 23 calendars. Pick the single
example with the most "wow" per word. Options, in order of impact
for a Foundation engineer:

1. **Performance (measured, the lead recommendation).** "Chinese
   calendar: icu4swift **1.9 µs/date** vs Foundation's **~12 µs/date**
   — **6–7× faster** in the baked range, still 1.7–12× faster on
   realistic spans outside it. Structural win from baked data
   versus ICU's runtime astronomy.
   
   *Be honest:* on arithmetic calendars — Hebrew, Persian, Coptic,
   Indian — Foundation is currently 1.3–1.7× faster, both sides
   under 3 µs. That's Swift micro-optimization headroom, not a
   design limit. Closeable with targeted work."
   
   See `BENCHMARK_RESULTS.md` for full tables. **Disclose the
   arithmetic gap unprompted** — over-claiming a blanket "faster"
   will not survive scrutiny.

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
| "How would you prove no perf regression?" | "Per-calendar benchmarks capturing the ICU baseline before the port, locked thresholds, parity-or-revert per PR. I have a design doc ready." |
| "ICU handles this differently, are you sure you match?" | "Daily regression 1900–2100 against [authoritative source]. Zero divergences where I've measured. Known quirks I'd want to discuss case-by-case." |
| "What about Hindu lunisolar performance?" | "Slow tier — ~3,500 µs/date, fully astronomical, not yet baked. The 20 of 22 other calendars are sub-3 µs. Baking design for lunisolar is a documented backlog item." |
| "What about arithmetic calendars like Hebrew?" | "Foundation is 1.3–1.7× faster there today, both sides sub-3 µs. Swift micro-optimization headroom, not a design limit. Closeable with inlining and specialization work." |

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
