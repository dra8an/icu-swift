"""Give every slide of a .pptx a fade transition (pptxgenjs cannot write transitions).

Usage: python3 add_fade.py <in.pptx> <out.pptx>
A slide that already has a transition is left alone.
"""
import re
import sys
import zipfile

src, dst = sys.argv[1], sys.argv[2]
FADE = '<p:transition spd="slow"><p:fade/></p:transition>'
slide = re.compile(r"^ppt/slides/slide\d+\.xml$")
changed = 0
with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        data = zin.read(item.filename)
        if slide.match(item.filename):
            text = data.decode("utf-8")
            if "<p:transition" not in text:
                # The transition belongs after the colour-map override (or the slide content if there is none).
                for anchor in ("</p:clrMapOvr>", "</p:cSld>"):
                    if anchor in text:
                        text = text.replace(anchor, anchor + FADE, 1)
                        changed += 1
                        break
            data = text.encode("utf-8")
        zout.writestr(item, data)
print(f"fade added to {changed} slide(s): {dst}")
