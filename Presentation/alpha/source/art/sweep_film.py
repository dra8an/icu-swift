"""The film for the Türkiye part: the Earth turns under the sunset line, from Singapore to the open Pacific.

Usage:
  python art/sweep_film.py <places.csv> <grid.csv> <series.csv> <ne_10m_land.geojson> <output folder>            the film
  python art/sweep_film.py <places.csv> <grid.csv> <series.csv> <ne_10m_land.geojson> <output folder> 11.4 24    stills at those hours

Writes s15c_sweep.mp4 (1920 x 1080, 30 frames a second, H.264), its first frame (s15c_sweep_first.jpg and a
smaller .png, which the slide shows until the film is started) and its last frame (s15c_sweep_poster.jpg).
Hours are counted from 17 February 2026, 00:00 Universal Time, as everywhere in engine/out.

How it is made, so that it cannot disagree with the numbers:
  * The camera stands still relative to the sun, so the line between day and night stays where it is and the
    Earth turns under it, 15 degrees an hour. A place has its sunset when it crosses that line.
  * Where the sun stands is fitted to the engine's own sunset line (not taken from a formula).
  * Every figure shown (each place's sunset, the moon's height and direction there, the moon's distance from
    the sun through the night) is read from engine/out/places.csv and series.csv.
  * Film time is not even: it slows down while a place is at its sunset and hurries between places.
"""
import csv
import json
import math
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

import nightsky

places_csv, grid_csv, series_csv, land_json = sys.argv[1:5]
out = Path(sys.argv[5])
still_hours = [float(a) for a in sys.argv[6:]]
out.mkdir(parents=True, exist_ok=True)

FW, FH, FPS = 1920, 1080, 30
GX, GY, GR = 1335, 548, 452          # the globe: centre and radius
LAT0, EAST = 14.0, 18.0              # we look at 14 N, 18 degrees east of the sunset line
EQUATOR_SUNSET = 90.85               # how far east of the sun's own longitude the sun sets, at the equator
DEADLINE = 24.0
LEFT = 130                            # the left edge of everything beside the globe: the slide's own text starts there too

CREAM, MUTED = (246, 238, 221), (189, 185, 201)
GOLD, MET, EMBER, NIGHT = (232, 185, 135), (255, 214, 140), (217, 119, 79), (7, 10, 28)
IOWAN = "/System/Library/Fonts/Supplemental/Iowan Old Style.ttc"
AVENIR = "/System/Library/Fonts/Avenir Next.ttc"


def font(kind, size):
    path, index = {"serif": (IOWAN, 0), "sans": (AVENIR, 7), "demi": (AVENIR, 2), "italic": (AVENIR, 4)}[kind]
    return ImageFont.truetype(path, size, index=index)


F = {name: font(kind, size) for name, (kind, size) in {
    "clock": ("serif", 104), "date": ("sans", 22), "line": ("sans", 27), "line_big": ("demi", 30), "gauge": ("sans", 22),
    "gauge_value": ("serif", 40), "panel_title": ("demi", 30), "panel": ("italic", 24), "small": ("italic", 20),
    "value": ("serif", 38), "value_label": ("sans", 20), "place": ("demi", 22)}.items()}

# ---- the engine's numbers --------------------------------------------------------------------------------
place_rows = {r["place"]: r for r in csv.DictReader(open(places_csv)) if r["evening"] == "17 Feb"}
series = [(float(r["utc_h"]), float(r["elong_geocentric"])) for r in csv.DictReader(open(series_csv))]
NEW_MOON = float(next(iter(place_rows.values()))["new_moon_utc_h"])


def sunset_of(name):
    return float(place_rows[name]["sunset_utc_h"])


def distance_at(t):
    """The moon's distance from the sun at a moment, read off the engine's series."""
    return float(np.interp(t, [s[0] for s in series], [s[1] for s in series]))


