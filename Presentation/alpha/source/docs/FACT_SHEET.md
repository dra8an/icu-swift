# Fact sheet for the Islamic calendars presentation

Rule: nothing goes on a slide unless it is in this sheet with a source. Version 4, 2026-11-12: local material, the
web checks of 11 and 12 November (East London Mosque's method added in section 3), and our engine's numbers for every place (section 1b).

Where a fact comes from: **official** = the authority's own text; **press** = a news report (often quoting the
authority); **other** = another secondary source; **ours** = computed by our own astronomy engine (committed file
`Tests/CalendarAstronomicalTests/crescent_astronomy_fixture.csv`). How it was checked: **read** = the page or file was
read at the source; **headline** = only the official headline was readable; **summary** = seen in a search summary
only. Status: **ready** = may go on a slide; **notes** = good enough for speaker notes, say where it comes from;
**no** = do not use.

## 1. The evening the story stands on: Tuesday 17 February 2026

| Fact | Value | From | Status |
|---|---|---|---|
| New moon (the moon passes the sun) | 17 Feb 2026, 12:01 UTC | ours (12:01:09); Diyanet prints 12:01 (official); Pakistan's space agency: 5:01 pm Pakistan time, the same moment (press, summary) | ready |
| That new moon was a solar eclipse | annular ("ring of fire"); the ring was visible from Antarctica, a partial eclipse from Argentina, Chile and southern Africa; greatest at 12:12 UT | official, NASA (`eclipse.gsfc.nasa.gov/OH/OH2026.html`, `…/SEdecade/SEdecade2021.html`), summary | ready |
| It was day 29 of Sha'ban for Türkiye, Saudi Arabia, Malaysia, Egypt | their Sha'ban began on Tue 20 Jan 2026 | official, read (our round-1 notes: Diyanet's 2026 list; Umm al-Qura table p.176; JAKIM takwim 2026; Dar al-Ifta 10915) | ready |
| … for Saudi Arabia, in the court's words | the Supreme Court called for the crescent to be looked for "tomorrow evening, Tuesday the twenty-ninth of Sha'ban" | official, headline (`spa.gov.sa/N2513476`, Arabic) | ready |
| … for Malaysia | 17 Feb was 29 Syaaban 1447 | press (RTM, the state broadcaster), read | ready |
| … for Singapore | the mufti's announcement is dated 17 Feb 2026 and speaks of "sunset this evening" | official, read | ready |
| … for Indonesia | the ministry's decision session was on Tue 17 Feb 2026, "29 Syaban 1447" | press (CNN Indonesia and others), summary | ready |
| **Not** day 29 for Morocco, Pakistan, and part of Britain | their Sha'ban began on Wed 21 Jan, so their day 29 was Wed 18 Feb | see section 2 | ready |
| Mecca: sunset | 18:19 local (15:19 UTC) | ours | ready |
| Mecca: moonset | 18:23 local, **3.2 minutes after the sun** | ours | ready |
| Mecca: the moon's age at sunset | 3 hours 18 minutes | ours | ready |
| Mecca: the moon at sunset | 0.4° above the horizon as seen, 1.8° from the sun | ours | ready |
| Singapore at sunset | "the moon set 4 minutes earlier than the sun" | official, read (MUIS, 17 Feb 2026) | ready |
| At Greenwich midnight, the best place on the sunset line | moon 4.5° high and 6.1° from the sun; Türkiye asks for 5° and 8° | ours | ready |
| The moment Türkiye's two numbers were first met anywhere | 18 Feb 2026, 03:42 UTC, 3 h 42 min after the deadline | ours (03:42:04); Diyanet prints 03:42 on its own map (official; the time is a fact, the map stays off the slides) | ready |
| Stops on the sunset's way, for the film (evening of 17 Feb, each at its own sunset; height as seen, then distance from the sun) | New York 22:33 UTC: 3.3°, 5.4°. Los Angeles 01:39 UTC on the 18th: 5.05°, 6.95° (high enough, not far enough). The first place, 4°N 142°W, 03:42: 6.06°, 8.00° (both met). The tip of the Alaska Peninsula, 04:06: **4.96°**, 8.20° (far enough, a hair too low). | ours (`engine/out/places.csv`, which now also holds the sun's and the moon's directions at each sunset; `series.csv` holds the moon's distance from the sun every five minutes) | ready. The 4.96° is now printed by the engine, no longer inferred |
| Where Türkiye's two numbers were first met | about 4°N 142°W, open Pacific south-east of Hawaii, at the 03:42 sunset (the earliest sunset among the grid's qualifying points; the grid has one point per degree, so the place is good to about a degree) | ours (`art/globe.py` from `engine/out/grid.csv`) | ready, worded "open ocean, south-east of Hawaii" |
| The sun on the globe picture | not from a formula: fitted to the engine's own 03:42 sunset line (declination −11.6°, misfit 0.05°) | ours | background only |
| Could anyone see it on the 17th? | "On February 17, the moon cannot be seen anywhere in the world." | other, read (moonsighting.com, page for Ramadan 1447) | notes, as that site's statement |
| The same point in the press | a report headed "Impossible Moon: Saudi Arabia Faces Scrutiny After Declaring Wednesday as 1st Day of Ramadan" | press, headline only (Morocco World News, Feb 2026) | notes, if a second voice is wanted |
| Could anyone see it on the 18th and 19th? | "On February 18, it can be seen easily from India westward everywhere. On February 19, it can be seen easily in the whole world." | other, read (same page) | notes, as that site's statement |
| What the Saudi court asks of a witness | anyone who sees the crescent is to tell the nearest court and have the testimony recorded | official (Saudi Press Agency item), summary only | notes |
| Tuas, in degrees (−1.8° high, 1.3° from the sun) | in our round-1 notes as MUIS's figures; **not** on the announcement page | not found again | no; use the "4 minutes" sentence |

