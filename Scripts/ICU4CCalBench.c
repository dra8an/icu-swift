// ICU4C calendar round-trip benchmark — direct C API, no Swift wrapper.
//
// Mirrors Scripts/FoundationCalBench.swift but measures ICU4C's native
// calendar math without the Swift/ObjC Calendar wrapper that Foundation
// adds on top. Completes the three-way comparison:
//
//   icu4swift (our Swift math)
//   ICU4C direct (this benchmark — their C++ math via C API)
//   Foundation Calendar (their math + Swift/ObjC wrapper)
//
// Per iteration: ucal_setMillis → 5× ucal_get → ucal_clear → 5× ucal_set
// → ucal_getMillis, accumulating a checksum to prevent dead-code elimination.
//
// Compile on macOS with Homebrew ICU:
//   cc -O2 -o /tmp/icubench Scripts/ICU4CCalBench.c \
//      -I/usr/local/opt/icu4c@78/include \
//      -L/usr/local/opt/icu4c@78/lib \
//      -Wl,-rpath,/usr/local/opt/icu4c@78/lib \
//      -licui18n -licuuc
//
// Usage:
//   /tmp/icubench <identifier> [year] [iters]
//     identifier: gregorian, hebrew, chinese, coptic, persian, islamic,
//                 japanese, ... (anything ICU understands via @calendar=)
//     year:       Gregorian start year (default 2024)
//     iters:      iteration count (default 100000)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>

#include <unicode/ucal.h>
#include <unicode/utypes.h>

static uint64_t nsec_now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

static UCalendar* open_calendar(const char* identifier, UErrorCode* status) {
    // Build locale with calendar keyword: "en_US@calendar=<identifier>".
    char locale[96];
    snprintf(locale, sizeof(locale), "en_US@calendar=%s", identifier);
    // UTC timezone, same as the Foundation bench.
    UChar tz[] = { 'U', 'T', 'C', 0 };
    return ucal_open(tz, 3, locale, UCAL_DEFAULT, status);
}

