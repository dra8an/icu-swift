"""Every picture of the deck except the two maps (those are art/world_map.py).

Usage: python art/scenes.py <output folder> [picture names ...]
With no names it draws all of them. Each picture is written as sNN_name.jpg (2560 x 1440) with a small
copy (suffix _small); contact sheets of the small copies are written as sheet_1.jpg, sheet_2.jpg, ...

The numbers follow the slides. Every picture is drawn here; nothing is taken from anywhere else.
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image

from nightsky import (COLD_STOPS, CREAM, FAR, H, MID, NEAR, W, Cutout, add_disc, add_glow_dots, add_lights, add_moon,
                      add_ring, add_stars, add_window, child, dividers_sign, dome, eye_sign, grass, height_at, houses,
                      minaret, ottoman_mosque, palm, person, pyramid, roughen, save, sky, smooth, square_minaret,
                      telescope, terrace, tower_block, westminster_tower)

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)

SEA = (20, 21, 52)
GOLD = (232, 185, 135)   # Wednesday
BLUE = (169, 196, 232)   # Thursday
WARM = (255, 206, 140)


def night(horizon, glow_x, glow, stars=1500, stops=None):
    img = sky(horizon, glow_x, glow, stops=stops)
    return add_stars(img, horizon, glow_x, glow, count=stars) if stars else img


def flat(y, wobble=8.0, seed=1, n=9):
    """A nearly level land line right across the picture."""
    rng = random.Random(seed)
    return smooth([(-40 + (W + 80) * i / (n - 1), y + rng.uniform(-wobble, wobble)) for i in range(n)])


def cover(img, line, color):
    cut = Cutout()
    cut.land(line)
    return cut.lay(img, color)


def setting_sun(img, x, horizon_y, r=44):
    """The sun with only its upper half still above the horizon (the land or sea drawn later hides the rest)."""
    return add_disc(img, x, horizon_y + 6, r, glow=0.5, spread=r * 1.4)


def sea_at_sunset(img, y, sun_x, moon_x):
    """The sea, a soft path of light under the sun, and below the horizon the ring of a moon that has already set."""
    img = cover(img, flat(y, 0), SEA)
    path = Cutout()
    path.ellipse(sun_x, y + 74, 26, 78)
    img = path.lay(img, (255, 186, 120), 0.42, blur=22)
    return add_ring(img, moon_x, y + 62, 40, dashes=24, strength=0.7)


def dashes(img, x0, x1, y, strength=0.5, on=22, off=16, width=2.0):
    cut = Cutout()
    x = x0
    while x < x1:
        cut.stroke([(x, y), (min(x + on, x1), y)], width)
        x += on + off
    return cut.lay(img, CREAM, strength)


# ---- Part 1: the sky -------------------------------------------------------------------------------------

def far_town(img, far_line):
    far = Cutout()
    far.land(far_line)
    houses(far, 1740, 2360, far_line, seed=3, low=8, high=24)
    dome(far, 2040, height_at(far_line, 2040) - 12, 26)
    minaret(far, 1978, height_at(far_line, 1978), 100)
    minaret(far, 2104, height_at(far_line, 2104), 86)
    img = far.lay(img, FAR)
    return add_lights(img, far_line, 1750, 2350, 18, seed=4, rise=15)


TITLE_FAR = [(-40, 1262), (300, 1250), (700, 1268), (1100, 1258), (1500, 1270), (1900, 1256), (2250, 1264), (2600, 1258)]
TITLE_HILL = [(-40, 1330), (200, 1262), (480, 1196), (740, 1168), (1000, 1196), (1400, 1280), (1900, 1352), (2600, 1400)]


def hill_with_child(img, pointing=False):
    hill = smooth(TITLE_HILL)
    near = Cutout()
    near.land(hill)
    grass(near, hill, 40, 1560, seed=11)
    child(near, 760, height_at(hill, 760) + 4, 236, pointing=pointing)
    return near.lay(img, NEAR)


def s01_title():
    """A child on a hill at dusk; a small town far away; no moon yet."""
    img = night(0.875, 0.70, 0.9)
    img = far_town(img, smooth(TITLE_FAR))
    return hill_with_child(img)


def s02_clock():
    """The moon's shapes in an arc across the sky, thin to full to thin."""
    img = night(0.88, 0.5, 0.55)
    lit = [0.04, 0.25, 0.5, 0.78, 1.0, 0.78, 0.5, 0.25, 0.04]
    for i, share in enumerate(lit):
        a = math.radians(213 + i * 114 / 8)
        x, y = 1280 + 835 * math.cos(a), 1535 + 835 * math.sin(a)
        img = add_moon(img, x, y, 40, lit=share, toward=0 if i < 4 else 180, earthshine=0.0 if share == 1.0 else 0.2, glow=0.3)
    img = cover(img, flat(1278, 8, seed=2), FAR)
    near_line = smooth([(-40, 1340), (500, 1318), (1100, 1346), (1700, 1322), (2200, 1348), (2600, 1332)])
    near = Cutout()
    near.land(near_line)
    grass(near, near_line, 0, 2560, seed=6, every=14)
    return near.lay(img, NEAR)