## 1b. Sunset by sunset, from our engine (computed 2026-11-12)

Made by `engine/` (a small program that calls `CrescentRules.evening`, the call behind the committed tests); raw output
in `engine/out/places.csv`. Two checks: the Mecca row equals the committed fixture to the second, and the Singapore row
(moon down 4.1 minutes before the sun) agrees with the mufti's "4 minutes earlier". New moon: 17 Feb 2026, 12:01:09 UTC.
All of this is **ours** and **ready**.

Evening of Tuesday 17 February:

| Place | Sunset (local, UTC) | Moon's age at sunset | Moon sets | Moon at sunset: height as seen, distance from the sun |
|---|---|---|---|---|
| Singapore (Tuas) | 19:21, 11:21 | **not new yet: 40 min to go** | 4.1 min **before** the sun | below the horizon; 1.0° |
| Malaysia (Pulau Perak) | 19:36, 11:36 | not new yet: 24 min to go | 3.9 min before | below; 1.0° |
| Kuala Lumpur | 19:27, 11:27 | not new yet: 33 min to go | 4.0 min before | below; 1.0° |
| Indonesia (Banda Aceh) | 18:51, 11:51 | not new yet: 10 min to go | 3.4 min before | below; 0.9° |
| Jakarta | 18:15, 11:15 | not new yet: 46 min to go | 3.7 min before | below; 1.0° |
| Peshawar | 17:59, 12:59 | 58 min | 3.6 min before | below; 1.0° |
| Mecca (Kaaba) | 18:19, 15:19 | 3 h 18 min | 3.2 min **after** | 0.4°; 1.8° |
| Cairo | 17:45, 15:45 | 3 h 44 min | 3.8 min after | 0.4°; 2.0° |
| Istanbul | 18:40, 15:40 | 3 h 40 min | 2.9 min after | 0.2°; 2.0° |
| London | 17:19, 17:19 | 5 h 18 min | 6.9 min after | 0.6°; 2.8° |
| Rabat | 18:13 UTC | 6 h 12 min | 10.1 min after | 1.5°; 3.2° |

Evening of Wednesday 18 February (day 29 for Morocco, Pakistan and Wifaqul Ulama in Britain):

| Place | Sunset (UTC) | Moon's age | Moon sets after the sun by | Height as seen, distance from the sun |
|---|---|---|---|---|
| Peshawar | 13:00 | 25 h | 59 min | 10.8°; 12.8° |
| Mecca | 15:20 | 27 h | 59 min | 12.3°; 14.0° |
| London | 17:21 | 29 h | 86 min | 11.3°; 15.1° |
| Rabat | 18:14 | 30 h | 73 min | 13.5°; 15.5° |
| Singapore | 11:22 | 23 h | 43 min | 9.5°; 12.0° |

