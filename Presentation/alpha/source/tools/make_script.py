"""The printable speaker's script, made from the deck itself.

Usage: python tools/make_script.py <deck.pptx> <folder with the Keynote renders> <out.pdf>

For every slide it prints a small picture of the slide, the words on it, what to say (the deck's speaker
notes), and the sources (the notes' last paragraph). Because it reads the deck, it can never disagree with it:
change the notes in deck/build_deck.js, rebuild, and run this again.

The times are estimates at 130 spoken words a minute.
"""
import io
import re
import sys
from pathlib import Path

from PIL import Image as PILImage
from pptx import Presentation
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import BaseDocTemplate, Frame, HRFlowable, Image, KeepTogether, PageTemplate, Paragraph, Spacer, Table, TableStyle

deck_path, render_dir, out_path = sys.argv[1], Path(sys.argv[2]), sys.argv[3]
WORDS_PER_MINUTE = 130
TITLE = "The Twenty-Ninth Evening"

# The deck's own typefaces: a bookish serif for the words to say, a clean sans for labels.
IOWAN = "/System/Library/Fonts/Supplemental/Iowan Old Style.ttc"
AVENIR = "/System/Library/Fonts/Avenir Next.ttc"
for name, path, index in (("Serif", IOWAN, 0), ("Serif-Bold", IOWAN, 1), ("Serif-Italic", IOWAN, 2),
                          ("Sans", AVENIR, 7), ("Sans-Demi", AVENIR, 2), ("Sans-Italic", AVENIR, 4)):
    pdfmetrics.registerFont(TTFont(name, path, subfontIndex=index))
pdfmetrics.registerFontFamily("Serif", normal="Serif", bold="Serif-Bold", italic="Serif-Italic", boldItalic="Serif-Bold")

INK = colors.HexColor("#1B1B24")
GREY = colors.HexColor("#6B6B78")
RULE = colors.HexColor("#D5D5DC")
WEDNESDAY = colors.HexColor("#9A6524")   # the slides' gold, darkened for white paper
THURSDAY = colors.HexColor("#2F5F9E")    # the slides' blue, darkened for white paper

style = {
    "doc_title": ParagraphStyle("doc_title", fontName="Serif", fontSize=28, leading=33, textColor=INK),
    "doc_sub": ParagraphStyle("doc_sub", fontName="Sans", fontSize=11, leading=15, textColor=GREY, spaceBefore=6),
    "doc_how": ParagraphStyle("doc_how", fontName="Serif-Italic", fontSize=11, leading=15.5, textColor=INK, spaceBefore=10),
    "number": ParagraphStyle("number", fontName="Sans-Demi", fontSize=10, leading=13, textColor=INK, spaceBefore=6),
    "time": ParagraphStyle("time", fontName="Sans", fontSize=8, leading=11, textColor=GREY),
    "kicker": ParagraphStyle("kicker", fontName="Sans", fontSize=7.5, leading=10, textColor=GREY),
    "title": ParagraphStyle("title", fontName="Serif-Bold", fontSize=13.5, leading=17, textColor=INK, spaceAfter=2),
    "shown": ParagraphStyle("shown", fontName="Sans", fontSize=8, leading=11, textColor=GREY, spaceAfter=2),
    "say": ParagraphStyle("say", fontName="Serif", fontSize=12, leading=17.5, textColor=INK, spaceBefore=6),
    "sources": ParagraphStyle("sources", fontName="Sans-Italic", fontSize=8, leading=11, textColor=GREY, spaceBefore=8),
}


