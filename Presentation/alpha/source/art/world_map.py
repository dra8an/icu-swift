"""The world on the evening of 17 February 2026, drawn from our own calculation.

Usage: python art/world_map.py <grid.csv> <ne_10m_land.geojson> <output folder>
Writes three maps (2560 x 1440, each with a small copy) and s09_map_points.json (where the places and the
lines sit, in inches on a 13.333 x 7.5 slide, for the labels). All three share one base: the sea coloured by
how many hours had passed since the new moon when the sun set at each place (night where the moon was not yet new).

  s09_map            the sunset line when the moon was new and every three hours after, and an arrow pointing west;
  s15b_turkiye_map   the line where the sun set at midnight in Greenwich, and the gold patch where the moon stood
                     at least 5 degrees high and 8 degrees from the sun;
  s19_answers        the places of the story as lights in two colours, Wednesday and Thursday.
The coastline is Natural Earth (public domain).
"""
import csv
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from nightsky import CREAM, H, SS, W, save

grid_csv, land_json, out = sys.argv[1], sys.argv[2], Path(sys.argv[3])
out.mkdir(parents=True, exist_ok=True)

# The window: from the date line in the Pacific east to 130 E. East of that nothing in the story happens,
# and leaving it out makes the map a fifth larger.
LON_LEFT, LON_RIGHT = -180.0, 130.0
LAT_TOP, LAT_BOTTOM = 70.0, -58.0
PX_PER_DEG = W / (LON_RIGHT - LON_LEFT)
MAP_H = int(round((LAT_TOP - LAT_BOTTOM) * PX_PER_DEG))
MAP_TOP = H - MAP_H - 40
EDGE = 150   # the map fades out over this many pixels at its top and bottom

OCEAN = (7, 10, 28)
LAND_LIGHT = (150, 165, 225)
GOLD = (240, 196, 138)
# Hours since the new moon at local sunset, drawn in the colours of the deck's dusk sky.
RAMP = [(0.00, OCEAN), (0.10, (22, 20, 58)), (0.30, (52, 36, 92)), (0.55, (104, 54, 98)), (0.80, (170, 84, 84)),
        (1.00, (222, 132, 88))]

PLACES = [("Singapore", 1.29, 103.63), ("Malaysia", 3.14, 101.69), ("Indonesia", -6.21, 106.85),
          ("Pakistan", 34.02, 71.52), ("Mecca", 21.42, 39.83), ("Egypt", 30.04, 31.24), ("Türkiye", 39.93, 32.86),
          ("London", 51.51, -0.13), ("Morocco", 34.02, -6.84)]


def px(lon, lat):
    return ((lon - LON_LEFT) * PX_PER_DEG, MAP_TOP + (LAT_TOP - lat) * PX_PER_DEG)


# ---- the grid from the engine ------------------------------------------------------------------------
rows = list(csv.DictReader(open(grid_csv)))
lats = sorted({int(r["latitude"]) for r in rows})
lons = sorted({int(r["longitude"]) for r in rows})


def field(key):
    a = np.full((len(lats), len(lons)), 0.0, np.float32)
    for r in rows:
        if r[key] != "":
            a[int(r["latitude"]) - lats[0], int(r["longitude"]) - lons[0]] = float(r[key])
    # keep the rows from LAT_TOP down to LAT_BOTTOM, north at the top, and stretch them over the map
    a = a[int(LAT_BOTTOM) - lats[0]: int(LAT_TOP) - lats[0] + 1, int(LON_LEFT) - lons[0]: int(LON_RIGHT) - lons[0] + 1][::-1]
    return np.asarray(Image.fromarray(a).resize((W, MAP_H), Image.BICUBIC))


sunset, age = field("sunset_utc_h"), field("age_h")
alt_seen, alt_topo, elong = field("alt_apparent"), field("alt_topocentric"), field("elong_geocentric")
moon_up = alt_topo + 34.0 / 60 + 0.26          # at or above zero: the moon's upper edge is still up at sunset
turkiye = np.minimum(alt_seen - 5.0, elong - 8.0)   # at or above zero: both of Türkiye's numbers are met

# ---- the picture ---------------------------------------------------------------------------------------
fade = np.ones(MAP_H, np.float32)
fade[:EDGE] = np.linspace(0, 1, EDGE) ** 1.5
fade[-EDGE:] = np.linspace(1, 0, EDGE) ** 1.5