Rabat's local clock time is left out on purpose: Morocco changes its clocks around Ramadan and the offset for these
two days was not checked. "Distance from the sun" is the angle between the centres of moon and sun seen from the
Earth's centre (the number Türkiye's rule uses).

## 2. First day of Ramadan 1447, and how each got there

| Who | First day | How | From | Status |
|---|---|---|---|---|
| Türkiye (Diyanet) | Thu 19 Feb | calculated years ahead | official, read (`vakithesaplama.diyanet.gov.tr/dinigunler.php?yil=2026`) | ready |
| Saudi Arabia, the printed Umm al-Qura calendar | Wed 18 Feb | calculated | official, read (scan of the printed calendar, p.177) | ready |
| Saudi Arabia, announced | Wed 18 Feb | "Royal Court: Ramadan Begins in Saudi Arabia Tomorrow, February 18, 2026" | official, headline (`spa.gov.sa/en/N2516805`) | ready |
| Saudi Arabia, the reason given | the court accepted a reported sighting on the evening of the 17th (one report names an observatory at Tumair) | press, summary (New Arab, Gulf News, Yahoo News UK); the court's own text was not readable (the agency's pages return only their headline) | notes |
| UAE, Qatar, Kuwait, Bahrain | Wed 18 Feb | announced the same evening | press, summary (Gulf News, New Arab) | notes |
| Malaysia | Thu 19 Feb | watched from 29 places on the evening of the 17th; announced by the Keeper of the Rulers' Seal, Tan Sri Syed Danial Syed Ahmad; set by order of the Yang di-Pertuan Agong with the Rulers' consent. The item does not say whether the crescent was seen. | press (RTM), read (`berita.rtm.gov.my/…/umat-islam-di-malaysia-mula-berpuasa-pada-khamis/`) | ready |
| Indonesia, the government | Thu 19 Feb | decision session on the 17th; the crescent did not meet 3° and 6.4° | official, read in round 1 (`aceh.kemenag.go.id/baca/pemerintah-tetapkan-1-ramadan-1447-h-jatuh-pada-19-februari-2026`) | ready |
| Indonesia, Muhammadiyah (a large organisation) | Wed 18 Feb | its own worldwide calculated calendar (KHGT); announced in October 2025 by its central board (Maklumat 2/MLM/I.0/E/2025): "di seluruh dunia tanggal 1 Ramadan 1447 H jatuh pada hari Rabu Legi, 18 Februari 2026 M" | official (`muhammadiyah.or.id/2025/10/maklumat-pp-muhammadiyah-tentang-penetapan-hasil-hisab-ramadan-syawal-dan-zulhijah-1447-h/`), summary | ready for the date; read the page before quoting it |
| **Muhammadiyah and Türkiye use the same rule** | Wed against Thu | Muhammadiyah's calendar asks what Türkiye asks (the 2016 Istanbul criteria): 5° high and 8° from the sun somewhere before midnight in Greenwich, or else on the American mainland with the new moon before dawn in New Zealand. Its expert, Arwin Juli Rakhmadi Butar-Butar: the first part was "belum terpenuhi" (not met) anywhere; the second part "telah terpenuhi" (was met) on the Alaska Peninsula, at 56°48′49″N 158°51′44″W and at Chevak, Tununak, Hooper Bay, Togiak, Kipnuk and Port Heiden. He says Türkiye's Thursday comes from not counting the Aleutian and Fox Islands, and calls it "perbedaan analisis ilmiah terhadap penerapan kriteria yang sama" (a difference in scientific analysis in applying the same criteria). | official for Muhammadiyah's side, **read** (`muhammadiyah.or.id/2026/01/pakar-ilmu-falak-muhammadiyah-jelaskan-alasan-1-ramadan-1447-h-jatuh-pada-18-februari-2026/`, 7 Jan 2026); Türkiye's date official. What Türkiye itself says about its reason was **not** found; the reason above is Muhammadiyah's account of it. | ready, worded as "Muhammadiyah says" |
| … and our engine on that Alaska test | Along the west coast of the American mainland (one point every 0.05° of latitude), the best point at its own sunset was the tip of the Alaska Peninsula, 54.85°N 163.38°W, sunset 04:05 UTC on the 18th. The moon was far enough from the sun (past 8°) but about 4.96° high as seen, against the 5° asked: **short by 0.04°**. | ours; the definition was read in the code on 2026-11-12 (`CrescentDiyanetProbe.swift`, the fixture export: the largest value of the smaller of "distance − 8°" and "height as seen − 5°"). The 4.96° is inferred from the margin and the time, not printed by the engine. | ready, with this caution said aloud: 0.04° is less than any calculation can honestly settle (the bending of light near the horizon alone changes more than that with the weather). Say "within a hair of the line", not "missed". |
| Singapore (MUIS) | Thu 19 Feb | "According to astronomical calculations…"; signed by the Mufti, Dr Nazirudin Mohd Nasir | official, read (`muis.gov.sg/resources/media-releases/announcement-by-mufti-for-the-month-of-ramadan-1447h-2026-for-singapore/`) | ready |
| Egypt (Dar al-Ifta) | Thu 19 Feb | not sighted on the evening of the 17th, so Sha'ban got a 30th day | official, read in round 1 (`dar-alifta.org/ar/Articles/Details/11039`) | ready |
| Egypt's printed Survey Authority calendar | Wed 18 Feb | calculated | seen once in round 1, could not be re-opened | no |
| Oman | Thu 19 Feb | announced in advance: the calculation showed the crescent could not be seen on Tuesday | press, summary (Gulf News, citing the Oman News Agency) | notes |
| Morocco | Thu 19 Feb | Sha'ban began Wed 21 Jan; the Ministry of Endowments and Islamic Affairs had the crescent watched on the evening of Wed 18 Feb, 29 Sha'ban, and confirmed it seen | press, summary (Yabiladi, Morocco World News, quoting the ministry) | ready as "the ministry announced"; notes for detail |
| Pakistan | Thu 19 Feb | the Central Ruet-e-Hilal Committee met in Peshawar on Wed 18 Feb; its chairman announced the crescent seen, on testimonies from several cities | press, summary (Business Recorder; Radio Pakistan for the meeting date) | same |
| India, Bangladesh | Thu 19 Feb | sightings on the evening of the 18th | press, summary | notes |
| How Morocco decides | by the naked eye: the ministry collects reports from about 270 observation points and from army units; reports are checked against astronomical calculation, which does not replace them | press and one enthusiast FAQ, summary (Morocco World News 2024 and 2026; moonsighting.org.uk) | notes. **Do not say "only looks"; say "witnesses decide"** |
| How Pakistan decides | zonal committees collect witnesses' testimonies, the central committee judges them; the weather office and the space agency advise | press, Wikipedia and a paper in the weather office's journal, summary | notes; same wording |
| Iraq | Sunni authorities 18 Feb, Shia authorities 19 Feb | | press, summary, one source | no, unless read at a source |

