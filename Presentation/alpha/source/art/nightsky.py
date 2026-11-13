"""Drawing tools for the deck's pictures: one night sky, stars, a thin moon, land cut-outs, a child.

Everything is drawn here with Pillow and numpy; no photograph or outside picture is used.
Sizes are in pixels of a 2560 x 1440 picture. Cut-outs are drawn at twice that size and scaled
down, which gives them smooth edges.
"""
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 2560, 1440
SS = 2

CREAM = (246, 238, 221)
MOONLIGHT = (255, 245, 218)
NEAR = (4, 5, 12)    # the nearest land, almost black
MID = (9, 11, 26)    # land a little further away
FAR = (17, 18, 44)   # the furthest ridge, lifted by haze

# The sky from the top of the picture (0.0) down to the horizon (1.0).
SKY_STOPS = [
    (0.00, (4, 6, 20)),
    (0.35, (8, 13, 38)),
    (0.62, (17, 24, 66)),
    (0.80, (40, 36, 92)),
    (0.90, (92, 56, 104)),
    (0.96, (176, 92, 84)),
    (1.00, (236, 150, 92)),
    (1.25, (120, 70, 60)),
]


def sky(horizon=0.875, glow_x=0.6, glow=1.0, seed=29, stops=None):
    """The sky as a picture. horizon: where the land line sits (share of the height);
    glow_x: where the sun went down (share of the width); glow: how strong the afterglow is."""
    yh = horizon * H
    y = np.arange(H, dtype=np.float32)
    x = np.arange(W, dtype=np.float32)
    t = np.clip(y / yh, 0, 1.25)
    stops = stops or SKY_STOPS
    ts = [s[0] for s in stops]
    img = np.empty((H, W, 3), np.float32)
    for c in range(3):
        img[:, :, c] = np.interp(t, ts, [s[1][c] for s in stops])[:, None]
    # The afterglow: a wide warm spread and a tighter bright heart where the sun went down.
    wide = np.exp(-(((x - glow_x * W) / (0.42 * W))[None, :] ** 2 + ((y - yh) / (0.20 * H))[:, None] ** 2) * 1.6)
    core = np.exp(-(((x - glow_x * W) / (0.12 * W))[None, :] ** 2 + ((y - yh) / (0.06 * H))[:, None] ** 2) * 1.5)
    img += (wide * glow)[:, :, None] * np.array([96, 50, 14], np.float32)
    img += (core * glow)[:, :, None] * np.array([30, 24, 12], np.float32)
    # Darker corners draw the eye inwards.
    vx = (x / W - 0.5) * 2
    vy = (y / H - 0.5) * 2
    img *= (1 - 0.20 * (0.6 * vx[None, :] ** 2 + 0.4 * vy[:, None] ** 2))[:, :, None]
    # A little grain so the smooth sky does not break into bands.
    img += np.random.default_rng(seed).normal(0, 1.3, (H, W, 1)).astype(np.float32)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert("RGBA")


def add_stars(img, horizon=0.875, glow_x=0.6, glow=1.0, count=1500, seed=7):
    """The same stars on every picture (same seed), thinning out towards the horizon and the afterglow."""
    rng = random.Random(seed)
    yh = horizon * H
    small = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    bright = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    ds, db = ImageDraw.Draw(small), ImageDraw.Draw(bright)
    for _ in range(count):
        # Every star draws the same random numbers whatever happens to it, so the field never shifts.
        sx, sy = rng.uniform(0, W), rng.uniform(0, H)
        keep, size, shine, tint = rng.random(), rng.random(), rng.random(), rng.random()
        depth = sy / yh
        if depth >= 0.97 or keep < depth ** 1.3:
            continue
        near_glow = math.exp(-(((sx - glow_x * W) / (0.42 * W)) ** 2 + ((sy - yh) / (0.20 * H)) ** 2) * 1.6) * glow
        if near_glow > 0.45:
            continue
        r = 0.55 + 1.5 * size ** 4
        a = int((70 + 185 * shine ** 2) * (1 - 0.75 * depth ** 2) * (1 - near_glow))
        color = (255, 250, 236) if tint < 0.6 else ((226, 234, 255) if tint < 0.85 else (255, 232, 205))
        ds.ellipse([(sx - r) * SS, (sy - r) * SS, (sx + r) * SS, (sy + r) * SS], fill=color + (a,))
        if size > 0.93 and shine > 0.5:
            rb = r * 2.6
            db.ellipse([(sx - rb) * SS, (sy - rb) * SS, (sx + rb) * SS, (sy + rb) * SS], fill=color + (110,))
    bright = bright.filter(ImageFilter.GaussianBlur(5 * SS))
    for layer in (bright, small):
        img = Image.alpha_composite(img, layer.resize((W, H), Image.LANCZOS))
    return img