def s03_hides():
    """The sun low in the sky; right beside it, only a fine ring where the moon is."""
    img = night(0.86, 0.46, 1.15, stars=900)
    sun_x, sun_y, r = 1180, 1060, 78
    # The sun must not be mistaken for a moon: rays, a wide warm glow, and a whiter heart than any moon in the deck.
    rays = Cutout()
    for k in range(20):
        a = math.radians(k * 18 + 4)
        reach = 300 if k % 2 == 0 else 210
        ca, sa = math.cos(a), math.sin(a)
        rays.poly([(sun_x + ca * (r + 16) - sa * 7, sun_y + sa * (r + 16) + ca * 7),
                   (sun_x + ca * (r + 16) + sa * 7, sun_y + sa * (r + 16) - ca * 7),
                   (sun_x + ca * reach, sun_y + sa * reach)])
    img = rays.lay(img, (255, 214, 150), 0.42, blur=5)
    halo = Cutout()
    halo.ellipse(sun_x, sun_y, r * 1.5, r * 1.5)
    img = halo.lay(img, (255, 196, 120), 0.6, blur=150)
    img = add_disc(img, sun_x, sun_y, r, color=(255, 246, 214), glow=0.85, spread=70)
    # The moon, the same size, right beside the sun and inside its glare: only a fine ring says where.
    img = add_ring(img, sun_x + 2 * r + 26, sun_y - 8, r - 2, dashes=34, width=2.4, strength=0.85)
    img = cover(img, flat(1246, 7, seed=3), FAR)
    near_line = smooth([(-40, 1322), (500, 1296), (1100, 1326), (1700, 1300), (2200, 1328), (2600, 1312)])
    near = Cutout()
    near.land(near_line)
    grass(near, near_line, 0, 2560, seed=5, every=14)
    return near.lay(img, NEAR)


def s04_crescent():
    """The child points; a hair-thin crescent stands in the afterglow."""
    img = night(0.875, 0.70, 0.9)
    img = add_moon(img, 1560, 730, 44, lit=0.055, toward=68, earthshine=0.18, glow=0.5)
    img = far_town(img, smooth(TITLE_FAR))
    return hill_with_child(img, pointing=True)


def s05_days():
    """Twenty-nine small lights in a row, and a thirtieth that is only a ring."""
    img = night(0.86, 0.5, 0.8)
    xs = [330 + i * (1900 / 29) for i in range(30)]
    img = add_glow_dots(img, [(x, 1010) for x in xs[:29]], WARM, radius=8, halo=16)
    img = add_ring(img, xs[29], 1010, 13, dashes=12, width=2.0, strength=0.75)
    img = cover(img, flat(1246, 7, seed=3), FAR)
    near_line = smooth([(-40, 1318), (500, 1292), (1100, 1322), (1700, 1298), (2200, 1326), (2600, 1310)])
    near = Cutout()
    near.land(near_line)
    grass(near, near_line, 0, 2560, seed=5, every=14)
    return near.lay(img, NEAR)


# ---- Part 2: the question ----------------------------------------------------------------------------------

def s06_question():
    """Only sky and horizon, and a fine ring where the moon might be."""
    img = night(0.86, 0.5, 1.0)
    img = cover(img, smooth([(-40, 1246), (400, 1232), (800, 1244), (1280, 1236), (1700, 1246), (2150, 1230), (2600, 1242)]), FAR)
    near_line = smooth([(-40, 1318), (500, 1292), (1100, 1322), (1700, 1298), (2200, 1326), (2600, 1310)])
    near = Cutout()
    near.land(near_line)
    grass(near, near_line, 0, 2560, seed=5, every=14)
    img = near.lay(img, NEAR)
    return add_ring(img, 1700, 1030, 46, strength=0.62)