## 3. Britain, the same Ramadan (the "no central authority" slide)

| Fact | From | Status |
|---|---|---|
| East London Mosque, published 17 Feb 2026: "1 Ramadan 1447 is on Wednesday 18 February 2026." "The first Tarawih prayers will be on the evening of Tuesday 17 February." It gives no reason. | official (the mosque's own site), read (`eastlondonmosque.org.uk/news/start-of-ramadan-2026`) | ready |
| **How East London Mosque sets its dates** (asked by the user, 2026-11-12). Its page on prayer times and the calendar: "we currently use the Umm al-Qura Islamic calendar"; "For key Islamic dates, such as the start of Ramadān ... we wait for news of the sighting of the new crescent moon, then post this on the front page of our website"; "any calendar may be off by a day, depending on when the new crescent moon is actually sighted." **It does not say whose sighting news it waits for.** | official, read (`eastlondonmosque.org.uk/prayer-times-and-calendar-explained`, updated 3 July 2026) | ready. Say what it says; do **not** say "follows Saudi Arabia": no source states that |
| Earlier years on the same site: 2017, "The Coordination Committee of Major Islamic Centres and Mosques of London have agreed that 1st Ramadan 1438 will be on Saturday 27th May 2017"; 2022, "if we receive confirmation that Ramadan has started" (source of the confirmation not named) | official, read (two announcement pages) | notes; shows a London committee was the route in 2017 |
| Whether that committee states whose sighting it follows | not found: one search turned up no statement by the committee; a Croydon mosque's pamphlet argues against "following Saudi Arabia" but is a polemic | none | no |
| Wifaqul Ulama (Britain): "The first day of Ramadān will be Thursday 19th February 2026." Local sighting report: negative. Foreign sighting report: positive. | official (its own site), read (`wifaqululama.co.uk/1447-2/`) | ready |
| Wifaqul Ulama's Sha'ban began on Wed 21 Jan 2026 (nothing seen at home or abroad the evening before), so its day 29 was Wed 18 Feb, not the 17th | same page, read | ready |
| It decides by "Moonsighting in UK (primary) and Morocco (secondary)" and consults the Batley Moon Sighting Committee | same page, read | ready |
| A Birmingham mosque (Green Lane) began after sunset on the 17th "in line with Saudi moonsighting"; the wider community was to look on Wednesday evening | press, summary (Yahoo News UK) | notes |
| The European Council for Fatwa and Research gave 19 Feb | press, summary, one source | no, unless read at a source |
| It was not the first time. Ramadan 2019: "UK [Coordinated by Major Islamic Centres of London]" Monday 6 May; "UK [Wifaaqul ulama] (Sighting from countries east of UK)" Tuesday 7 May; Wifaqul Ulama: "Moon was not sighted anywhere in Britain or anywhere East of UK." | other, read (moonsighting.com's page for Ramadan 1440; our data row checked against the saved page) | notes, as "one compilation records" |
| The same file shows a split for Eid al-Fitr 2011 and 2013 and Eid al-Adha 2019 | other; these rows were not re-checked | no |

## 4. What each calculating authority asks on day 29

From our guide `Docs/Islamic_Crescent_Calendars.md` (swift-foundation-islamic), which rests on the round-1 research.

| Authority | Where it looks | What it asks at sunset | From | Status |
|---|---|---|---|---|
| Türkiye, Diyanet | anywhere on Earth, before midnight in Greenwich | moon at least 8° from the sun and 5° high | official (the two numbers); the midnight deadline is from a congress working paper (other) | ready |
| Türkiye, since 2017 | a late crescent still counts if it is visible on the American mainland and the new moon came before dawn in New Zealand | | official | ready |
| Saudi Arabia, Umm al-Qura | one spot: the Kaaba in Mecca | has the new moon happened before sunset, and does the moon set after the sun | official (printed calendar, KACST's site) | ready |
| Malaysia | one spot: its westernmost point (Pulau Perak since AH 1444) | moon at least 3° high and 6.4° from the sun | official (numbers, change of place) | ready |
| Indonesia | anywhere in its territory; in practice the far northwest around Banda Aceh | the same two numbers | official (regulation PMA 1/2026) | ready |
| Singapore | one spot: Tuas | the same two numbers; by calculation for Ramadan and Shawwal since a 1974 decision | official (MUIS, round 1) | ready |
| The shared Southeast Asian rule | agreed by Brunei, Indonesia, Malaysia, Singapore; in use from 2021–2022; before it an easier one | | official | ready |
| Every one of them | a month has 29 or 30 days, never more; the question is asked once, on the evening of day 29 | | official, all | ready |

Who does both (calculates a calendar, yet decides Ramadan by looking):

| Country | What we hold | From | Status |
|---|---|---|---|
| Saudi Arabia | Ramadan, Shawwal and Dhu al-Hijjah are decided by sighting through the Supreme Court; the printed calendar calls itself a civil convention. In 2026 the court asked people to look on the 17th and the Royal Court announced the 18th. | official | ready |
| Malaysia | a sighting anywhere in Malaysia overrides the calculation (it did for Shawwal 1443, at Labuan); in 2026 it watched from 29 places | official; press (RTM) | ready |
| Indonesia | the ministry holds a decision session on day 29 with sworn observers | official | ready |
| Egypt | committees look on day 29; a sighting counts only if the calculation allows it (moon sets after the sun, at least 15 h 40 min after the new moon) | official (Dar al-Ifta fatwa 3420, 2016) | ready |
| Oman | used the calculation to rule the 17th out in advance | press, summary | notes |

## 5. Numbers from our own measurements that could carry the ending

| Fact | From | Status |
|---|---|---|
| Türkiye's published calendar, 707 months (AH 1399–1457): 703 follow from the rules, 4 need a named correction | ours (`CrescentDiyanetPublishedTests`) | ready |
| Türkiye's rule changed in 1980, 2009, 2014 and 2017 | ours, measured against the published dates | ready |
| Saudi Arabia has had at least three rules since the 1970s | other (van Gent) for the older ones; official from AH 1420 | ready, worded "at least three" |
| A plain "new moon" clock matches 20% of 510 announced first days and is early in 80% | ours (results document, Round 7); but the announced-dates file has 504 mis-parsed rows of 1,766 | no, until re-measured |

## 6. The one night, place by place from east to west (every line is from the tables above)

**Clock order, checked with our engine on 2026-11-12 (section 1b):** the sun set in Singapore, Malaysia and Indonesia
(11:15 to 11:51 UTC) *before* the new moon at 12:01 UTC. The moon was not even new yet when those three looked. So in
clock time the story runs: sunsets in Southeast Asia, then the new moon and the eclipse, then Pakistan, Mecca, Cairo,
Istanbul, London, Rabat. The list below is by place, east to west.

1. 12:01 UTC: new moon. Over Antarctica the sun becomes a ring.
2. Sunset in Singapore, 40 minutes before the new moon: the moon has already set, 4 minutes before the sun. Thursday.
3. Sunset in Malaysia: watchers at 29 places. Thursday.
4. Sunset in Indonesia: the government's session says Thursday. Muhammadiyah, by its own calendar, had long said Wednesday.
5. Sunset in Mecca: the moon is 3 hours old and sets 3 minutes after the sun. The printed calendar says Wednesday; the announcement says Wednesday.
6. Egypt: looked, not seen. Thursday.
7. Türkiye: by midnight in Greenwich the moon is 6° from the sun, not 8°. Thursday. Its two numbers are first met 3 h 42 min too late.
8. London: one mosque announces Wednesday. Another body is still on day 28 and will look tomorrow.
9. The next evening: Morocco, Pakistan and that British body look, on their day 29. Thursday.

One moon, one evening: Wednesday for some, Thursday for others, and not everyone agreed which evening was day 29.

## 6b. Textbook facts for the opening (not yet tied to a page; cite one at build time)

| Fact | Value | Status |
|---|---|---|
| One turn of the moon's phases | "every 29.5 days" (NASA, `science.nasa.gov/moon/moon-phases/`); on average 29.53059 days, a single month between 29.26 and 29.80 days (NASA, `eclipse.gsfc.nasa.gov/SEhelp/moonorbit.html`) | official, summary; ready |
| Twelve such months | about 354 days, 11 days short of the sun's year, so Ramadan arrives about 11 days earlier each year | notes; arithmetic from the line above |
| The moon moves away from the sun | about half a degree an hour (12° a day) | ready; it is in our guide and follows from the line above |

## 7. Open, for the user

- **Tone on the Saudi evening.** The facts: the calendar's rule was met by 3 minutes; the court asked people to look;
  the Royal Court announced Wednesday; press reports say a sighting was accepted; an astronomy site and Oman's
  announcement say the crescent could not be seen that evening. Suggested: the slide says what each authority decided
  and by which rule, with no verdict; the "could it be seen" point appears once, as a plain statement of who said what.
- **London:** 2026 as the example (it is the same evening as the whole story), 2019 in the notes as "not the first
  time". The user's own example was a past split in London; 2026 gives one with both sides read at their own sites.

## 8. Never on a slide

Diyanet's maps and lists, JAKIM's PDFs, moonsighting.com pages, the Keleş article, any news photograph (all
copyrighted; dates and times taken from them are facts and may be used). The coastline for our own map is Natural
Earth, public domain.

## 9. How the web checks were done (2026-11-11)

Fourteen searches (astronomycenter.net blocked in each) and six single-page reads with default identification: MUIS,
RTM, East London Mosque and Wifaqul Ulama were read in full; the Saudi Press Agency's page returned only its headline.
Not found: the Supreme Court's own text on the sighting; a second look at Egypt's Survey Authority table; a London
Central Mosque statement for 2026.
