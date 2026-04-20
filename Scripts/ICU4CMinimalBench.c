// Minimal ICU4C calendar benchmark — diagnostic companion to ICU4CCalBench.c.
//
// Hot loop is JUST `ucal_setMillis`. No field get/set, no round-trip.
// Isolates the per-iteration cost of ucal's state-machine setup from the
// field-by-field get/set overhead measured by the full round-trip bench.
//
// Caveat: ICU is lazy — `ucal_setMillis` typically just stores the time
// and marks fields as invalid; actual field resolution happens on the
// first `ucal_get`. So this measures the setup cost only, not the
// field-compute cost.
//
// Compile:
//   cc -O2 -o /tmp/icubench_min Scripts/ICU4CMinimalBench.c \
//      -I/usr/local/opt/icu4c@78/include \
//      -L/usr/local/opt/icu4c@78/lib \
//      -Wl,-rpath,/usr/local/opt/icu4c@78/lib \
//      -licui18n -licuuc
//
// Usage:
//   /tmp/icubench_min <identifier> [year] [iters]

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
    char locale[96];
    snprintf(locale, sizeof(locale), "en_US@calendar=%s", identifier);
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

    UCalendar* cal = open_calendar(identifier, &status);
    if (U_FAILURE(status) || cal == NULL) {
        fprintf(stderr, "ucal_open failed for %s: %s\n", identifier, u_errorName(status));
        return 2;
    }

    // Compute start millis via a temporary Gregorian calendar.
    status = U_ZERO_ERROR;
    UChar tz[] = { 'U', 'T', 'C', 0 };
    UCalendar* gcal = ucal_open(tz, 3, "en_US", UCAL_GREGORIAN, &status);
    ucal_clear(gcal);
    ucal_set(gcal, UCAL_YEAR, start_year);
    ucal_set(gcal, UCAL_MONTH, 0);
    ucal_set(gcal, UCAL_DATE, 1);
    ucal_set(gcal, UCAL_HOUR_OF_DAY, 0);
    ucal_set(gcal, UCAL_MINUTE, 0);
    ucal_set(gcal, UCAL_SECOND, 0);
    ucal_set(gcal, UCAL_MILLISECOND, 0);
    UDate start_millis = ucal_getMillis(gcal, &status);
    ucal_close(gcal);

    // Pre-build date list.
    const double ms_per_day = 86400000.0;
    UDate* dates = (UDate*)malloc((size_t)iters * sizeof(UDate));
    for (int i = 0; i < iters; i++) {
        dates[i] = start_millis + (double)(i % 1000) * ms_per_day;
    }

    // Warm-up.
    for (int i = 0; i < 100 && i < iters; i++) {
        status = U_ZERO_ERROR;
        ucal_setMillis(cal, dates[i], &status);
    }

    // Timed loop — ONLY ucal_setMillis.
    uint64_t t0 = nsec_now();
    for (int i = 0; i < iters; i++) {
        status = U_ZERO_ERROR;
        ucal_setMillis(cal, dates[i], &status);
    }
    uint64_t t1 = nsec_now();

    double elapsed_ns = (double)(t1 - t0);
    double per_date_ns = elapsed_ns / (double)iters;
    printf("ICU4C %s setMillis-only (%d, %d iters): %.3f ms total, %.1f ns/call\n",
           identifier, start_year, iters, elapsed_ns / 1000000.0, per_date_ns);

    ucal_close(cal);
    free(dates);
    return 0;
}