def s07_who():
    """Three signs in the sky: an eye, a pair of dividers, and the two together."""
    img = night(0.87, 0.5, 0.6)
    signs = Cutout()
    eye_sign(signs, 560, 770, s=1.7, width=4.2)
    dividers_sign(signs, 1280, 770, s=1.7, width=4.2)
    eye_sign(signs, 1880, 770, s=1.05, width=3.6)
    dividers_sign(signs, 2110, 770, s=1.05, width=3.6)
    img = signs.lay(img, CREAM, 0.92)
    img = cover(img, flat(1262, 7, seed=4), FAR)
    return cover(img, smooth([(-40, 1332), (500, 1306), (1100, 1338), (1700, 1312), (2200, 1340), (2600, 1324)]), NEAR)


# ---- Part 3: one real evening ------------------------------------------------------------------------------

def s08_eclipse():
    """A ring of fire low over the ice."""
    img = night(0.80, 0.5, 0.0, stars=500, stops=COLD_STOPS)
    img = add_disc(img, 1840, 800, 98, color=(255, 224, 164), glow=0.8, spread=80)
    moon = Cutout()
    moon.ellipse(1840, 800, 89, 89)
    img = moon.lay(img, (9, 14, 36))
    shelf = Cutout()   # a far ice shelf with a level top
    shelf.land(roughen(flat(1150, 3, seed=7, n=14), 5, seed=8, rough=0.75))
    img = shelf.lay(img, (92, 122, 168))
    img = cover(img, flat(1196, 0, seed=1), (10, 18, 44))   # the sea
    bergs = Cutout()
    for x, w, h in ((520, 300, 96), (1180, 210, 62), (2060, 340, 110)):
        top = roughen(smooth([(x, 1210), (x + w * 0.12, 1210 - h), (x + w * 0.55, 1210 - h * 0.92), (x + w * 0.86, 1210 - h * 0.62),
                              (x + w, 1210)], 10), 5, seed=int(x), rough=0.7)
        bergs.poly(top + [(x + w, 1232), (x, 1232)])
    img = bergs.lay(img, (176, 200, 228))
    near = Cutout()
    near.land(roughen(smooth([(-40, 1318), (500, 1296), (1100, 1330), (1700, 1304), (2200, 1334), (2600, 1316)], 20), 5, seed=9))
    return near.lay(img, (104, 132, 172))


def s10_singapore():
    """City towers by the water. The sun is half down; the moon's ring has already sunk."""
    horizon, y = 0.86, 1238
    img = night(horizon, 0.70, 1.05)
    img = setting_sun(img, 1792, y)
    img = sea_at_sunset(img, y, 1792, 1610)
    city = Cutout()
    rng = random.Random(21)
    towers = []
    x = 250
    while x < 1330:
        w, h = rng.uniform(40, 84), rng.uniform(110, 330)
        tower_block(city, x + w / 2, y, w, h, crown=rng.choice((0, 0, 1, 2)))
        towers.append((x, y - h, w, h))
        x += w + rng.uniform(4, 30)
    for tx in (2010, 2072, 2134):          # three towers carrying one long roof deck
        tower_block(city, tx, y, 36, 196)
        towers.append((tx - 18, y - 196, 36, 196))
    city.poly(smooth([(1962, y - 196), (2010, y - 206), (2072, y - 210), (2134, y - 206), (2186, y - 196)], 6)
              + [(2186, y - 188), (1962, y - 188)])
    city.arc(2360, y - 84, 76, 0, 360, 3.0)   # a big wheel
    for k in range(8):
        a = math.radians(k * 22.5)
        city.stroke([(2360 - 76 * math.cos(a), y - 84 - 76 * math.sin(a)), (2360 + 76 * math.cos(a), y - 84 + 76 * math.sin(a))], 1.2)
    city.poly([(2360, y - 84), (2330, y + 4), (2390, y + 4)])
    city.rect(-40, y - 14, 1340, y + 8)
    city.rect(1930, y - 12, 2600, y + 8)
    img = city.lay(img, MID)
    lights = []
    for tx, ty, w, h in towers:
        for _ in range(int(w * h / 420)):
            lights.append((tx + rng.uniform(4, w - 4), ty + rng.uniform(8, h - 6)))
    img = add_glow_dots(img, lights, WARM, radius=1.3, halo=3.0, strength=0.85)
    return cover(img, smooth([(-40, 1392), (700, 1376), (1500, 1396), (2600, 1382)]), NEAR)