def on_map(mask_small, strength=1.0):
    """Place a map-sized mask on the full picture, fading out at the top and bottom edges of the map."""
    a = (np.asarray(mask_small).astype(np.float32) * fade[:, None] * strength).astype(np.uint8)
    full = Image.new("L", (W, H), 0)
    full.paste(Image.fromarray(a), (0, MAP_TOP))
    return full


def lay(image, mask_small, color, strength=1.0):
    return Image.composite(Image.new("RGBA", (W, H), color + (255,)), image, on_map(mask_small, strength))


# the sea: night, warming westwards with the hours since the new moon
moved = np.clip(age / 19.0, 0, 1)
ts = [t for t, _ in RAMP]
sea = np.stack([np.interp(moved, ts, [c[k] for _, c in RAMP]) for k in range(3)], axis=2).astype(np.float32)
base = np.empty((H, W, 3), np.float32)
base[:] = OCEAN
band = base[MAP_TOP:MAP_TOP + MAP_H]
band += (sea - band) * fade[:, None, None]
yy = (np.arange(H, dtype=np.float32) / H - 0.5) * 2
xx = (np.arange(W, dtype=np.float32) / W - 0.5) * 2
base *= (1 - 0.16 * (0.5 * xx[None, :] ** 2 + 0.5 * yy[:, None] ** 2))[:, :, None]
base += np.random.default_rng(29).normal(0, 1.1, (H, W, 1)).astype(np.float32)
img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).convert("RGBA")

# land, cut from the coastline and laid on as a light veil, so it is a little lighter than the sea everywhere
land = Image.new("L", (W * SS, MAP_H * SS), 0)
d = ImageDraw.Draw(land)
for feature in json.load(open(land_json))["features"]:
    g = feature["geometry"]
    polygons = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
    for polygon in polygons:
        for k, ring in enumerate(polygon):
            pts = [((lon - LON_LEFT) * PX_PER_DEG * SS, (LAT_TOP - lat) * PX_PER_DEG * SS) for lon, lat in ring]
            if len(pts) >= 3:
                d.polygon(pts, fill=255 if k == 0 else 0)
land = land.resize((W, MAP_H), Image.LANCZOS)
img = lay(img, land, LAND_LIGHT, 0.17)

plain = img.copy()   # the world with nothing drawn on it yet; all three maps start from here


