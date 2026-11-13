"""The Earth as a globe at the moment Türkiye's two numbers were first met, for the second Türkiye slide.

Usage: python art/globe.py <grid.csv> <ne_10m_land.geojson> <output folder>
Writes s15b_turkiye_globe.jpg (2560 x 1440), a small copy, and s15b_globe_points.json (where things sit, in
inches on a 13.333 x 7.5 slide, for the labels).

What it shows, all from the engine's one-degree grid of the evening of 17 February 2026 (engine/out/grid.csv):
  * the globe lit as it was at the moment the numbers were first met (03:42 Universal Time on the 18th):
    day on the left, night on the right, the sunset line between them;
  * a dashed line: where the sunset line stood at midnight in Greenwich, the deadline;
  * one light on the sunset line: the first place on Earth where the moon stood 5 degrees high and 8 degrees
    from the sun at sunset, and a soft wedge opening westwards from it, where later sunsets met the numbers too.
The sun's position is not taken from a formula: it is fitted to the engine's own sunset line, so the picture
cannot disagree with the numbers. The coastline is Natural Earth (public domain).
"""
import csv
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from nightsky import CREAM, H, SS, W, Cutout, add_stars, save

grid_csv, land_json, out = sys.argv[1], sys.argv[2], Path(sys.argv[3])
out.mkdir(parents=True, exist_ok=True)

CX, CY, R = 1770, 800, 545          # where the globe sits in the picture, and its radius
LAT0, LON0 = 14.0, -124.0           # the point of the Earth facing us: the eastern Pacific
DEADLINE = 24.0                     # midnight in Greenwich, in hours after 17 February 00:00 UTC
ALASKA = (54.85, -163.38)           # the tip of the Alaska Peninsula (fact sheet, section 2)
HAWAII = (21.3, -157.86)
GOLD = (255, 214, 140)

# ---- the engine's grid ---------------------------------------------------------------------------------
rows = [r for r in csv.DictReader(open(grid_csv)) if r["sunset_utc_h"] != ""]
lats = sorted({int(r["latitude"]) for r in rows})
lons = sorted({int(r["longitude"]) for r in rows})


def field(key):
    a = np.zeros((len(lats), len(lons)), np.float32)
    for r in rows:
        a[int(r["latitude"]) - lats[0], int(r["longitude"]) - lons[0]] = float(r[key])
    return a


sunset, alt_seen, elong = field("sunset_utc_h"), field("alt_apparent"), field("elong_geocentric")
numbers = np.minimum(alt_seen - 5.0, elong - 8.0)     # at or above zero: both of Türkiye's numbers are met
met = numbers >= 0
i, j = np.unravel_index(np.argmin(np.where(met, sunset, 99.0)), sunset.shape)
FIRST = (float(lats[i]), float(lons[j]))
T_FIRST = float(sunset[i, j])


def sunset_line(hours):
    """Where the sun was setting at a given moment: one (latitude, longitude) for every degree of latitude."""
    pts = []
    for a, lat in enumerate(lats):
        row = sunset[a] - hours
        idx = np.where((row[:-1] >= 0) & (row[1:] < 0))[0]      # sunset comes earlier towards the east
        if len(idx) and -58 <= lat <= 66:
            k = idx[-1]
            pts.append((float(lat), float(lons[k] + row[k] / (row[k] - row[k + 1]))))
    return pts


def fit_sun(line):
    """The sun's declination and the longitude it stands over, fitted to a sunset line."""
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
            best = (spread, math.degrees(dec), mean)
    return float(best[1]), float(best[2]), float(math.sqrt(best[0]))


line_first, line_deadline = sunset_line(T_FIRST), sunset_line(DEADLINE)
DEC, SUN_LON, misfit = fit_sun(line_first)

# ---- land, as a picture of the whole world to look colours up in ------------------------------------------
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
land_world = np.asarray(world)