def s11_malaysia():
    """A headland above the sea, with watchers and their telescopes."""
    horizon, y = 0.86, 1238
    img = night(horizon, 0.64, 1.05)
    img = setting_sun(img, 1638, y)
    isles = Cutout()
    isles.poly(smooth([(1960, y + 4), (2040, y - 26), (2150, y - 40), (2260, y - 22), (2330, y + 4)], 8))
    isles.poly(smooth([(2380, y + 4), (2440, y - 16), (2520, y - 22), (2600, y - 10)], 8) + [(2600, y + 4)])
    img = isles.lay(img, FAR)
    img = sea_at_sunset(img, y, 1638, 1470)
    head = roughen(smooth([(-40, 1176), (300, 1120), (620, 1094), (900, 1100), (1060, 1140), (1170, 1250), (1250, 1400),
                           (1300, 1500)], 16), 5, seed=12, rough=0.7)
    cape = Cutout()
    cape.land(head)
    grass(cape, head, 0, 1040, seed=14, every=11)
    for tx in (470, 660, 850):
        telescope(cape, tx, height_at(head, tx) + 3, 104, aim=24)
    for px, tall, point in ((396, 108, None), (566, 104, 1), (752, 110, None), (948, 100, None)):
        person(cape, px, height_at(head, px) + 3, tall, pointing=point)
    return cape.lay(img, NEAR)


def s12_indonesia():
    """An island shore: palms, a mosque, a far volcano, and two lit windows of different colours."""
    horizon, y = 0.86, 1238
    img = night(horizon, 0.66, 1.05)
    img = setting_sun(img, 1690, y)
    far = Cutout()
    far.poly(smooth([(1830, y + 4), (1990, 1136), (2090, 1052), (2128, 1040), (2172, 1050), (2280, 1136), (2470, y + 4)], 10))
    far.poly(smooth([(2380, y + 4), (2470, y - 20), (2600, y - 30)], 6) + [(2600, y + 4)])
    img = far.lay(img, FAR)
    img = sea_at_sunset(img, y, 1690, 1530)
    shore = smooth([(-40, 1208), (400, 1196), (800, 1212), (1080, 1236), (1220, 1272), (1300, 1400), (1320, 1500)], 16)
    land = Cutout()
    land.land(shore)
    houses(land, 150, 1000, shore, seed=31, low=20, high=44)
    dome(land, 520, height_at(shore, 520) - 30, 40)
    minaret(land, 612, height_at(shore, 612), 150)
    for px, tall, lean, seed in ((90, 190, 0.10, 1), (260, 220, -0.08, 2), (770, 200, 0.14, 3), (930, 170, -0.10, 4), (1060, 150, 0.16, 5)):
        palm(land, px, height_at(shore, px), tall, lean=lean, seed=seed)
    img = land.lay(img, MID)
    img = add_window(img, 356, height_at(shore, 356) - 24, 12, 14, GOLD)
    img = add_window(img, 842, height_at(shore, 842) - 26, 12, 14, BLUE)
    beach = smooth([(-40, 1338), (600, 1306), (1200, 1348), (1800, 1392), (2600, 1410)])
    near = Cutout()
    near.land(beach)
    palm(near, 2240, height_at(beach, 2240), 420, lean=-0.16, seed=8)
    palm(near, 2420, height_at(beach, 2420), 340, lean=0.10, seed=9)
    return near.lay(img, NEAR)


MECCA_RIDGE = [(-40, 1150), (250, 1098), (520, 1132), (800, 1062), (1050, 1112), (1350, 1088), (1600, 1140), (1766, 1128),
               (1950, 1118), (2200, 1086), (2600, 1130)]