int main(int argc, char** argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <identifier> [year] [iters]\n", argv[0]);
        return 1;
    }
    const char* identifier = argv[1];
    int start_year = (argc > 2) ? atoi(argv[2]) : 2024;
    int iters = (argc > 3) ? atoi(argv[3]) : 100000;

    UErrorCode status = U_ZERO_ERROR;

    // Open the target calendar.
    UCalendar* cal = open_calendar(identifier, &status);
    if (U_FAILURE(status) || cal == NULL) {
        fprintf(stderr, "ucal_open failed for %s: %s\n", identifier, u_errorName(status));
        return 2;
    }

    // Compute start date in milliseconds via a temporary Gregorian calendar.
    status = U_ZERO_ERROR;
    UChar tz[] = { 'U', 'T', 'C', 0 };
    UCalendar* gcal = ucal_open(tz, 3, "en_US", UCAL_GREGORIAN, &status);
    if (U_FAILURE(status) || gcal == NULL) {
        fprintf(stderr, "ucal_open (gregorian) failed: %s\n", u_errorName(status));
        ucal_close(cal);
        return 3;
    }
    ucal_clear(gcal);
    ucal_set(gcal, UCAL_YEAR, start_year);
    ucal_set(gcal, UCAL_MONTH, 0);   // January (0-indexed in ICU)
    ucal_set(gcal, UCAL_DATE, 1);
    ucal_set(gcal, UCAL_HOUR_OF_DAY, 0);
    ucal_set(gcal, UCAL_MINUTE, 0);
    ucal_set(gcal, UCAL_SECOND, 0);
    ucal_set(gcal, UCAL_MILLISECOND, 0);
    UDate start_millis = ucal_getMillis(gcal, &status);
    ucal_close(gcal);
    if (U_FAILURE(status)) {
        fprintf(stderr, "getMillis on start date failed: %s\n", u_errorName(status));
        ucal_close(cal);
        return 4;
    }

    // Pre-build date list so malloc/arithmetic is out of the timed region.
    // Use 1000-day window (i % 1000) to stay within any baked range.
    const double ms_per_day = 86400000.0;
    UDate* dates = (UDate*)malloc((size_t)iters * sizeof(UDate));
    if (!dates) {
        fprintf(stderr, "malloc failed\n");
        ucal_close(cal);
        return 5;
    }
    for (int i = 0; i < iters; i++) {
        dates[i] = start_millis + (double)(i % 1000) * ms_per_day;
    }

    // Warm-up pass (not timed).
    // Apples-to-apples with icu4swift/Foundation APPLES benches:
    // full Y/M/D/h/m/s/ns round-trip.
    int64_t checksum = 0;
    for (int i = 0; i < 100 && i < iters; i++) {
        status = U_ZERO_ERROR;
        ucal_setMillis(cal, dates[i], &status);
        int32_t era    = ucal_get(cal, UCAL_ERA, &status);
        int32_t year   = ucal_get(cal, UCAL_YEAR, &status);
        int32_t month  = ucal_get(cal, UCAL_MONTH, &status);
        int32_t day    = ucal_get(cal, UCAL_DATE, &status);
        int32_t hour   = ucal_get(cal, UCAL_HOUR_OF_DAY, &status);
        int32_t minute = ucal_get(cal, UCAL_MINUTE, &status);
        int32_t second = ucal_get(cal, UCAL_SECOND, &status);
        int32_t ms     = ucal_get(cal, UCAL_MILLISECOND, &status);
        int32_t leap   = ucal_get(cal, UCAL_IS_LEAP_MONTH, &status);
        ucal_clear(cal);
        ucal_set(cal, UCAL_ERA, era);
        ucal_set(cal, UCAL_YEAR, year);
        ucal_set(cal, UCAL_MONTH, month);
        ucal_set(cal, UCAL_DATE, day);
        ucal_set(cal, UCAL_HOUR_OF_DAY, hour);
        ucal_set(cal, UCAL_MINUTE, minute);
        ucal_set(cal, UCAL_SECOND, second);
        ucal_set(cal, UCAL_MILLISECOND, ms);
        if (leap) ucal_set(cal, UCAL_IS_LEAP_MONTH, leap);
        UDate back = ucal_getMillis(cal, &status);
        checksum += (int64_t)back ^ (int64_t)day;
    }

    // Timed loop — identical shape to warm-up.
    uint64_t t0 = nsec_now();
    for (int i = 0; i < iters; i++) {
        status = U_ZERO_ERROR;
        ucal_setMillis(cal, dates[i], &status);
        int32_t era    = ucal_get(cal, UCAL_ERA, &status);
        int32_t year   = ucal_get(cal, UCAL_YEAR, &status);
        int32_t month  = ucal_get(cal, UCAL_MONTH, &status);
        int32_t day    = ucal_get(cal, UCAL_DATE, &status);
        int32_t hour   = ucal_get(cal, UCAL_HOUR_OF_DAY, &status);
        int32_t minute = ucal_get(cal, UCAL_MINUTE, &status);
        int32_t second = ucal_get(cal, UCAL_SECOND, &status);
        int32_t ms     = ucal_get(cal, UCAL_MILLISECOND, &status);
        int32_t leap   = ucal_get(cal, UCAL_IS_LEAP_MONTH, &status);
        ucal_clear(cal);
        ucal_set(cal, UCAL_ERA, era);
        ucal_set(cal, UCAL_YEAR, year);
        ucal_set(cal, UCAL_MONTH, month);
        ucal_set(cal, UCAL_DATE, day);
        ucal_set(cal, UCAL_HOUR_OF_DAY, hour);
        ucal_set(cal, UCAL_MINUTE, minute);
        ucal_set(cal, UCAL_SECOND, second);
        ucal_set(cal, UCAL_MILLISECOND, ms);
        if (leap) ucal_set(cal, UCAL_IS_LEAP_MONTH, leap);
        UDate back = ucal_getMillis(cal, &status);
        checksum += (int64_t)back ^ (int64_t)day;
    }
    uint64_t t1 = nsec_now();

    double elapsed_ns = (double)(t1 - t0);
    double elapsed_ms = elapsed_ns / 1000000.0;
    double per_date_ns = elapsed_ns / (double)iters;

    printf("ICU4C %s (%d, %d iters): %.3f ms total, %.1f ns/date\n",
           identifier, start_year, iters, elapsed_ms, per_date_ns);
    printf("  checksum: %lld\n", (long long)checksum);

    ucal_close(cal);
    free(dates);
    return 0;
}