grid_rows = [r for r in csv.DictReader(open(grid_csv)) if r["sunset_utc_h"] != ""]
lats = sorted({int(r["latitude"]) for r in grid_rows})
lons = sorted({int(r["longitude"]) for r in grid_rows})
sunset_grid = np.zeros((len(lats), len(lons)), np.float32)
for r in grid_rows:
    sunset_grid[int(r["latitude"]) - lats[0], int(r["longitude"]) - lons[0]] = float(r["sunset_utc_h"])


def sunset_line(hours):
    pts = []
    for a, lat in enumerate(lats):
        row = sunset_grid[a] - hours
        idx = np.where((row[:-1] >= 0) & (row[1:] < 0))[0]
        if len(idx) and -58 <= lat <= 66:
            k = idx[-1]
            pts.append((float(lat), float(lons[k] + row[k] / (row[k] - row[k + 1]))))
    return pts


def fit_sun(line):
    best = None
    for tenth in range(-200, 201):
        dec = math.radians(tenth / 10.0)
        offsets = []
        for lat, lon in line:
            phi = math.radians(lat)
            cos_h = (math.sin(math.radians(-0.8333)) - math.sin(phi) * math.sin(dec)) / (math.cos(phi) * math.cos(dec))
            if -1 < cos_h < 1:
                offsets.append(lon - math.degrees(math.acos(cos_h)))
        mean = sum(offsets) / len(offsets)
        spread = sum((o - mean) ** 2 for o in offsets) / len(offsets)
        if best is None or spread < best[0]:
            best = (spread, float(math.degrees(dec)), float(mean))
    return best[1], best[2]


T_FIRST = sunset_of("First place (4N 142W)")
DEC, SUN_LON_FIRST = fit_sun(sunset_line(T_FIRST))
_, sun_lon_deadline = fit_sun(sunset_line(DEADLINE))
drift = ((sun_lon_deadline - (SUN_LON_FIRST + 15.0 * (T_FIRST - DEADLINE)) + 180) % 360) - 180
assert abs(drift) < 0.3, f"the sun's place at the deadline is off by {drift} degrees"
deadline_line = sunset_line(DEADLINE)


def view_centre(t):
    """The longitude facing us at a moment: the sun's own longitude, plus a quarter turn, plus a little."""
    return SUN_LON_FIRST - 15.0 * (t - T_FIRST) + EQUATOR_SUNSET + EAST


# ---- land ----------------------------------------------------------------------------------------------------
PER_DEG = 10
world = Image.new("L", (360 * PER_DEG, 180 * PER_DEG), 0)
dw = ImageDraw.Draw(world)
for feature in json.load(open(land_json))["features"]:
    g = feature["geometry"]
    for polygon in (g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]):
        for k, ring in enumerate(polygon):
            pts = [((lon + 180) * PER_DEG, (90 - lat) * PER_DEG) for lon, lat in ring]
            if len(pts) >= 3:
                dw.polygon(pts, fill=255 if k == 0 else 0)
land_world = np.asarray(world.filter(ImageFilter.GaussianBlur(1.3)))     # soft coasts: smooth edges on the globe

# ---- the globe: everything that does not change from frame to frame --------------------------------------
phi0 = math.radians(LAT0)
n = 2 * GR + 4
yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
x = xx - n / 2 + 0.5
y = -(yy - n / 2 + 0.5)
rho = np.sqrt(x * x + y * y)
c = np.arcsin(np.clip(rho / GR, 0, 1))
safe = np.where(rho == 0, 1, rho)
phi = np.arcsin(np.clip(np.cos(c) * math.sin(phi0) + y * np.sin(c) * math.cos(phi0) / safe, -1, 1))
dlon = np.degrees(np.arctan2(x * np.sin(c), rho * np.cos(c) * math.cos(phi0) - y * np.sin(c) * math.sin(phi0)))
lat_deg = np.degrees(phi)
row_index = np.clip(((90 - lat_deg) * PER_DEG).astype(np.int32), 0, 180 * PER_DEG - 1)
sun_alt = np.degrees(np.arcsin(np.clip(np.sin(phi) * math.sin(math.radians(DEC)) + np.cos(phi) * math.cos(math.radians(DEC))
                                       * np.cos(np.radians(dlon + EQUATOR_SUNSET + EAST)), -1, 1)))