def _stamp(img, mask, color, strength=1.0):
    """Lay a colour over the picture through a grey mask."""
    if strength != 1.0:
        mask = mask.point(lambda v: int(v * strength))
    return Image.composite(Image.new("RGBA", img.size, color + (255,)), img, mask)


def add_moon(img, cx, cy, r, lit=0.03, toward=90.0, earthshine=0.0, glow=0.5):
    """A moon of radius r. lit: the lit share of the disc (0.03 is a very thin crescent);
    toward: the direction from the moon to the sun in degrees (0 = right, 90 = straight down);
    earthshine: how much of the dark part shows, 0 to 1."""
    ss = 6
    n = int((r + 3) * 2 * ss)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    px = (xx - n / 2 + 0.5) / ss
    py = (yy - n / 2 + 0.5) / ss
    a = math.radians(toward)
    u = px * math.cos(a) + py * math.sin(a)
    v = -px * math.sin(a) + py * math.cos(a)
    inside = (u * u + v * v) <= r * r
    edge = (1 - 2 * lit) * np.sqrt(np.clip(r * r - v * v, 0, None))
    size = (n // ss, n // ss)
    lit_patch = Image.fromarray(((inside & (u >= edge)) * 255).astype(np.uint8)).resize(size, Image.BOX)
    disc_patch = Image.fromarray((inside * 255).astype(np.uint8)).resize(size, Image.BOX)
    corner = (int(round(cx - size[0] / 2)), int(round(cy - size[1] / 2)))
    lit_mask = Image.new("L", img.size, 0)
    lit_mask.paste(lit_patch, corner)
    if earthshine > 0:
        disc_mask = Image.new("L", img.size, 0)
        disc_mask.paste(disc_patch, corner)
        img = _stamp(img, disc_mask, (118, 130, 168), earthshine)
    if glow > 0:
        img = _stamp(img, lit_mask.filter(ImageFilter.GaussianBlur(max(2.0, r * 0.45))), (255, 232, 190), glow)
    return _stamp(img, lit_mask, MOONLIGHT)


def add_ring(img, cx, cy, r, dashes=30, width=2.0, strength=0.5, color=CREAM):
    """A fine dashed circle: the place in the sky where the moon is, or would be."""
    mask = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(mask)
    step = 360.0 / dashes
    box = [(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS]
    for i in range(dashes):
        d.arc(box, i * step, i * step + step * 0.5, fill=255, width=max(1, int(round(width * SS))))
    return _stamp(img, mask.resize((W, H), Image.LANCZOS), color, strength)


def smooth(points, per_segment=24):
    """A smooth line through the given points (Catmull-Rom)."""
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for s in range(per_segment):
            t = s / per_segment
            out.append(tuple(
                0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t * t
                       + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t ** 3)
                for k in (0, 1)))
    out.append(points[-1])
    return out


def height_at(line, x):
    """The height of a land line at a given x."""
    for (x0, y0), (x1, y1) in zip(line, line[1:]):
        if x0 <= x <= x1 and x1 > x0:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return line[-1][1]


class Cutout:
    """A black-paper cut-out: draw shapes into it, then lay it on the picture in one colour."""

    def __init__(self):
        self.mask = Image.new("L", (W * SS, H * SS), 0)
        self.d = ImageDraw.Draw(self.mask)

    def poly(self, pts):
        self.d.polygon([(x * SS, y * SS) for x, y in pts], fill=255)

    def rect(self, x0, y0, x1, y1):
        self.d.rectangle([x0 * SS, y0 * SS, x1 * SS, y1 * SS], fill=255)

    def ellipse(self, cx, cy, rx, ry):
        self.d.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=255)

    def limb(self, pts, width):
        """A thick line with round ends and joints: an arm, a leg."""
        self.d.line([(x * SS, y * SS) for x, y in pts], fill=255, width=int(round(width * SS)), joint="curve")
        for x, y in pts:
            self.ellipse(x, y, width / 2, width / 2)

    def land(self, line):
        """Everything below a land line."""
        self.poly(list(line) + [(W + 40, H + 40), (-40, H + 40)])

    def stroke(self, pts, width):
        """A line of even width with round ends."""
        self.limb(pts, width)

    def arc(self, cx, cy, r, start, end, width):
        self.d.arc([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], start, end, fill=255,
                   width=max(1, int(round(width * SS))))

    def hole(self, cx, cy, rx, ry):
        """Cut an oval opening back out of the paper."""
        self.d.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=0)

    def lay(self, img, color, strength=1.0, blur=0.0):
        mask = self.mask.resize((W, H), Image.LANCZOS)
        if blur:
            mask = mask.filter(ImageFilter.GaussianBlur(blur))
        return _stamp(img, mask, color, strength)