def mecca_sky():
    img = night(0.84, 0.69, 1.05)
    img = cover(img, roughen(smooth(MECCA_RIDGE, 40), 13, seed=21, rough=0.8), FAR)
    img = add_ring(img, 1800, 1066, 50, dashes=34, strength=0.42)
    return add_moon(img, 1800, 1066, 23, lit=0.034, toward=105, earthshine=0.0, glow=0.4)


def clock_tower(cut, x, base, s=1.0):
    """A tall stepped tower with a spire, flanked by two lower ones."""
    cut.rect(x - 104 * s, base - 46 * s, x + 104 * s, base + 10)
    cut.rect(x - 50 * s, base - 78 * s, x + 50 * s, base)
    for dx in (-76, 76):
        cut.rect(x + (dx - 13) * s, base - 118 * s, x + (dx + 13) * s, base)
        cut.poly([(x + (dx - 13) * s, base - 118 * s), (x + (dx + 13) * s, base - 118 * s), (x + dx * s, base - 140 * s)])
    cut.rect(x - 22 * s, base - 192 * s, x + 22 * s, base)
    cut.rect(x - 27 * s, base - 236 * s, x + 27 * s, base - 192 * s)
    cut.poly([(x - 21 * s, base - 236 * s), (x + 21 * s, base - 236 * s), (x + 5 * s, base - 268 * s), (x - 5 * s, base - 268 * s)])
    cut.rect(x - 2.0 * s, base - 306 * s, x + 2.0 * s, base - 268 * s)
    cut.ellipse(x, base - 310 * s, 4.5 * s, 4.5 * s)


def s13_mecca():
    """Hills, a city of minarets, the sun just gone, and the thinnest moon following it down."""
    img = mecca_sky()
    town_line = smooth([(-40, 1236), (400, 1222), (900, 1238), (1400, 1226), (2000, 1240), (2600, 1230)])
    town = Cutout()
    town.land(town_line)
    houses(town, -20, 2580, town_line, seed=17, low=10, high=34)
    clock_tower(town, 930, height_at(town_line, 930), 0.9)
    for x, tall in ((380, 104), (470, 104), (1420, 118), (1512, 118), (2130, 96), (2210, 96)):
        minaret(town, x, height_at(town_line, x), tall)
    dome(town, 1466, height_at(town_line, 1466) - 14, 30)
    img = town.lay(img, MID)
    img = add_lights(img, town_line, 0, 2560, 170, seed=9, rise=26)
    return cover(img, smooth([(-40, 1334), (500, 1306), (1100, 1342), (1700, 1314), (2600, 1352)]), NEAR)


def s14_saudi_looks():
    """The same hills and the same thin moon; on a rise, people watching with a telescope."""
    img = mecca_sky()
    rise = roughen(smooth([(-40, 1262), (260, 1200), (560, 1158), (840, 1172), (1100, 1236), (1420, 1304), (1900, 1350),
                           (2600, 1372)], 20), 5, seed=33, rough=0.7)
    near = Cutout()
    near.land(rise)
    for px, tall, point in ((450, 124, 1), (580, 116, None), (700, 120, None)):
        person(near, px, height_at(rise, px) + 3, tall, pointing=point)
    telescope(near, 836, height_at(rise, 836) + 3, 112, aim=18)
    return near.lay(img, NEAR)


def s15_turkiye():
    """Night over a city of domes and slim minarets by the water."""
    y = 1238
    img = night(0.86, 0.5, 0.3, stars=2300)
    hills = smooth([(-40, 1196), (500, 1150), (900, 1128), (1300, 1160), (1700, 1140), (2100, 1168), (2600, 1150)])
    city = Cutout()
    city.land(hills)
    houses(city, -20, 2580, hills, seed=41, low=10, high=30)
    ottoman_mosque(city, 880, height_at(hills, 880) + 2, 1.22)
    ottoman_mosque(city, 1700, height_at(hills, 1700) + 2, 0.8)
    gx, gb = 2160, height_at(hills, 2160)
    city.rect(gx - 24, gb - 118, gx + 24, gb + 4)
    city.rect(gx - 28, gb - 128, gx + 28, gb - 116)
    city.poly([(gx - 22, gb - 128), (gx + 22, gb - 128), (gx, gb - 190)])
    img = city.lay(img, MID)
    img = add_lights(img, hills, 0, 2560, 260, seed=42, rise=-34)
    img = cover(img, flat(1270, 0), (16, 18, 46))
    return cover(img, smooth([(-40, 1346), (700, 1318), (1500, 1352), (2600, 1328)]), NEAR)