def crossing_line(values, target):
    """For every row of the map, the x where a field that falls towards the east crosses a value."""
    pts = []
    for y in range(EDGE // 3, MAP_H - EDGE // 3, 3):
        row = values[y] - target
        idx = np.where((row[:-1] >= 0) & (row[1:] < 0))[0]
        if len(idx):
            x = idx[-1]
            point = (x + row[x] / (row[x] - row[x + 1]), MAP_TOP + y)
            if pts and abs(point[0] - pts[-1][0]) > 40:   # a jump: the line has left the map's sensible part
                if len(pts) < 30:
                    pts = [point]
                    continue
                break
            pts.append(point)
    return pts


def stroke(image, pts, width=2.2, strength=0.8, color=CREAM, with_map_fade=True, head=None):
    """A line on the picture. head: the three corners of an arrowhead, if the line is an arrow."""
    mask = Image.new("L", (W * SS, H * SS), 0)
    dm = ImageDraw.Draw(mask)
    dm.line([(x * SS, y * SS) for x, y in pts], fill=255, width=int(round(width * SS)), joint="curve")
    if head:
        dm.polygon([(x * SS, y * SS) for x, y in head], fill=255)
    m = np.asarray(mask.resize((W, H), Image.LANCZOS)).astype(np.float32) * strength
    if with_map_fade:
        full_fade = np.zeros(H, np.float32)
        full_fade[MAP_TOP:MAP_TOP + MAP_H] = fade
        m *= full_fade[:, None]
    return Image.composite(Image.new("RGBA", (W, H), color + (255,)), image, Image.fromarray(m.astype(np.uint8)))


def with_dots(image, spots, color=CREAM, r=6, halo=7):
    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    dl = ImageDraw.Draw(layer)
    for x, y in spots:
        dl.ellipse([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS], fill=color + (255,))
    soft = layer.filter(ImageFilter.GaussianBlur(halo * SS))
    for part in (soft, soft, layer):
        image = Image.alpha_composite(image, part.resize((W, H), Image.LANCZOS))
    return image


def finish(image, name):
    save(image, out / f"{name}.jpg")
    image.convert("RGB").resize((1280, 720), Image.LANCZOS).save(out / f"{name}_small.jpg", quality=90)
    print("wrote", out / f"{name}.jpg")


first = next(r for r in rows if r["age_h"] != "")
new_moon = float(first["sunset_utc_h"]) - float(first["age_h"])   # hours after 17 Feb 00:00 UTC (12.02)

# ---- map 1: sunset travels west ----------------------------------------------------------------------------
# One idea only: the sunset line, drawn when the moon was new and then every three hours, and an arrow.
AGES = (0, 3, 6, 9, 12, 15)
age_lines = {hours: crossing_line(sunset, new_moon + hours) for hours in AGES}
sweep = plain
for hours, line in age_lines.items():
    sweep = stroke(sweep, line, width=2.6 if hours == 0 else 1.8, strength=0.95 if hours == 0 else 0.6)
ARROW_Y = MAP_TOP + 52
sweep = stroke(sweep, [(2340, ARROW_Y), (250, ARROW_Y)], width=2.4, strength=0.8, with_map_fade=False,
               head=[(214, ARROW_Y), (262, ARROW_Y - 13), (262, ARROW_Y + 13)])
sweep = with_dots(sweep, [px(lon, lat) for _, lat, lon in PLACES])
finish(sweep, "s09_map")

# ---- map 2: Türkiye's rule -----------------------------------------------------------------------------------
# The line where the sun was setting at midnight in Greenwich, and the one patch where 5 and 8 degrees were met.
ALASKA = (54.85, -163.38)   # the best point of the American mainland that evening (fact sheet, section 2)
zone = Image.fromarray(((turkiye >= 0) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))
rule = lay(plain, zone, GOLD, 0.5)
rim = Image.fromarray(np.clip(np.asarray(zone.filter(ImageFilter.MaxFilter(7)), np.int16) - np.asarray(zone, np.int16),
                              0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
rule = lay(rule, rim.point(lambda v: min(255, int(v * 1.6))), (255, 226, 176))
midnight_line = crossing_line(sunset, 24.0)
rule = stroke(rule, midnight_line, width=2.8, strength=0.95)
ankara = next(px(lon, lat) for name, lat, lon in PLACES if name == "Türkiye")
rule = with_dots(rule, [ankara, px(ALASKA[1], ALASKA[0])])
finish(rule, "s15b_turkiye_map")

# ---- map 3: who began on which day -------------------------------------------------------------------------
WEDNESDAY, THURSDAY = (232, 185, 135), (169, 196, 232)
ANSWERS = {"Singapore": "T", "Malaysia": "T", "Indonesia": "WT", "Pakistan": "T", "Mecca": "W", "Egypt": "T",
           "Türkiye": "T", "London": "WT", "Morocco": "T"}
answers = plain
for letter, color in (("W", WEDNESDAY), ("T", THURSDAY)):
    spots = []
    for name, lat, lon in PLACES:
        if letter in ANSWERS[name]:
            x, y = px(lon, lat)
            if ANSWERS[name] == "WT":       # two answers in one place: two lights side by side
                x += -11 if letter == "W" else 11
            spots.append((x, y))
    answers = with_dots(answers, spots, color=color, r=10, halo=11)
finish(answers, "s19_answers")


def inches(point):
    return [round(point[0] / W * 13.333, 3), round(point[1] / H * 7.5, 3)]


def at_lat(line, lat):
    y = px(0, lat)[1]
    return inches(min(line, key=lambda p: abs(p[1] - y)))


zone_px = np.argwhere(turkiye >= 0)
points = {
    "places": {name: inches(px(lon, lat)) for name, lat, lon in PLACES},
    "age_lines": {str(hours): {"north": at_lat(line, 52), "south": at_lat(line, -38)} for hours, line in age_lines.items()},
    "midnight_line": {str(lat): at_lat(midnight_line, lat) for lat in (40, 20, 0, -20, -38)},
    "gold_zone_right_edge": inches((float(zone_px[:, 1].max()), MAP_TOP + float(zone_px[:, 0].mean()))),
    "alaska": inches(px(ALASKA[1], ALASKA[0])),
    "map_top_bottom": [round(MAP_TOP / H * 7.5, 3), round((MAP_TOP + MAP_H) / H * 7.5, 3)],
}
(out / "s09_map_points.json").write_text(json.dumps(points, indent=1, ensure_ascii=False))
print(json.dumps(points, ensure_ascii=False))