ALTS = [-90, -16, -8, -2.5, 0, 3, 12, 90]
SEA = [(7, 10, 28), (9, 13, 36), (36, 28, 80), (112, 58, 102), (206, 122, 90), (132, 100, 138), (52, 76, 142), (58, 88, 160)]
LAND = [(24, 31, 66), (27, 34, 72), (62, 50, 104), (144, 86, 118), (228, 156, 112), (170, 138, 150), (98, 122, 156), (112, 140, 168)]
shade = (0.58 + 0.42 * np.cos(c)).astype(np.float32)
edge = np.clip(1 - np.abs(sun_alt + 0.83) / 0.5, 0, 1)                    # the sunset line, a thin bright edge
sea_img = np.stack([np.interp(sun_alt, ALTS, [s[k] for s in SEA]) for k in range(3)], axis=2).astype(np.float32)
land_img = np.stack([np.interp(sun_alt, ALTS, [s[k] for s in LAND]) for k in range(3)], axis=2).astype(np.float32)
for image in (sea_img, land_img):
    image += (np.array((255, 232, 190), np.float32) - image) * (0.85 * edge)[:, :, None]
    image *= shade[:, :, None]
land_minus_sea = land_img - sea_img
parallels = (np.abs(((lat_deg + 15) % 30) - 15) < 0.24) * 9.0 * shade
meridian_width = 0.24 / np.maximum(np.cos(phi), 0.2)
globe_alpha = Image.fromarray((np.clip(GR - rho, 0, 1) * 255).astype(np.uint8))

# ---- the night behind the globe ------------------------------------------------------------------------------
space = np.empty((nightsky.H, nightsky.W, 3), np.float32)
space[:] = (6, 8, 24)
vy = (np.arange(nightsky.H, dtype=np.float32) / nightsky.H - 0.5) * 2
vx = (np.arange(nightsky.W, dtype=np.float32) / nightsky.W - 0.5) * 2
space *= (1 - 0.22 * (0.5 * vx[None, :] ** 2 + 0.5 * vy[:, None] ** 2))[:, :, None]
space += np.random.default_rng(29).normal(0, 1.1, (nightsky.H, nightsky.W, 1)).astype(np.float32)
backdrop = nightsky.add_stars(Image.fromarray(np.clip(space, 0, 255).astype(np.uint8)).convert("RGBA"), horizon=1.5, glow_x=0.5, glow=0.0, count=1700)
scale = nightsky.W / FW
air = nightsky.Cutout()
air.ellipse(GX * scale, GY * scale, (GR + 8) * scale, (GR + 8) * scale)
backdrop = air.lay(backdrop, (70, 104, 196), 0.5, blur=26).resize((FW, FH), Image.LANCZOS).convert("RGB")

# ---- the places, and what happens when --------------------------------------------------------------------
DOTS = {"Jakarta": "Indonesia", "Singapore (Tuas)": "Singapore", "Kuala Lumpur": "Malaysia", "Peshawar": "Pakistan",
        "Mecca (Kaaba)": "Mecca", "Cairo": "Egypt", "Ankara": "Türkiye", "London": "London", "Rabat": "Morocco",
        "New York": "New York", "Los Angeles": "Los Angeles", "Alaska Peninsula (tip)": "Alaska"}
NAME_AT = {"Kuala Lumpur": (-12, -4, "rs"), "Singapore (Tuas)": (14, 6, "ls"), "Jakarta": (14, 22, "ls"),   # where a name sits by its light
           "Ankara": (12, -2, "ls"), "Cairo": (12, 16, "ls")}