def s16_morocco():
    """A town with a square minaret, palms, and people on a roof under a crescent anyone can see."""
    img = night(0.86, 0.62, 0.95)
    img = add_moon(img, 1840, 770, 46, lit=0.09, toward=100, earthshine=0.2, glow=0.55)
    img = cover(img, roughen(smooth([(-40, 1170), (400, 1118), (800, 1150), (1200, 1096), (1600, 1146), (2000, 1110),
                                    (2600, 1160)], 30), 10, seed=51, rough=0.75), FAR)
    town_line = smooth([(-40, 1216), (600, 1202), (1300, 1220), (2000, 1206), (2600, 1218)])
    town = Cutout()
    town.land(town_line)
    houses(town, -20, 2580, town_line, seed=52, low=20, high=58)
    square_minaret(town, 700, height_at(town_line, 700), 46, 240)
    for px, tall, lean, seed in ((1040, 170, 0.10, 11), (1130, 200, -0.08, 12), (330, 180, 0.12, 13)):
        palm(town, px, height_at(town_line, px), tall, lean=lean, seed=seed)
    img = town.lay(img, MID)
    img = add_lights(img, town_line, 0, 2560, 120, seed=53, rise=30)
    roof = Cutout()   # a flat roof with a low wall, close to us
    roof.rect(1280, 1222, 2600, 1500)
    for bx in range(1280, 2600, 110):
        roof.rect(bx, 1204, bx + 58, 1224)
    person(roof, 1500, 1224, 176, pointing=1)
    person(roof, 1640, 1224, 162)
    child(roof, 1760, 1224, 112, pointing=True)
    roof.land(smooth([(-40, 1372), (700, 1350), (1280, 1366)]) + [(1280, 1500)])
    return roof.lay(img, NEAR)


def s17_egypt():
    """The river, palms and a minaret, pyramids far off, a sail; an almost empty sky."""
    y = 1238
    img = night(0.86, 0.66, 1.0)
    img = add_ring(img, 1700, 1134, 48, dashes=32, strength=0.42)
    img = add_moon(img, 1700, 1134, 22, lit=0.03, toward=105, glow=0.35)
    far = Cutout()
    far.land(flat(y, 3, seed=61))
    pyramid(far, 2010, y, 250)
    pyramid(far, 2210, y, 180)
    pyramid(far, 2350, y, 110)
    img = far.lay(img, FAR)
    img = cover(img, flat(1254, 0), (24, 22, 56))   # the river
    bank = smooth([(-40, 1232), (500, 1222), (880, 1236), (1120, 1262), (1230, 1330), (1290, 1500)], 16)
    left = Cutout()
    left.land(bank)
    houses(left, 60, 760, bank, seed=62, low=16, high=40)
    dome(left, 330, height_at(bank, 330) - 26, 34)
    minaret(left, 420, height_at(bank, 420), 170)
    for px, tall, lean, seed in ((120, 210, 0.10, 21), (560, 230, -0.10, 22), (700, 190, 0.12, 23), (860, 170, 0.18, 24)):
        palm(left, px, height_at(bank, px), tall, lean=lean, seed=seed)
    img = left.lay(img, MID)
    boat = Cutout()   # a river boat with a tall slanted sail
    boat.poly([(1438, 1296), (1452, 1118), (1560, 1288)])
    boat.poly([(1400, 1298), (1590, 1298), (1566, 1316), (1424, 1316)])
    img = boat.lay(img, NEAR)
    reeds_line = smooth([(-40, 1372), (900, 1350), (1800, 1380), (2600, 1356)])
    reeds = Cutout()
    reeds.land(reeds_line)
    grass(reeds, reeds_line, 0, 2560, seed=63, every=7)
    return reeds.lay(img, NEAR)


