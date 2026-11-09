# Scripts behind the crescent data (no copyrighted content)

- `american_west_coast_generator.py` — builds the `americanWestCoast` table in `Sources/CalendarAstronomical/CrescentRules.swift`
  (westernmost mainland longitude per 0.05° latitude row) from Natural Earth 1:10m land, version 5.1.2 (public domain;
  download `ne_10m_land` from naturalearthdata.com). Needs Python with `shapefile` (pyshp) or `fiona`; see the script.
- `parse_moonsighting_announcements.py` — parses moonsighting.com's per-country "1st day" lists (Ramadan, Shawwal,
  Eid al-Adha pages, `<AHyear><rmd|shw|zhj>.html`) into `Tests/CalendarAstronomicalTests/announced_dates_2009_2026.csv`
  (plus a normalisation step for country names documented in `Docs/CRESCENT_RULES_RESULTS.md`, Round 7). The pages
  themselves are not in the repository; fetch them with plain curl (their robots.txt allows it) into a folder and pass it
  as the argument.