EVENTS = [   # t: when; title, data: the card and whose numbers it shows; dwell: seconds of film spent there
    {"t": sunset_of("Singapore (Tuas)"), "title": "Singapore · Malaysia · Indonesia", "data": "Singapore (Tuas)", "dwell": 3.0},
    {"t": NEW_MOON, "dwell": 1.3},
    {"t": sunset_of("Peshawar"), "title": "Pakistan", "data": "Peshawar", "dwell": 2.0},
    {"t": sunset_of("Mecca (Kaaba)"), "title": "Mecca", "data": "Mecca (Kaaba)", "dwell": 2.7},
    {"t": sunset_of("Cairo"), "title": "Egypt · Türkiye", "data": "Cairo", "dwell": 2.4},
    {"t": sunset_of("London"), "title": "London", "data": "London", "dwell": 2.3},
    {"t": sunset_of("Rabat"), "title": "Morocco", "data": "Rabat", "dwell": 2.3},
    {"t": sunset_of("New York"), "title": "New York", "data": "New York", "dwell": 2.1},
    {"t": DEADLINE, "dwell": 2.8},
    {"t": sunset_of("Los Angeles"), "title": "Los Angeles", "data": "Los Angeles", "dwell": 2.6},
    {"t": T_FIRST, "title": "The open Pacific", "data": "First place (4N 142W)", "dwell": 1.0, "first": True},
]
T0, T1 = sunset_of("Jakarta") - 0.3, T_FIRST + 0.004     # the film stops at the first place's sunset
SPEED, SLOW = 1.55, 0.05                 # hours of the evening per second of film between places; how tightly it slows
HOLD_START, HOLD_END = 1.0, 4.0


def film_seconds(t):
    """How far into the film a moment of the evening falls (before the opening hold is added)."""
    return (t - T0) / SPEED + sum(e["dwell"] / (1 + math.exp(-(t - e["t"]) / SLOW)) for e in EVENTS)


table_t = np.linspace(T0, T1, 20000)
table_s = np.array([film_seconds(t) for t in table_t])
table_s -= table_s[0]
LENGTH = HOLD_START + float(table_s[-1]) + HOLD_END


def evening_at(seconds):
    return float(np.interp(seconds - HOLD_START, table_s, table_t))


def seconds_at(t):
    return HOLD_START + float(np.interp(t, table_t, table_s))


for e in EVENTS:
    e["s"] = seconds_at(e["t"])
CARDS = [e for e in EVENTS if "title" in e]


def project(lat, lon, centre):
    p, d = math.radians(lat), math.radians(lon - centre)
    if math.sin(phi0) * math.sin(p) + math.cos(phi0) * math.cos(p) * math.cos(d) < 0.02:
        return None
    return (GX + GR * math.cos(p) * math.sin(d), GY - GR * (math.cos(phi0) * math.sin(p) - math.sin(phi0) * math.cos(p) * math.cos(d)))


def ease(v):
    v = min(1.0, max(0.0, v))
    return v * v * (3 - 2 * v)


def clock_words(t):
    minutes = int(round(t * 60))
    return f"{(minutes // 60) % 24:02d}:{minutes % 60:02d}", ("17 FEBRUARY 2026" if minutes < 24 * 60 else "18 FEBRUARY 2026")


def hours_minutes(h):
    minutes = int(round(h * 60))
    return f"{minutes // 60} h {minutes % 60:02d} min" if minutes >= 60 else f"{minutes} min"


# the western-sky window
PX0, PY0, PW, PH = LEFT, 622, 700, 412
SKY_TOP, SKY_BOTTOM = PY0 + 96, PY0 + PH - 86
PPD = (SKY_BOTTOM - SKY_TOP) / 8.6                     # pixels for one degree: the window shows -1.6 to +7.0 degrees
HORIZON_Y = SKY_BOTTOM - 1.6 * PPD
SUN_X = PX0 + PW * 0.5