def esc(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def clock(seconds):
    seconds = int(round(seconds))
    return f"{seconds // 60}:{seconds % 60:02d}"


def about(seconds):
    if seconds < 50:
        return f"about {max(10, int(round(seconds / 10) * 10))} seconds"
    halves = round(seconds / 30)          # the nearest half minute
    if halves <= 2:
        return "about a minute"
    return f"about {halves // 2}{'½' if halves % 2 else ''} minutes"


def slide_parts(slide):
    """What is on a slide and in its notes: kicker, title, other words shown, answers, what to say, sources."""
    # The deck's placeholders come in a fixed order: a kicker in capitals (if the layout has one), then the
    # title, then a subtitle (title and closing slides only). The first one not in capitals is the title.
    kicker, title, shown, answers = "", "", [], []
    for shape in slide.shapes:
        if not shape.has_text_frame:
            continue
        text = " ".join(shape.text_frame.text.split())
        if not text:
            continue
        if shape.name.startswith("Answer:"):
            answers.append(text)
        elif shape.is_placeholder and text.upper() == text:
            kicker = text
        elif shape.is_placeholder and not title:
            title = text
        elif shape.is_placeholder or shape.name in ("Caption",):
            shown.append(text)
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n|\n", slide.notes_slide.notes_text_frame.text) if p.strip()]
    say = [p for p in paragraphs if not re.match(r"(?i)sources?:", p) and not p.startswith("(")]
    sources = [p for p in paragraphs if re.match(r"(?i)sources?:", p)]
    return kicker, title, shown, answers, say, sources


def thumbnail(index, width):
    picture = PILImage.open(render_dir / f"the_twenty_ninth_evening-{index:02d}.jpg").convert("RGB").resize((640, 360), PILImage.LANCZOS)
    buffer = io.BytesIO()
    picture.save(buffer, "JPEG", quality=82)
    buffer.seek(0)
    return Image(buffer, width=width, height=width * 9 / 16)


prs = Presentation(deck_path)
slides = [slide_parts(s) for s in prs.slides]
seconds = [sum(len(re.findall(r"\w+", p)) for p in parts[4]) / WORDS_PER_MINUTE * 60 for parts in slides]
total = sum(seconds)

LEFT, RIGHT, GAP = 2.15 * inch, 4.65 * inch, 0.2 * inch
story = [
    Paragraph(TITLE, style["doc_title"]),
    Paragraph(f"Speaker's script  ·  {len(slides)} slides  ·  about {int(round(total / 60))} minutes at an unhurried pace", style["doc_sub"]),
    Paragraph("For each slide: what the audience sees, what to say, and where the facts come from. "
              "The times are a guide, counted at 130 words a minute.", style["doc_how"]),
    Spacer(1, 14),
]
started = 0.0
for number, (parts, length) in enumerate(zip(slides, seconds), start=1):
    kicker, title, shown, answers, say, sources = parts
    left = [thumbnail(number, LEFT), Paragraph(f"Slide {number}", style["number"]),
            Paragraph(f"{about(length)}  ·  starts at {clock(started)}", style["time"])]
    right = []
    if kicker:
        right.append(Paragraph(esc(kicker), style["kicker"]))
    right.append(Paragraph(esc(title), style["title"]))
    for text in shown:
        right.append(Paragraph("Also on the slide: " + esc(text), style["shown"]))
    if answers:
        marks = []
        for answer in answers:
            color = WEDNESDAY if "WEDNESDAY" in answer else THURSDAY
            marks.append(f'<font name="Sans-Demi" color="{color.hexval().replace("0x", "#")}">{esc(answer.title().replace("·", "·"))}</font>')
        right.append(Paragraph("The slide ends on:  " + "   and   ".join(marks), style["shown"]))
    right += [Paragraph(esc(p), style["say"]) for p in say]
    right += [Paragraph(esc(p), style["sources"]) for p in sources]
    block = Table([[left, right]], colWidths=[LEFT + GAP, RIGHT])
    block.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 0),
                               ("RIGHTPADDING", (0, 0), (0, 0), GAP), ("RIGHTPADDING", (1, 0), (1, 0), 0),
                               ("TOPPADDING", (0, 0), (-1, -1), 0), ("BOTTOMPADDING", (0, 0), (-1, -1), 0)]))
    story.append(KeepTogether([HRFlowable(width="100%", thickness=0.6, color=RULE, spaceBefore=4, spaceAfter=12), block, Spacer(1, 12)]))
    started += length
story.append(HRFlowable(width="100%", thickness=0.6, color=RULE, spaceBefore=4, spaceAfter=8))
story.append(Paragraph(f"End of the talk: about {clock(total)} of speaking, before any pauses or questions.", style["time"]))


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Sans", 8)
    canvas.setFillColor(GREY)
    canvas.drawString(0.75 * inch, 0.5 * inch, f"{TITLE}  ·  speaker's script")
    canvas.drawRightString(letter[0] - 0.75 * inch, 0.5 * inch, f"page {doc.page}")
    canvas.restoreState()


doc = BaseDocTemplate(out_path, pagesize=letter, leftMargin=0.75 * inch, rightMargin=0.75 * inch, topMargin=0.75 * inch,
                      bottomMargin=0.85 * inch, title=f"{TITLE}: speaker's script", author="")
frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
doc.addPageTemplates([PageTemplate(id="script", frames=[frame], onPage=footer)])
doc.build(story)
print(f"wrote {out_path}: {len(slides)} slides, {doc.page} pages, about {clock(total)} of speaking")