def minaret(cut, x, base, height, width=7.0):
    """A slim tower with a balcony and a pointed cap."""
    top = base - height
    cut.rect(x - width / 2, top, x + width / 2, base)
    cut.rect(x - width * 0.95, top + height * 0.26, x + width * 0.95, top + height * 0.26 + 3.5)
    cut.poly([(x - width * 0.62, top), (x + width * 0.62, top), (x, top - width * 2.6)])
    cut.rect(x - 0.7, top - width * 3.6, x + 0.7, top - width * 2.4)


def dome(cut, x, base, radius):
    """A dome on a low drum, with a small finial."""
    cut.rect(x - radius * 1.05, base - radius * 0.35, x + radius * 1.05, base)
    cut.ellipse(x, base - radius * 0.35, radius, radius)
    cut.rect(x - 0.8, base - radius * 1.75, x + 0.8, base - radius * 1.3)


def houses(cut, x0, x1, base_line, seed, low=8, high=30):
    """A huddle of flat-roofed houses standing on a land line."""
    rng = random.Random(seed)
    x = x0
    while x < x1:
        w = rng.uniform(14, 40)
        h = rng.uniform(low, high)
        base = height_at(base_line, x + w / 2)
        cut.rect(x, base - h, x + w, base + 12)
        if rng.random() < 0.25:
            cut.rect(x + w * 0.3, base - h - rng.uniform(4, 9), x + w * 0.6, base - h)
        x += w + rng.uniform(-4, 6)


def child(cut, x, feet, h, pointing=False):
    """A child in profile, facing right, head tipped back to look at the sky, hands behind the back
    (or one arm raised to point). x, feet: where the child stands; h: the child's height."""
    def p(dx, dy):
        return (x + dx * h, feet + dy * h)

    # legs and shoes, one foot a little ahead of the other
    for hip, foot in ((-0.035, -0.055), (0.03, 0.04)):
        cut.limb([p(hip, -0.40), p(foot, -0.04)], 0.072 * h)
        cut.ellipse(x + (foot + 0.03) * h, feet - 0.017 * h, 0.06 * h, 0.024 * h)
    # a coat that widens towards the hem
    cut.poly(smooth([p(-0.03, -0.80), p(-0.092, -0.75), p(-0.112, -0.58), p(-0.162, -0.345)], 8)
             + smooth([p(0.132, -0.345), p(0.09, -0.58), p(0.078, -0.75), p(0.03, -0.80)], 8))
    # arms: hands held behind the back, or one arm raised
    cut.limb([p(-0.03, -0.74), p(-0.128, -0.615), p(-0.142, -0.505)], 0.05 * h)
    if pointing:
        cut.limb([p(0.03, -0.745), p(0.15, -0.80), p(0.285, -0.905)], 0.05 * h)
    # neck, and a head tipped back
    cut.limb([p(0.0, -0.79), p(-0.01, -0.845)], 0.062 * h)
    hx, hy = x - 0.014 * h, feet - 0.897 * h
    cut.ellipse(hx, hy, 0.088 * h, 0.094 * h)
    look = math.radians(-36)   # the face points up and to the right

    def on_head(angle, reach):
        return (hx + math.cos(angle) * reach * h, hy + math.sin(angle) * reach * h)

    cut.poly([on_head(look - 0.30, 0.086), on_head(look - 0.04, 0.110), on_head(look + 0.28, 0.088)])   # nose
    cut.poly([on_head(look + 0.62, 0.086), on_head(look + 0.86, 0.104), on_head(look + 1.15, 0.088)])   # chin
    # hair: fuller at the back of the head
    cut.ellipse(hx - 0.022 * h, hy - 0.012 * h, 0.09 * h, 0.098 * h)
    # a scarf round the neck, its end lifted by the evening wind
    cut.limb([p(-0.045, -0.795), p(0.04, -0.80)], 0.04 * h)
    top = smooth([p(-0.03, -0.815), p(-0.14, -0.80), p(-0.24, -0.762), p(-0.335, -0.778)], 8)
    under = smooth([p(-0.33, -0.742), p(-0.24, -0.728), p(-0.14, -0.762), p(-0.03, -0.775)], 8)
    cut.poly(top + under)


