// CompareDateFromComponents.c
//
// Empirical test of what raw ICU4C does for the equivalent of
//   Calendar.date(from: DateComponents(year: 2026, day: 21))
//
// Companion to Scripts/CompareDateFromComponents.swift, which exercises the
// same input through Foundation's high-level Calendar API. Run both and
// compare the outputs to settle:
//
//   - What state is a UCalendar* in immediately after ucal_open?
//   - What state does ucal_clear leave it in?
//   - With ucal_clear + only YEAR + DAY set, what month/time does ucal_getMillis
//     pick? Epoch defaults? Calendar-default? Something else?
//   - Are Foundation's explicit defaults (YEAR=1 MONTH=0 DAY=1 ...)
//     load-bearing or belt-and-suspenders?
//
// Compile (Apple Silicon, Homebrew ICU4C 77):
//   cc -O2 -o /tmp/cmpdate Scripts/CompareDateFromComponents.c \
//      -I/opt/homebrew/opt/icu4c/include \
//      -L/opt/homebrew/opt/icu4c/lib \
//      -Wl,-rpath,/opt/homebrew/opt/icu4c/lib \
//      -licui18n -licuuc
//   /tmp/cmpdate

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include <unicode/ucal.h>
#include <unicode/utypes.h>
#include <unicode/ustring.h>

static const UChar UTC[] = {'U','T','C',0};

static void format_udate(UDate millis, char *out, size_t outsz) {
    // Decompose the resulting UDate via a *fresh* UTC Gregorian calendar so the
    // formatting is independent of whatever state the test calendar is in.
    UErrorCode ec = U_ZERO_ERROR;
    UCalendar *fmt = ucal_open(UTC, -1, "en_US@calendar=gregorian",
                               UCAL_GREGORIAN, &ec);
    if (U_FAILURE(ec)) { snprintf(out, outsz, "<open failed: %s>", u_errorName(ec)); return; }
    ucal_setMillis(fmt, millis, &ec);
    int32_t y = ucal_get(fmt, UCAL_YEAR, &ec);
    int32_t m = ucal_get(fmt, UCAL_MONTH, &ec) + 1;  // ICU is 0-indexed
    int32_t d = ucal_get(fmt, UCAL_DATE, &ec);
    int32_t h = ucal_get(fmt, UCAL_HOUR_OF_DAY, &ec);
    int32_t mn = ucal_get(fmt, UCAL_MINUTE, &ec);
    int32_t s = ucal_get(fmt, UCAL_SECOND, &ec);
    int32_t ms = ucal_get(fmt, UCAL_MILLISECOND, &ec);
    int32_t era = ucal_get(fmt, UCAL_ERA, &ec);
    snprintf(out, outsz, "%04d-%02d-%02d %02d:%02d:%02d.%03d UTC (era=%d)  raw=%.0f ms",
             y, m, d, h, mn, s, ms, era, (double)millis);
    ucal_close(fmt);
}

static void run(const char *label, void (*setup)(UCalendar *)) {
    UErrorCode ec = U_ZERO_ERROR;
    UCalendar *cal = ucal_open(UTC, -1, "en_US@calendar=gregorian",
                               UCAL_GREGORIAN, &ec);
    if (U_FAILURE(ec)) { printf("%-60s open failed: %s\n", label, u_errorName(ec)); return; }
    setup(cal);
    ec = U_ZERO_ERROR;
    UDate result = ucal_getMillis(cal, &ec);
    if (U_FAILURE(ec)) { printf("%-60s getMillis failed: %s\n", label, u_errorName(ec)); ucal_close(cal); return; }
    char buf[256];
    format_udate(result, buf, sizeof(buf));
    printf("%-60s %s\n", label, buf);
    ucal_close(cal);
}

// --- Setup variants ---------------------------------------------------------

// Scenario A: ucal_open only — no clear, no sets. What does a fresh handle hold?
static void setup_A(UCalendar *cal) {
    (void)cal;
}

// Scenario B: ucal_open + ucal_set(YEAR=2026), ucal_set(DAY=21). NO clear.
// Tests whether ICU keeps the open-time state for unset fields.
static void setup_B(UCalendar *cal) {
    ucal_set(cal, UCAL_YEAR, 2026);
    ucal_set(cal, UCAL_DATE, 21);
}

// Scenario C: ucal_open + ucal_clear only. What does clear leave?
static void setup_C(UCalendar *cal) {
    ucal_clear(cal);
}

// Scenario D: ucal_open + ucal_clear + set YEAR=2026 + set DAY=21.
// The "raw" version of what Foundation does, minus the explicit defaults.
static void setup_D(UCalendar *cal) {
    ucal_clear(cal);
    ucal_set(cal, UCAL_YEAR, 2026);
    ucal_set(cal, UCAL_DATE, 21);
}

// Scenario E: full Foundation-style. clear + explicit defaults + user values.
// Should be the deterministic Jan 21, 2026 00:00:00.000 UTC result.
static void setup_E(UCalendar *cal) {
    ucal_clear(cal);
    ucal_set(cal, UCAL_YEAR, 1);
    ucal_set(cal, UCAL_MONTH, 0);              // January (0-indexed)
    ucal_set(cal, UCAL_DAY_OF_MONTH, 1);
    ucal_set(cal, UCAL_HOUR_OF_DAY, 0);
    ucal_set(cal, UCAL_MINUTE, 0);
    ucal_set(cal, UCAL_SECOND, 0);
    ucal_set(cal, UCAL_MILLISECOND, 0);
    ucal_set(cal, UCAL_YEAR, 2026);            // user's value
    ucal_set(cal, UCAL_DAY_OF_MONTH, 21);      // user's value
}

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    printf("Input:  DateComponents(year: 2026, day: 21)  (TZ = UTC, calendar = gregorian)\n");
    printf("Format: <yyyy-MM-dd HH:mm:ss.SSS UTC (era=N)  raw=<millis since epoch>>\n\n");
    run("A) open only (no clear, no set)",                        setup_A);
    run("B) open + set(YEAR=2026, DAY=21)  [NO clear]",           setup_B);
    run("C) open + clear (no sets at all)",                       setup_C);
    run("D) open + clear + set(YEAR=2026, DAY=21)",               setup_D);
    run("E) open + clear + Foundation defaults + (YEAR, DAY)",    setup_E);
    return 0;
}
