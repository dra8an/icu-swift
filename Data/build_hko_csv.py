#!/usr/bin/env python3
"""Parse HKO T{YEAR}e.txt files in hko_raw/ and emit a Chinese-lunar-month CSV
matching the format of Tests/CalendarAstronomicalTests/chinese_months_1900_2050.csv:
    related_iso,month_number,is_leap,month_length,greg_year,greg_month,greg_day

A row represents one lunar month of Chinese year `related_iso`. The related_iso
year is the Gregorian year in which that lunar year's 1st month begins (i.e.
Chinese New Year). Leap is detected by two consecutive lines with the same
lunar month number in HKO data.
"""
import os, re, sys
from datetime import date

RAW_DIR = os.path.join(os.path.dirname(__file__), "hko_raw")
OUT = os.path.join(os.path.dirname(__file__), "chinese_months_1901_2100_hko.csv")

ORD = {"1st":1,"2nd":2,"3rd":3,"4th":4,"5th":5,"6th":6,"7th":7,"8th":8,
       "9th":9,"10th":10,"11th":11,"12th":12}

line_re = re.compile(r"^(\d{4})/(\d{1,2})/(\d{1,2})\s+(\w+)\s+Lunar [Mm]onth")

# Collect all month-start events across all files in Gregorian order.
events = []  # list of (date, month_num_from_hko)
for y in range(1901, 2101):
    path = os.path.join(RAW_DIR, f"T{y}e.txt")
    if not os.path.exists(path):
        continue
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = line_re.match(line)
            if not m:
                continue
            gy, gm, gd, ord_str = m.groups()
            if ord_str not in ORD:
                continue
            events.append((date(int(gy), int(gm), int(gd)), ORD[ord_str]))

# Sort & dedupe (in case of overlap across files — shouldn't happen but safe).
events.sort()
dedup = []
for e in events:
    if not dedup or dedup[-1][0] != e[0]:
        dedup.append(e)
events = dedup

# Walk events, building lunar months. Leap = same month number as previous event.
# Assign related_iso = greg year of the "month 1" event beginning the lunar year.
rows = []
current_related_iso = None
for i, (d, mnum) in enumerate(events):
    if mnum == 1 and (i == 0 or events[i-1][1] != 1):
        current_related_iso = d.year
    if current_related_iso is None:
        continue  # skip months before first observed CNY
    is_leap = 1 if (i > 0 and events[i-1][1] == mnum) else 0
    if i + 1 < len(events):
        length = (events[i+1][0] - d).days
    else:
        length = None  # can't determine — drop
    if length is None:
        continue
    rows.append((current_related_iso, mnum, is_leap, length, d.year, d.month, d.day))

# Only keep Chinese years fully covered: need both a "month 1" start AND the
# "month 1" start of the following year (to bound the final month length).
# Drop any trailing rows whose related_iso has no successor year-start.
years_with_successor = set()
prev_iso = None
for r in rows:
    if r[1] == 1 and r[2] == 0 and prev_iso is not None:
        years_with_successor.add(prev_iso)
    prev_iso = r[0]
rows = [r for r in rows if r[0] in years_with_successor]

with open(OUT, "w") as f:
    f.write("related_iso,month_number,is_leap,month_length,greg_year,greg_month,greg_day\n")
    for r in rows:
        f.write(",".join(str(x) for x in r) + "\n")

print(f"Wrote {len(rows)} rows covering {len(years_with_successor)} Chinese years -> {OUT}")