def s18_london():
    """Rows of pitched roofs and chimneys, a mosque among them, a clock tower far off; two lit windows."""
    y = 1250
    img = night(0.87, 0.64, 0.85)
    img = add_ring(img, 1730, 1090, 48, dashes=32, strength=0.42)
    img = add_moon(img, 1730, 1090, 22, lit=0.034, toward=105, glow=0.35)
    far_line = flat(y, 4, seed=71)
    far = Cutout()
    far.land(far_line)
    houses(far, -20, 2580, far_line, seed=72, low=14, high=52)
    westminster_tower(far, 2230, y, 1.3)
    dome(far, 1960, y - 34, 46)
    far.rect(1900, y - 50, 2020, y + 4)
    for tx, w, h in ((300, 60, 150), (390, 44, 210), (1120, 56, 170)):
        tower_block(far, tx, y, w, h, crown=1)
    img = far.lay(img, FAR)
    street = flat(1400, 4, seed=73)
    mid = Cutout()
    dome(mid, 1400, 1400 - 150, 70)
    mid.rect(1300, 1400 - 170, 1500, 1420)
    minaret(mid, 1548, 1400, 300, width=10)
    homes = terrace(mid, -20, 2580, street, seed=74, wide=(118, 150), tall=(92, 118))
    mid.land(flat(1412, 0))
    img = mid.lay(img, MID)
    for index, color in ((2, GOLD), (5, BLUE)):
        hx, top, w, wall = homes[index]
        img = add_window(img, hx + w * 0.26, top + wall * 0.26, 30, 40, color)
    return img


def s20_alaska():
    """A cold coast of sharp mountains; a fine line at 5 degrees, and the moon resting on it."""
    y = 1238
    img = night(0.86, 0.58, 0.9)
    img = dashes(img, 1240, 2330, 930, strength=0.5)
    img = add_moon(img, 1890, 933, 30, lit=0.07, toward=100, earthshine=0.16, glow=0.5)
    peaks = roughen(smooth([(-40, 1120), (300, 1040), (520, 1104), (800, 984), (1040, 1092), (1300, 1034), (1560, 1112),
                           (1900, 1064), (2200, 1122), (2600, 1082)], 30), 26, seed=5, rough=0.8)
    img = cover(img, peaks, (22, 26, 58))
    img = cover(img, flat(y, 0), SEA)
    return cover(img, roughen(smooth([(-40, 1334), (700, 1302), (1500, 1352), (2600, 1320)], 20), 6, seed=6), NEAR)


def s21_rules():
    """Five small moons in a row above the horizon, one for each time a rule changed."""
    img = night(0.87, 0.5, 0.7)
    for i in range(5):
        img = add_moon(img, 420 + i * 430, 800, 36, lit=0.05 + 0.03 * i, toward=95, earthshine=0.16, glow=0.45)
    img = cover(img, flat(1262, 7, seed=4), FAR)
    return cover(img, smooth([(-40, 1332), (500, 1306), (1100, 1338), (1700, 1312), (2200, 1340), (2600, 1324)]), NEAR)


def s22_closing():
    """The child again, the next evening; the crescent is plain to see."""
    img = night(0.875, 0.70, 0.9)
    img = add_moon(img, 2060, 880, 54, lit=0.10, toward=75, earthshine=0.22, glow=0.55)
    img = far_town(img, smooth(TITLE_FAR))
    return hill_with_child(img)


SCENES = [s01_title, s02_clock, s03_hides, s04_crescent, s05_days, s06_question, s07_who, s08_eclipse, s10_singapore,
          s11_malaysia, s12_indonesia, s13_mecca, s14_saudi_looks, s15_turkiye, s16_morocco, s17_egypt, s18_london,
          s20_alaska, s21_rules, s22_closing]

wanted = set(sys.argv[2:])
for scene in SCENES:
    if wanted and scene.__name__ not in wanted:
        continue
    picture = scene()
    save(picture, out / f"{scene.__name__}.jpg")
    picture.convert("RGB").resize((1280, 720), Image.LANCZOS).save(out / f"{scene.__name__}_small.jpg", quality=90)
    print("wrote", scene.__name__)

# contact sheets of everything in the folder, nine to a sheet
smalls = sorted(out.glob("s[0-9][0-9]_*_small.jpg"))
for n in range(0, len(smalls), 9):
    sheet = Image.new("RGB", (1920, 1080), (0, 0, 0))
    for k, f in enumerate(smalls[n:n + 9]):
        sheet.paste(Image.open(f).resize((636, 358), Image.LANCZOS), (2 + (k % 3) * 640, 1 + (k // 3) * 360))
    sheet.save(out / f"sheet_{n // 9 + 1}.jpg", quality=88)
print("sheets:", (len(smalls) + 8) // 9)