def roughen(line, amp, seed, rough=0.6):
    """Turn a smooth land line into a rocky one."""
    rng = random.Random(seed)
    ys = [0.0, 0.0]
    scale = 1.0
    while len(ys) < len(line):
        nxt = []
        for a, b in zip(ys, ys[1:]):
            nxt += [a, (a + b) / 2 + rng.uniform(-1, 1) * scale]
        nxt.append(ys[-1])
        ys, scale = nxt, scale * rough
    return [(x, y + amp * ys[int(i * (len(ys) - 1) / max(1, len(line) - 1))]) for i, (x, y) in enumerate(line)]


def add_lights(img, line, x0, x1, count, seed, rise=24, color=(255, 206, 140)):
    """Lit windows scattered through a town that stands on a land line."""
    rng = random.Random(seed)
    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(count):
        lx = rng.uniform(x0, x1)
        ly = height_at(line, lx) - rng.uniform(-6, rise)
        r = rng.uniform(0.9, 1.7)
        d.ellipse([(lx - r) * SS, (ly - r) * SS, (lx + r) * SS, (ly + r) * SS], fill=color + (rng.randint(130, 235),))
    soft = layer.filter(ImageFilter.GaussianBlur(2.5 * SS))
    for part in (soft, layer):
        img = Image.alpha_composite(img, part.resize((W, H), Image.LANCZOS))
    return img


def grass(cut, line, x0, x1, seed, every=9.0):
    """Short blades along the top of a hill."""
    rng = random.Random(seed)
    x = x0
    while x < x1:
        base = height_at(line, x)
        lean = rng.uniform(-3.5, 3.5)
        tall = rng.uniform(4, 13)
        cut.poly([(x - 1.6, base + 3), (x + 1.6, base + 3), (x + lean, base - tall)])
        x += rng.uniform(every * 0.4, every * 1.6)


def save(img, path):
    # Quality 97: at 92 the dark sky showed faint 8-pixel block edges (measured 2026-11-12); at 97 they are gone.
    img.convert("RGB").save(path, quality=97, subsampling=0, optimize=True)


# ---- more things to draw (added for the full deck) --------------------------------------------------

COLD_STOPS = [(0.00, (4, 7, 22)), (0.40, (10, 20, 52)), (0.70, (24, 44, 88)), (0.90, (58, 92, 136)),
              (1.00, (112, 150, 186)), (1.25, (40, 62, 96))]


def add_disc(img, cx, cy, r, color=(255, 228, 176), glow=0.6, spread=None):
    """A bright disc with a soft halo: the sun."""
    cut = Cutout()
    cut.ellipse(cx, cy, r, r)
    if glow > 0:
        img = cut.lay(img, color, glow, blur=spread or r * 1.1)
    return cut.lay(img, color)


def add_glow_dots(img, dots, color, radius=3.0, halo=7.0, strength=1.0):
    """Small glowing lights: lanterns, lit windows seen from afar."""
    cut = Cutout()
    for x, y in dots:
        cut.ellipse(x, y, radius, radius)
    img = cut.lay(img, color, 0.75 * strength, blur=halo)
    return cut.lay(img, color, strength)