panel = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
pd = ImageDraw.Draw(panel)
pd.rounded_rectangle([PX0, PY0, PX0 + PW, PY0 + PH], radius=18, fill=(10, 14, 40, 205), outline=CREAM + (70,), width=1)
sky_box = [PX0 + 18, SKY_TOP, PX0 + PW - 18, SKY_BOTTOM]
for k in range(int(HORIZON_Y - SKY_TOP)):                # a small dusk of its own
    f = k / (HORIZON_Y - SKY_TOP)
    pd.line([(sky_box[0], SKY_TOP + k), (sky_box[2], SKY_TOP + k)],
            fill=(int(14 + 150 * f ** 3), int(18 + 70 * f ** 3), int(52 + 30 * f ** 2), 255))
pd.rectangle([sky_box[0], HORIZON_Y, sky_box[2], SKY_BOTTOM], fill=(5, 6, 16, 255))
for xx_ in range(int(sky_box[0]) + 8, int(sky_box[2]) - 150, 22):   # the mark at 5 degrees
    pd.line([(xx_, HORIZON_Y - 5 * PPD), (xx_ + 12, HORIZON_Y - 5 * PPD)], fill=CREAM + (150,), width=2)
pd.text((sky_box[2] - 12, HORIZON_Y - 5 * PPD), "5° high", font=F["small"], fill=CREAM + (220,), anchor="rm")
pd.text((sky_box[2] - 12, HORIZON_Y + 6), "the horizon, looking west", font=F["small"], fill=MUTED + (200,), anchor="ra")
glow = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse([SUN_X - 70, HORIZON_Y - 46, SUN_X + 70, HORIZON_Y + 46], fill=(255, 196, 120, 150))
glow = glow.filter(ImageFilter.GaussianBlur(26))
glow.paste((0, 0, 0, 0), [0, int(HORIZON_Y), FW, FH])
panel = Image.alpha_composite(panel, glow)
ImageDraw.Draw(panel).pieslice([SUN_X - 11, HORIZON_Y - 11, SUN_X + 11, HORIZON_Y + 11], 180, 360, fill=(255, 240, 200, 255))


def card_layer(event, strength):
    """What the window says about one place: where the moon stood at that sunset, and the two figures."""
    r = place_rows[event["data"]]
    height, distance = float(r["alt_apparent"]), float(r["elong_geocentric"])
    aside = ((float(r["moon_azimuth"]) - float(r["sun_azimuth"]) + 180) % 360) - 180
    layer = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text((PX0 + 24, PY0 + 14), event["title"], font=F["panel_title"], fill=(MET if event.get("first") else CREAM) + (255,))
    mx, my = SUN_X + aside * PPD, HORIZON_Y - height * PPD
    if height < 0:
        d.ellipse([mx - 9, my - 9, mx + 9, my + 9], outline=CREAM + (150,), width=2)
        words = "The moon has already set."
    else:
        d.ellipse([mx - 30, my - 30, mx + 30, my + 30], outline=CREAM + (90,), width=1)
        d.ellipse([mx - 9, my - 9, mx + 9, my + 9], fill=(255, 245, 218, 255))
        words = "Both numbers are met: the first place on Earth." if event.get("first") else f"The moon stands {height:.1f}° high."
    d.text((PX0 + 24, PY0 + 54), words, font=F["panel"], fill=(MET if event.get("first") else CREAM) + (255,))
    for k, (label, value, needs) in enumerate((("height at this sunset", height, 5.0), ("distance from the sun", distance, 8.0))):
        bx = PX0 + 24 + k * 340
        ok = value >= needs - 0.005
        shown = "below the horizon" if value < 0 else f"{value:.1f}°"
        d.text((bx, PY0 + PH - 76), label, font=F["value_label"], fill=MUTED + (255,))
        d.text((bx, PY0 + PH - 30), shown, font=F["value"] if value >= 0 else F["panel"], fill=(MET if ok else CREAM) + (255,), anchor="lm")
        if value >= 0:
            wide = d.textlength(shown, font=F["value"])
            d.text((bx + wide + 16, PY0 + PH - 28), ("met" if ok else f"needs {needs:.0f}°"), font=F["value_label"],
                   fill=(MET if ok else MUTED) + (255,), anchor="lm")
    if strength < 1:
        layer.putalpha(layer.getchannel("A").point(lambda v: int(v * strength)))
    return layer