# ---- the globe ---------------------------------------------------------------------------------------------
phi0, lam0 = math.radians(LAT0), math.radians(LON0)
n = int(2 * R * SS) + 4
yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
x = (xx - n / 2 + 0.5) / SS
y = -(yy - n / 2 + 0.5) / SS
rho = np.sqrt(x * x + y * y)
inside = rho <= R
c = np.arcsin(np.clip(rho / R, 0, 1))
safe = np.where(rho == 0, 1, rho)
phi = np.arcsin(np.clip(np.cos(c) * math.sin(phi0) + y * np.sin(c) * math.cos(phi0) / safe, -1, 1))
lam = lam0 + np.arctan2(x * np.sin(c), rho * np.cos(c) * math.cos(phi0) - y * np.sin(c) * math.sin(phi0))
lat_deg = np.degrees(phi)
lon_deg = (np.degrees(lam) + 180) % 360 - 180

col = np.clip(((lon_deg + 180) * PER_DEG).astype(int), 0, 360 * PER_DEG - 1)
row = np.clip(((90 - lat_deg) * PER_DEG).astype(int), 0, 180 * PER_DEG - 1)
is_land = land_world[row, col] > 127

# how high the sun stands at every point of the globe at that moment
sun_alt = np.degrees(np.arcsin(np.clip(np.sin(phi) * math.sin(math.radians(DEC))
                                       + np.cos(phi) * math.cos(math.radians(DEC)) * np.cos(lam - math.radians(SUN_LON)), -1, 1)))
ALTS = [-90, -16, -8, -2.5, 0, 3, 12, 90]
SEA = [(7, 10, 28), (9, 13, 36), (36, 28, 80), (112, 58, 102), (206, 122, 90), (132, 100, 138), (52, 76, 142), (58, 88, 160)]
LAND = [(24, 31, 66), (27, 34, 72), (62, 50, 104), (144, 86, 118), (228, 156, 112), (170, 138, 150), (98, 122, 156), (112, 140, 168)]
rgb = np.zeros((n, n, 3), np.float32)
for k in range(3):
    sea = np.interp(sun_alt, ALTS, [s[k] for s in SEA])
    land = np.interp(sun_alt, ALTS, [s[k] for s in LAND])
    rgb[:, :, k] = np.where(is_land, land, sea)

# a faint net of latitude and longitude lines, so the ball reads as a ball
net = (np.abs(((lon_deg + 15) % 30) - 15) < 0.22 / np.maximum(np.cos(phi), 0.2)) | (np.abs(((lat_deg + 15) % 30) - 15) < 0.22)
rgb += net[:, :, None] * 9.0

# the wedge: where sunsets after the first one met the numbers too, fading away towards the west
gi = np.clip(lat_deg - lats[0], 0, len(lats) - 1.001)
gj = np.clip(lon_deg - lons[0], 0, len(lons) - 1.001)
i0, j0 = gi.astype(int), gj.astype(int)
fi, fj = gi - i0, gj - j0
value = (numbers[i0, j0] * (1 - fi) * (1 - fj) + numbers[i0 + 1, j0] * fi * (1 - fj)
         + numbers[i0, j0 + 1] * (1 - fi) * fj + numbers[i0 + 1, j0 + 1] * fi * fj)