def add_window(img, x, y, w, h, color):
    """One lit window, with its light spilling a little."""
    cut = Cutout()
    cut.rect(x, y, x + w, y + h)
    img = cut.lay(img, color, 0.8, blur=max(w, h) * 0.9)
    return cut.lay(img, color)


def palm(cut, x, base, h, lean=0.12, seed=0):
    """A palm: a slightly bent trunk and drooping fronds."""
    rng = random.Random(seed)
    top = (x + lean * h, base - h)
    cut.limb(smooth([(x, base + 4), (x + lean * h * 0.3, base - h * 0.5), top], 8), h * 0.042)
    for angle in (-168, -138, -108, -80, -52, -22, 8, 196):
        a = math.radians(angle + rng.uniform(-6, 6))
        reach = h * rng.uniform(0.34, 0.44)
        tip = (top[0] + math.cos(a) * reach, top[1] + math.sin(a) * reach * 0.55 + reach * 0.42)
        mid = (top[0] + math.cos(a) * reach * 0.55, top[1] + math.sin(a) * reach * 0.62 - reach * 0.05)
        frond = smooth([top, mid, tip], 7)
        cut.limb(frond, h * 0.022)
        for fx, fy in frond[2::2]:
            cut.poly([(fx - 2.2, fy), (fx + 2.2, fy), (fx + rng.uniform(-3, 3), fy + h * 0.07)])


def person(cut, x, feet, h, pointing=None):
    """A grown-up in a long robe or coat. pointing: -1 points up to the left, 1 up to the right."""
    cut.ellipse(x, feet - 0.925 * h, 0.062 * h, 0.07 * h)
    cut.poly([(x - 0.05 * h, feet - 0.85 * h), (x + 0.05 * h, feet - 0.85 * h), (x + 0.125 * h, feet - 0.80 * h),
              (x + 0.14 * h, feet - 0.02 * h), (x - 0.14 * h, feet - 0.02 * h), (x - 0.125 * h, feet - 0.80 * h)])
    cut.ellipse(x - 0.06 * h, feet - 0.012 * h, 0.06 * h, 0.022 * h)
    cut.ellipse(x + 0.06 * h, feet - 0.012 * h, 0.06 * h, 0.022 * h)
    if pointing:
        cut.limb([(x + pointing * 0.10 * h, feet - 0.78 * h), (x + pointing * 0.24 * h, feet - 0.86 * h),
                  (x + pointing * 0.38 * h, feet - 0.98 * h)], 0.05 * h)


def telescope(cut, x, feet, h, aim=32, facing=1):
    """A telescope on a tripod, tube raised towards the sky."""
    pivot = (x, feet - 0.62 * h)
    for foot in (-0.24, 0.05, 0.24):
        cut.stroke([pivot, (x + foot * h, feet)], 0.035 * h)
    a = math.radians(aim)
    dx, dy = math.cos(a) * facing, -math.sin(a)
    cut.stroke([(pivot[0] - dx * 0.26 * h, pivot[1] - dy * 0.26 * h), (pivot[0] + dx * 0.40 * h, pivot[1] + dy * 0.40 * h)],
               0.10 * h)
    cut.stroke([(pivot[0] - dx * 0.34 * h, pivot[1] - dy * 0.34 * h), (pivot[0] - dx * 0.26 * h, pivot[1] - dy * 0.26 * h)],
               0.06 * h)


def ottoman_mosque(cut, x, base, s=1.0):
    """A great domed mosque: a main dome, half-domes stepping down, and slim minarets."""
    cut.rect(x - 118 * s, base - 46 * s, x + 118 * s, base + 6)
    for side in (-1, 1):
        cut.ellipse(x + side * 72 * s, base - 46 * s, 46 * s, 40 * s)
        cut.ellipse(x + side * 112 * s, base - 40 * s, 20 * s, 20 * s)
    cut.rect(x - 60 * s, base - 84 * s, x + 60 * s, base - 40 * s)
    cut.ellipse(x, base - 84 * s, 60 * s, 54 * s)
    cut.rect(x - 1.2 * s, base - 156 * s, x + 1.2 * s, base - 136 * s)
    for dx, tall in ((-150, 218), (150, 218), (-100, 176), (100, 176)):
        minaret(cut, x + dx * s, base, tall * s, width=6.5 * s)


