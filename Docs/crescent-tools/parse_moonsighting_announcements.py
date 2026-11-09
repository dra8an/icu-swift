# Parse moonsighting.com per-country "1st day" lists (Ramadan, Shawwal, Eid al-Adha pages), AH 1429-1448.
# Output CSV: page,ah_year,ah_month,country_raw,country,first_day,listed_date,basis
import re, html, sys, os, datetime, glob
D = sys.argv[1]
MONTHS = {m: i for i, m in enumerate(['January','February','March','April','May','June','July','August','September','October','November','December'], 1)}
WD = r'(?:Mon|Tues|Wednes|Thurs|Fri|Satur|Sun)day'
def find_date(s):
    m = re.search(WD + r',?\s+([A-Z][a-z]+)\.?\s+(\d{1,2}),?\s+(\d{4})', s)          # Monday, May 6, 2019
    if m and m.group(1) in MONTHS: return datetime.date(int(m.group(3)), MONTHS[m.group(1)], int(m.group(2)))
    m = re.search(WD + r',?\s+(\d{1,2})\s+([A-Z][a-z]+)\.?,?\s+(\d{4})', s)          # Wednesday, 7 August 2013
    if m and m.group(2) in MONTHS: return datetime.date(int(m.group(3)), MONTHS[m.group(2)], int(m.group(1)))
    m = re.search(r'\b([A-Z][a-z]+)\.?\s+(\d{1,2}),\s+(\d{4})', s)                    # August 21, 2009 (Friday)
    if m and m.group(1) in MONTHS: return datetime.date(int(m.group(3)), MONTHS[m.group(1)], int(m.group(2)))
    m = re.search(r'\b(\d{1,2})\s+([A-Z][a-z]+)\.?\s+(\d{4})', s)                     # 7 August 2013
    if m and m.group(2) in MONTHS: return datetime.date(int(m.group(3)), MONTHS[m.group(2)], int(m.group(1)))
    return None
def lines(p):
    t = open(p, encoding='utf-8', errors='replace').read()
    t = re.sub(r'<script.*?</script>|<style.*?</style>', '', t, flags=re.S)
    txt = html.unescape(re.sub(r'<[^>]+>', '\n', t))
    return [l.strip() for l in txt.split('\n') if l.strip()]
def basis_of(s):
    s2 = s.lower()
    if 'saudi' in s2: return 'follows-Saudi'
    if 'local sighting' in s2 or re.search(r'\(sighting', s2) or 'sighting)' in s2: return 'sighting'
    if 'turkey' in s2 or 'ecfr' in s2 or 'fcna' in s2 or 'isna' in s2: return 'follows-calc-body'
    if 'calculat' in s2 or 'criteria' in s2 or 'moon born' in s2 or 'conjunction' in s2 or 'birth of moon' in s2: return 'calculation'
    if '30 days' in s2: return '30-days'
    if 'official announcement' in s2 or 'announcement' in s2: return 'official'
    return ''
out = []
for p in sorted(glob.glob(os.path.join(D, '1???[a-z][a-z][a-z].html'))):
    name = os.path.basename(p)[:-5]; year = int(name[:4]); mon = name[4:]
    if mon not in ('rmd', 'shw', 'zhj'): continue
    ahm = {'rmd': 9, 'shw': 10, 'zhj': 12}[mon]
    L = lines(p)
    start = next((k for k, l in enumerate(L) if re.search(r'1st Day of .* in Different Countries|Eid al-Adha in Different Countries|OFFICIAL 1st Day', l)), None)
    if start is None: print(f'# {name}: no per-country section', file=sys.stderr); continue
    cur_date = None; group_basis = ''; pending = None; n = 0
    for l in L[start + 1:]:
        if l.startswith('Back to Top') or re.match(r'^Moon ?Sighting for the month', l): break
        d = find_date(l)
        is_heading = l.startswith('Countries that') or (d is not None and re.match(r'^(' + WD + r',?\s+)?[A-Z][a-z]+\.?\s+\d{1,2},?\s+\d{4}\s*(\(' + WD + r'\))?:', l)) or (d is not None and re.match(r'^' + WD + r',\s+\d{1,2}\s+[A-Z][a-z]+\s+\d{4}:', l))
        if is_heading:
            cur_date = d if d else (None if l.startswith('Countries that') else cur_date)
            if l.startswith('Countries that'):
                group_basis = basis_of(l) or ('own' if 'own criteria' in l.lower() else '')
            else:
                group_basis = ''
            pending = None
            continue
        if re.fullmatch(r'\(?\s*\)?', l) or l == '????' or l.startswith('www.') or l in ('[', ']'):
            continue
        if d is not None and re.fullmatch(r'\(?' + WD + r'[^()]*\)?', l):   # a date on its own line: belongs to the previous country
            if pending is not None:
                pending['date'] = d; out.append(pending); n += 1; pending = None
            continue
        # a country line
        own_date = d
        text = re.sub(r'\(' + WD + r'[^)]*\)', '', l).strip()
        text = re.sub(r'\(\s*\)', '', text).strip()
        if not text or text == '????': continue
        country = re.split(r'\s*\(|\s+-\s+|\s*\[|\t', text)[0].strip().rstrip(':').strip()
        if not country or country.lower().startswith(('these are', 'countries', 'note', 'updated')): continue
        rec = {'page': name, 'year': year, 'month': ahm, 'raw': text[:120], 'country': country, 'date': own_date if own_date else cur_date,
               'basis': basis_of(text) or group_basis}
        if own_date is None and cur_date is None:
            pending = rec; rec['date'] = None   # may receive a date on the next line
            continue
        if own_date is None and cur_date is not None and 'Countries that' not in ''.join(L[start:start+2]) and False:
            pass
        if rec['date'] is None: pending = rec; continue
        out.append(rec); n += 1; pending = None
    print(f'# {name}: {n} dated entries', file=sys.stderr)
w = open(os.path.join(D, '..', 'moonsighting_announced.csv'), 'w')
w.write('page,ah_year,ah_month,country_raw,country,first_day,listed_date,basis\n')
for r in out:
    listed = r['date']; first = listed - datetime.timedelta(days=9) if r['month'] == 12 else listed
    w.write(f"{r['page']},{r['year']},{r['month']},\"{r['raw']}\",\"{r['country']}\",{first.isoformat()},{listed.isoformat()},{r['basis']}\n")
w.close()
print(f'TOTAL {len(out)} dated entries')