wedge = np.clip(value / 0.35, 0, 1) * (lat_deg > lats[0]) * (lat_deg < lats[-1]) * inside
# soft edges all round (the grid is coarse), then the fade to the west and a clean stop at the sunset line
wedge = np.asarray(Image.fromarray((wedge * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(9 * SS)), np.float32) / 255
wedge *= np.clip(1 - sun_alt / 17.0, 0, 1) ** 1.3 * (sun_alt > -0.9)
rgb += (np.array(GOLD, np.float32) - rgb) * (0.6 * wedge)[:, :, None]

# the sunset line itself, a thin bright edge
edge = np.clip(1 - np.abs(sun_alt + 0.83) / 0.42, 0, 1)
rgb += (np.array((255, 232, 190), np.float32) - rgb) * (0.85 * edge)[:, :, None]

rgb *= (0.58 + 0.42 * np.cos(c))[:, :, None]          # darker towards the rim: a ball, not a disc
alpha = np.clip((R - rho) * SS, 0, 1) * 255
globe = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8), "RGBA").resize((n // SS, n // SS), Image.LANCZOS)

# ---- the picture -------------------------------------------------------------------------------------------
base = np.empty((H, W, 3), np.float32)
base[:] = (6, 8, 24)
vy = (np.arange(H, dtype=np.float32) / H - 0.5) * 2
vx = (np.arange(W, dtype=np.float32) / W - 0.5) * 2
base *= (1 - 0.22 * (0.5 * vx[None, :] ** 2 + 0.5 * vy[:, None] ** 2))[:, :, None]
base += np.random.default_rng(29).normal(0, 1.1, (H, W, 1)).astype(np.float32)
img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).convert("RGBA")
img = add_stars(img, horizon=1.5, glow_x=0.5, glow=0.0, count=1700)
air = Cutout()      # a thin shell of air glowing round the globe
air.ellipse(CX, CY, R + 10, R + 10)
img = air.lay(img, (70, 104, 196), 0.5, blur=26)
img.alpha_composite(globe, (int(round(CX - globe.width / 2)), int(round(CY - globe.height / 2))))


def project(lat, lon):
    """A place on the Earth, as a point of the picture; None if it is on the far side."""
    p, l = math.radians(lat), math.radians(lon)
    if math.sin(phi0) * math.sin(p) + math.cos(phi0) * math.cos(p) * math.cos(l - lam0) < 0.03:
        return None
    return (CX + R * math.cos(p) * math.sin(l - lam0),
            CY - R * (math.cos(phi0) * math.sin(p) - math.sin(phi0) * math.cos(p) * math.cos(l - lam0)))


# the deadline: where the sunset line stood at midnight in Greenwich, dashed
dash = Cutout()
seen = [project(lat, lon) for lat, lon in line_deadline]
seen = [p for p in seen if p]
for k in range(0, len(seen) - 3, 6):
    dash.stroke(seen[k:k + 4], 3.0)
img = dash.lay(img, CREAM, 0.9)

# the first place, as a light with two rings
fx, fy = project(*FIRST)
light = Cutout()
light.ellipse(fx, fy, 9, 9)
img = light.lay(img, GOLD, 0.9, blur=22)
img = light.lay(img, (255, 250, 232))
rings = Cutout()
rings.arc(fx, fy, 24, 0, 360, 2.2)
rings.arc(fx, fy, 42, 0, 360, 1.4)
img = rings.lay(img, (255, 244, 214), 0.85)

# two places to find one's way by
marks = Cutout()
for place in (ALASKA, HAWAII):
    px_, py_ = project(*place)
    marks.ellipse(px_, py_, 5, 5)
img = marks.lay(img, CREAM, 0.6, blur=6)
img = marks.lay(img, CREAM)

save(img, out / "s15b_turkiye_globe.jpg")
img.convert("RGB").resize((1280, 720), Image.LANCZOS).save(out / "s15b_turkiye_globe_small.jpg", quality=90)


def inches(point):
    return [round(point[0] / W * 13.333, 3), round(point[1] / H * 7.5, 3)]


def on_line(line, lat):
    return inches(project(*min(line, key=lambda p: abs(p[0] - lat))))


hours, minutes = int(T_FIRST - 24), int(round((T_FIRST - 24 - int(T_FIRST - 24)) * 60))
points = {
    "first": inches((fx, fy)), "first_place": {"latitude": FIRST[0], "longitude": FIRST[1], "utc_on_the_18th": f"{hours:02d}:{minutes:02d}"},
    "alaska": inches(project(*ALASKA)), "hawaii": inches(project(*HAWAII)),
    "deadline_line": {str(lat): on_line(line_deadline, lat) for lat in (45, 30, 10, -10, -30)},
    "sunset_line": {str(lat): on_line(line_first, lat) for lat in (40, -10, -30, -45)},
    "globe": {"centre": inches((CX, CY)), "radius": round(R / W * 13.333, 3)},
    "sun": {"declination": round(DEC, 2), "over_longitude": round(SUN_LON, 2), "misfit_degrees": round(misfit, 3)},
}
(out / "s15b_globe_points.json").write_text(json.dumps(points, indent=1))
print("wrote", out / "s15b_turkiye_globe.jpg")
print(json.dumps(points))