def frame_at(seconds):
    t = evening_at(seconds)
    centre = view_centre(t)
    lon = centre + dlon
    col = (((lon + 180.0) % 360.0) * PER_DEG).astype(np.int32)
    np.clip(col, 0, 360 * PER_DEG - 1, out=col)
    rgb = sea_img + land_minus_sea * (land_world[row_index, col].astype(np.float32) / 255.0)[:, :, None]
    net = parallels + (np.abs(((lon + 15) % 30) - 15) < meridian_width) * 9.0 * shade
    rgb += net[:, :, None]
    frame = backdrop.copy()
    frame.paste(Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)), (GX - n // 2, GY - n // 2), globe_alpha)

    over = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    # the deadline, left behind on the Earth as a dashed line
    if t >= DEADLINE:
        a = int(235 * ease((seconds - seconds_at(DEADLINE)) / 0.6))
        pts = [p for p in (project(la, lo, centre) for la, lo in deadline_line) if p]
        for k in range(0, len(pts) - 3, 6):
            d.line(pts[k:k + 4], fill=CREAM + (a,), width=3)
    # the places: a light each; rings when its sunset comes; its name while its card is up
    now = max((e for e in CARDS if seconds >= e["s"] - 0.15), key=lambda e: e["s"], default=None)
    for name, label in DOTS.items():
        r = place_rows[name]
        p = project(float(r["latitude"]), float(r["longitude"]), centre)
        if not p:
            continue
        since = seconds - seconds_at(float(r["sunset_utc_h"])) if float(r["sunset_utc_h"]) <= T1 else -99.0
        d.ellipse([p[0] - 5, p[1] - 5, p[0] + 5, p[1] + 5], fill=CREAM + (255 if since >= 0 else 170,))
        if 0 <= since < 1.6:
            for lag in (0.0, 0.45):
                g = (since - lag) / 1.15
                if 0 <= g <= 1:
                    rad = 8 + 34 * g
                    d.ellipse([p[0] - rad, p[1] - rad, p[0] + rad, p[1] + rad], outline=CREAM + (int(230 * (1 - g)),), width=2)
        if -0.4 <= since < 3.2 and name != "Alaska Peninsula (tip)":
            a = int(255 * ease((since + 0.4) / 0.4) * ease((3.2 - since) / 0.7))
            dx, dy, anchor = NAME_AT.get(name, (12, 8, "ls"))
            d.text((p[0] + dx, p[1] + dy), label, font=F["place"], fill=CREAM + (a,), anchor=anchor,
                   stroke_width=3, stroke_fill=NIGHT + (int(a * 0.7),))
    # the first place keeps its light and rings
    if t >= T_FIRST:
        r = place_rows["First place (4N 142W)"]
        p = project(float(r["latitude"]), float(r["longitude"]), centre)
        a = ease((seconds - seconds_at(T_FIRST)) / 0.5)
        for rad, wd in ((22, 2), (40, 1)):
            d.ellipse([p[0] - rad, p[1] - rad, p[0] + rad, p[1] + rad], outline=(255, 244, 214, int(220 * a)), width=wd)
        d.ellipse([p[0] - 8, p[1] - 8, p[0] + 8, p[1] + 8], fill=(255, 250, 232, int(255 * a)))

    # the clock, and two lines beside it
    words, date = clock_words(t)
    first_shown = t >= T_FIRST
    d.text((LEFT, 384), date + "  ·  UNIVERSAL TIME", font=F["date"], fill=MUTED + (255,))
    d.text((LEFT - 4, 400), words, font=F["clock"], fill=(MET if first_shown else CREAM) + (255,))
    age = t - NEW_MOON
    d.text((LEFT + 302, 432), "the moon is not new yet" if age < 0 else f"the moon is {hours_minutes(age)} old", font=F["line"], fill=CREAM + (255,))
    if first_shown:
        d.text((LEFT + 302, 472), "3 h 42 min after the deadline", font=F["line_big"], fill=MET + (int(255 * ease((seconds - seconds_at(T_FIRST)) / 0.6)),))
    elif t >= DEADLINE:
        d.text((LEFT + 302, 474), "the deadline has passed", font=F["line"], fill=EMBER + (255,))
    else:
        d.text((LEFT + 302, 474), "deadline: midnight in Greenwich", font=F["line"], fill=MUTED + (255,))
    # the gauge: the moon's distance from the sun, the same for everyone on Earth
    gx0, gx1, gy = LEFT, LEFT + 500, 582
    dist = distance_at(t)
    d.text((gx0, gy - 42), "the moon's distance from the sun", font=F["gauge"], fill=MUTED + (255,))
    d.rounded_rectangle([gx0, gy, gx1, gy + 12], radius=6, fill=(255, 255, 255, 38))
    reach = gx0 + (gx1 - gx0) * min(dist, 9.0) / 9.0
    d.rounded_rectangle([gx0, gy, max(reach, gx0 + 12), gy + 12], radius=6, fill=(MET if dist >= 8 else GOLD) + (255,))
    mark = gx0 + (gx1 - gx0) * 8.0 / 9.0
    d.line([(mark, gy - 10), (mark, gy + 20)], fill=CREAM + (255,), width=2)
    d.text((mark, gy - 14), "8°", font=F["gauge"], fill=CREAM + (255,), anchor="mb")
    d.text((gx1 + 26, gy + 8), f"{dist:.1f}°", font=F["gauge_value"], fill=(MET if dist >= 8 else CREAM) + (255,), anchor="lm")

    over = Image.alpha_composite(over, panel)
    if now is not None:
        index = CARDS.index(now)
        arrive = ease((seconds - (now["s"] - 0.15)) / 0.35)
        if index > 0 and arrive < 1:
            over = Image.alpha_composite(over, card_layer(CARDS[index - 1], 1 - arrive))
        over = Image.alpha_composite(over, card_layer(now, arrive))
    else:
        ImageDraw.Draw(over).text((PX0 + 24, PY0 + 14), "The western sky, at each place's sunset", font=F["panel_title"], fill=MUTED + (255,))
    frame.paste(over, (0, 0), over)
    return frame


if still_hours:
    for h in still_hours:
        frame_at(seconds_at(h) + 0.9).save(out / f"s15c_still_{h:05.2f}.jpg", quality=90)
        print("still at", h)
    print(f"the film would run {LENGTH:.1f} seconds")
    sys.exit(0)

import imageio_ffmpeg

target = out / "s15c_sweep.mp4"
encoder = subprocess.Popen(
    [imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{FW}x{FH}", "-r", str(FPS),
     "-i", "-", "-an", "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(target)],
    stdin=subprocess.PIPE)
total = int(round(LENGTH * FPS))
last = None
for k in range(total):
    last = frame_at(k / FPS)
    if k == 0:      # the slide shows this until the film is started
        last.save(out / "s15c_sweep_first.jpg", quality=95, subsampling=0)
        last.resize((1280, 720), Image.LANCZOS).save(out / "s15c_sweep_first.png", optimize=True)
    encoder.stdin.write(last.tobytes())
    if k % 150 == 0:
        print(f"frame {k} of {total}", flush=True)
encoder.stdin.close()
encoder.wait()
last.save(out / "s15c_sweep_poster.jpg", quality=92)
print(f"wrote {target}: {LENGTH:.1f} seconds, {total} frames")