def square_minaret(cut, x, base, w, h):
    """A square tower with a small lantern and a finial, as in the far west of the Islamic world."""
    cut.rect(x - w / 2, base - h, x + w / 2, base + 4)
    for i in range(5):
        tx = x - w / 2 + i * w / 4.5
        cut.rect(tx, base - h - w * 0.12, tx + w * 0.12, base - h)
    cut.rect(x - w * 0.24, base - h - w * 0.62, x + w * 0.24, base - h)
    cut.ellipse(x, base - h - w * 0.62, w * 0.24, w * 0.2)
    cut.rect(x - 1.0, base - h - w * 1.25, x + 1.0, base - h - w * 0.7)
    for k in range(3):
        cut.ellipse(x, base - h - w * (0.9 + 0.13 * k), 3.2 - 0.7 * k, 3.2 - 0.7 * k)


def pyramid(cut, x, base, w):
    cut.poly([(x - w / 2, base + 4), (x + w / 2, base + 4), (x, base - w * 0.62)])


def westminster_tower(cut, x, base, s=1.0):
    """A tall clock tower with a pointed roof."""
    cut.rect(x - 11 * s, base - 150 * s, x + 11 * s, base + 4)
    cut.rect(x - 13.5 * s, base - 180 * s, x + 13.5 * s, base - 150 * s)
    cut.poly([(x - 13.5 * s, base - 180 * s), (x + 13.5 * s, base - 180 * s), (x + 6 * s, base - 204 * s),
              (x - 6 * s, base - 204 * s)])
    cut.rect(x - 6 * s, base - 214 * s, x + 6 * s, base - 204 * s)
    cut.poly([(x - 6 * s, base - 214 * s), (x + 6 * s, base - 214 * s), (x, base - 250 * s)])


def terrace(cut, x0, x1, base_line, seed, wide=(54, 72), tall=(46, 64)):
    """A row of pitched-roof houses with chimneys. Returns each house as (left, top of wall, width, wall height)."""
    rng = random.Random(seed)
    out, x = [], x0
    while x < x1:
        w = rng.uniform(*wide)
        wall = rng.uniform(*tall)
        base = height_at(base_line, x + w / 2)
        cut.rect(x, base - wall, x + w, base + 12)
        cut.poly([(x - 2, base - wall), (x + w + 2, base - wall), (x + w / 2, base - wall - w * 0.34)])
        cx = x + w * rng.choice((0.2, 0.78))
        cut.rect(cx - 5, base - wall - w * 0.34 - 6, cx + 5, base - wall)
        cut.rect(cx - 6.5, base - wall - w * 0.34 - 9, cx + 6.5, base - wall - w * 0.34 - 6)
        out.append((x, base - wall, w, wall))
        x += w
    return out


def tower_block(cut, x, base, w, h, crown=0):
    """A tall city tower. crown: 0 flat, 1 stepped, 2 with a spire."""
    cut.rect(x - w / 2, base - h, x + w / 2, base + 6)
    if crown >= 1:
        cut.rect(x - w * 0.3, base - h - w * 0.35, x + w * 0.3, base - h)
    if crown >= 2:
        cut.rect(x - 1.2, base - h - w * 1.3, x + 1.2, base - h - w * 0.35)


def eye_sign(cut, x, y, s=1.0, width=3.4):
    """A simple line drawing of an eye."""
    cut.stroke(smooth([(x - 62 * s, y), (x, y - 36 * s), (x + 62 * s, y)], 14), width)
    cut.stroke(smooth([(x - 62 * s, y), (x, y + 36 * s), (x + 62 * s, y)], 14), width)
    cut.arc(x, y, 21 * s, 0, 360, width)
    cut.ellipse(x, y, 8 * s, 8 * s)


def dividers_sign(cut, x, y, s=1.0, width=3.4):
    """A pair of dividers, the old tool for measuring on a chart."""
    top = (x, y - 58 * s)
    cut.stroke([top, (x - 34 * s, y + 58 * s)], width)
    cut.stroke([top, (x + 34 * s, y + 58 * s)], width)
    cut.ellipse(top[0], top[1], 7 * s, 7 * s)
    cut.arc(top[0], top[1], 74 * s, 66, 114, width)
