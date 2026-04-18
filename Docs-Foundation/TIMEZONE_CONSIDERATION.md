# TimeZone & DST — How the Port Handles Them

*Created 2026-04-17. Anticipated concern from the `swift-foundation` team.*

A question this project should expect in every design review:
**"Are you addressing time zones and DST?"**

The answer is cleaner than people expect. This document captures both
the tight pitch-ready answer and the full reasoning, so the position
is consistent across conversations.

## The short answer (pitch-ready, 30–45 s)

> "TimeZone is out of scope. The TZ data layer — TZif parsing,
> historical transitions, identifier resolution — stays in
> Foundation's existing TimeZone infrastructure, untouched. What the
> calendar port does is the TZ-aware boundary: `(Date, TimeZone) →
> (RataDie, seconds-in-day)`, with DST transitions handled exactly
> like `_CalendarGregorian` already does today. The calendar math
> itself never sees DST. It only sees civil days."

Positions the concern as a solved pattern in Foundation that we
follow, not as a new risk.

## The full reasoning

### "TimeZone & DST" is actually four separate concerns

| Concern | Who owns it | In scope for this port? |
|---|---|---|
| TZ data (TZif files, historical transitions, identifier → offset) | Foundation's existing `TimeZone` layer | **Out of scope** — untouched |
| `(Date, TimeZone) → (RataDie, secondsInDay)` adapter | Calendar backend | **In scope** — must port |
| DST-aware `nextDate(after:matching:)` with `matchingPolicy`, `repeatedTimePolicy` | Calendar enumeration | **In scope** — must port |
| Week/year boundaries that cross midnight in local time | Calendar math inside a fixed TZ | **In scope, trivially** — civil-day math is unaffected |

The first row — the data layer — is what most people mean when they
say "time zones." We do not touch it. Our calendars consume whatever
`TimeZone` Foundation ships.

### Why the pattern works

- Foundation's `Date` is absolute: seconds since reference, UTC. No
  TZ baked in.
- Every calendar operation takes a `Date` and uses the calendar's
  configured `TimeZone` to produce wall-clock components.
- Adding the TZ offset to the `Date` and flooring to day gives you
  `RataDie`. The remainder gives `secondsInDay` for H/M/S/ns.
- DST transitions change the length of specific civil days (23 or 25
  hours). The adapter handles that by asking Foundation's `TimeZone`
  what offset applies at a given `Date`. The calendar itself never
  sees the irregularity.

See also `MigrationIssues.md` § "Time-of-day resolution" — the
RataDie-based model already accepts sub-day precision via
`secondsInDay` at the boundary. DST is the same boundary concern,
with a different source of irregularity.

### Existence proof

`_CalendarGregorian` (in `swift-foundation/Sources/FoundationEssentials/
Calendar/Calendar_Gregorian.swift`) already implements exactly this
pattern — pure Swift, TZ-aware, DST-aware, no ICU calls. Every other
calendar follows the same adapter shape. We are not inventing a new
approach; we are applying a known-working one.

## Anticipated follow-ups

Short answers for every DST/TZ rabbit hole worth anticipating:

| If they ask… | Answer |
|---|---|
| "Spring-forward: `date(from: DateComponents(hour: 2, minute: 30))` on transition day?" | "Same `matchingPolicy` semantics as today — `.nextTime` rolls forward, `.strict` returns `nil`. Port the existing behavior." |
| "Fall-back: which 1:30 AM wins?" | "`repeatedTimePolicy` — `.first` or `.last`. Foundation already distinguishes; we just respect the parameter." |
| "What about TZ changes mid-enumeration in `nextDate`?" | "The calendar holds a single `TimeZone` for the operation, same as `_CalendarICU`. TZ changes are the user's responsibility via a new calendar value." |
| "Historical TZ rules (pre-1970, political changes)?" | "Foundation's TZ layer handles that. We just ask it for the offset at a `Date`. Our calendar math is identical regardless." |
| "Leap seconds?" | "Foundation doesn't expose them. ICU doesn't resolve them at the calendar layer either. Non-issue." |
| "TZ swap inside `dateComponents(_:from:in:)`?" | "The in-scope variant temporarily reassigns the calendar's TZ. We port that behavior one-for-one in the adapter — it is small and well-defined." |
| "DST-related regressions are notoriously subtle. How do you catch them?" | "Per-calendar daily regression 1900–2100 against `_CalendarICU` includes every DST transition in every exercised TZ. Zero-divergence bar surfaces anything." |
| "Does every calendar identifier honor DST correctly?" | "DST is orthogonal to the calendar system — it is a property of the TZ, not the calendar. The adapter is shared across all identifiers." |

Each answer is one to two sentences. "Yes we have thought about this,
but not in the next 90 seconds."

## What this means for the port

Concretely, for Stage 1 (extend icu4swift):

1. Add a stored `timeZone: TimeZone` property to each calendar struct,
   matching `_CalendarProtocol`'s contract.
2. Add the `(Date, TimeZone) → (RataDie, secondsInDay)` adapter,
   translating `Date` inputs for every `_CalendarProtocol` method
   that takes one.
3. Porting `nextDate(after:matching:)` and `enumerateDates(…)`
   requires DST-aware logic. That is a non-trivial piece of Stage 1
   — tracked under `OPEN_ISSUES.md` Issue 3.

For Stages 2–4, TZ handling is already in scope via the Stage 1
adapter; no additional TZ work per calendar. Per-calendar work is
purely the Y/M/D/era/week math.

## What is explicitly **not** in scope

- Re-implementing TZif parsing.
- Re-implementing historical transition databases.
- Replacing `TimeZone_ICU.swift` or `_TimeZoneGMTICU.swift`.
- Adding leap-second support.
- Changing how `TimeZone.current` resolves.

If any of those become relevant during the port, they are a separate
project.

## See also

- `MigrationIssues.md` — the RataDie vs. millisecond discussion; the
  same adapter pattern applies.
- `00-Overview.md` § "Scope" — explicit out-of-scope list.
- `OPEN_ISSUES.md` Issue 3 — `nextDate`/`enumerateDates` and its
  DST-awareness requirements.
- `PITCH.md` § "Anti-stranding rules" — how to keep this topic from
  eating a 3-to-5-minute pitch.
