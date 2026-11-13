// The Twenty-Ninth Evening: the whole deck, 24 slides (one of them a film).
//
// Usage (from anywhere; no need to change folder):
//   NODE_PATH=<build folder>/node_modules PPTX_SKILL=<folder of the PowerPoint skill> node build_deck.js
// Writes the_twenty_ninth_evening.pptx next to this file. The pictures come from art/scenes.py and
// art/world_map.py (folder deck/art). Every fact in the words and the notes is in FACT_SHEET.md.
//
// Built on a theme and a handful of layouts, so fonts and colours change in one place and all text stays
// live, editable text in Keynote or PowerPoint.
const fs = require("fs");
const path = require("path");
const pptxgen = require("pptxgenjs");
const { applyTheme } = require(path.join(process.env.PPTX_SKILL, "scripts", "apply_theme.js"));

const art = (name) => path.join(__dirname, "art", name);
const OUT = path.join(__dirname, "the_twenty_ninth_evening.pptx");
const inches = (x, y) => [(x / 2560) * 13.333, (y / 1440) * 7.5]; // a point of a picture, on the slide
const notes = (...paragraphs) => paragraphs.join("\n\n");

// Night, cream words, and two answer colours: gold for Wednesday, moonlight blue for Thursday.
//
// The theme keeps the usual meaning of its first slots: "dark 1" is plain black and "light 1" is the cream.
// Speaker notes (and anything else that uses the default text colour) take "dark 1"; if that slot held the
// cream, the notes would be cream on Keynote's white notes area, nearly invisible (this happened, 2026-11-12).
// Black also matters: Keynote shows black notes as white on its dark presenter display, other colours as they are.
// So the words on the slides ask for the cream by name: C.background1 (cream) and C.background2 (quieter).
const THEME = {
  name: "Twenty-Ninth Evening",
  headFontFace: "Iowan Old Style",
  bodyFontFace: "Avenir Next",
  colors: {
    dk1: "000000", // default text: the speaker notes
    lt1: "F6EEDD", // the words on the slides (cream)
    dk2: "070A1C", // the night behind the pictures
    lt2: "BDB9C9", // quieter words
    accent1: "E8B987", accent2: "A9C4E8", accent3: "D9774F", accent4: "6A4B8C", accent5: "8FA3C8", accent6: "F2D9A0",
    hlink: "E8B987", folHlink: "A9C4E8",
  },
};

(async () => {
  const pres = new pptxgen();
  pres.layout = "LAYOUT_WIDE"; // 13.333 x 7.5 inches
  pres.title = "The Twenty-Ninth Evening";
  pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
  const C = pres.SchemeColor;
  const night = { color: THEME.colors.dk2 };
  const ph = (name, type, o) => ({ placeholder: { options: { name, type, margin: 0, ...o }, text: "" } });

  pres.defineSlideMaster({ title: "Title", background: night, objects: [
    ph("title", "title", { x: 5.25, y: 1.2, w: 7.4, h: 2.3, fontSize: 58, color: C.background1, align: "left", valign: "bottom" }),
    ph("subtitle", "body", { x: 5.25, y: 3.72, w: 6.3, h: 1.1, fontSize: 20, color: C.background2, align: "left", valign: "top" }),
  ] });
  pres.defineSlideMaster({ title: "Story", background: night, objects: [
    ph("title", "title", { x: 0.9, y: 1.0, w: 10.8, h: 1.9, fontSize: 44, color: C.background1, align: "left", valign: "top" }),
  ] });
  pres.defineSlideMaster({ title: "Centre", background: night, objects: [
    ph("title", "title", { x: 0.67, y: 2.3, w: 12.0, h: 1.5, fontSize: 54, color: C.background1, align: "center", valign: "top" }),
  ] });
  pres.defineSlideMaster({ title: "Question", background: night, objects: [
    ph("kicker", "body", { x: 1.67, y: 2.0, w: 10.0, h: 0.5, fontSize: 16, color: C.accent1, align: "center", valign: "middle" }),
    ph("title", "title", { x: 0.67, y: 2.6, w: 12.0, h: 1.4, fontSize: 56, color: C.background1, align: "center", valign: "top" }),
  ] });
  pres.defineSlideMaster({ title: "Place", background: night, objects: [
    ph("kicker", "body", { x: 0.9, y: 1.0, w: 10.6, h: 0.45, fontSize: 15, color: C.accent1, align: "left", valign: "middle" }),
    ph("title", "title", { x: 0.9, y: 1.6, w: 9.8, h: 1.9, fontSize: 40, color: C.background1, align: "left", valign: "top" }),
  ] });
  pres.defineSlideMaster({ title: "Map", background: night, objects: [
    ph("kicker", "body", { x: 0.9, y: 0.42, w: 11.5, h: 0.4, fontSize: 14, color: C.accent1, align: "left", valign: "middle" }),
    ph("title", "title", { x: 0.9, y: 0.82, w: 11.5, h: 0.75, fontSize: 34, color: C.background1, align: "left", valign: "top" }),
  ] });

  // ---- small builders -------------------------------------------------------------------------------------
  let section = "";
  const slide = (layout, picture) => {
    const s = pres.addSlide({ masterName: layout, sectionTitle: section });
    s.background = { path: art(picture) };
    return s;
  };
  const lines = (list) => list.map((text, i) => ({ text, options: { breakLine: i < list.length - 1 } }));
  // The answer a place slide ends on: a rounded outline with the day inside, gold or blue.
  const stamp = (s, text, day, x, y) => {
    const color = day === "W" ? C.accent1 : C.accent2;
    const w = 0.7 + 0.2 * text.length; // letter-spaced capitals: about a fifth of an inch each
    s.addShape(pres.ShapeType.roundRect, {
      x, y, w, h: 0.52, rectRadius: 0.26, objectName: `Answer outline: ${text}`,
      fill: { color: THEME.colors.dk2, transparency: 100 }, line: { color, width: 1 },
    });
    s.addText(text, {
      x, y, w, h: 0.52, fontSize: 14, charSpacing: 6, color, align: "center", valign: "middle",
      margin: 0, isTextBox: true, objectName: `Answer: ${text}`,
    });
  };
  // A small label beside something in the picture. side: "left", "right" or "centre" of the point.
  const label = (s, text, x, y, side = "right", o = {}) => {
    const w = o.w || 2.2, h = o.h || 0.3, gap = o.gap === undefined ? 0.13 : o.gap;
    s.addText(text, {
      x: side === "left" ? x - gap - w : side === "centre" ? x - w / 2 : x + gap, y: y - h / 2, w, h,
      fontSize: o.size || 12, italic: o.italic !== false, color: o.color || C.background1,
      align: side === "left" ? "right" : side === "centre" ? "center" : "left", valign: "middle",
      margin: 0, isTextBox: true, objectName: o.name || `Label: ${text}`,
    });
  };
  const placeSlide = (picture, kicker, titleLines, stamps, stampY) => {
    const s = slide("Place", picture);
    s.addText(kicker, { placeholder: "kicker", charSpacing: 5 });
    s.addText(lines(titleLines), { placeholder: "title" });
    stamps.forEach(([text, day], i) => stamp(s, text, day, 0.9, stampY + i * 0.68));
    return s;
  };

  // ---- Part 1: the sky ----------------------------------------------------------------------------------
  section = "The sky";
  pres.addSection({ title: section });

  let s = slide("Title", "s01_title.jpg");
  s.addText("The Twenty-Ninth Evening", { placeholder: "title" });
  s.addText("How one thin moon starts a month, and why the world does not agree when", { placeholder: "subtitle" });
  s.addNotes(notes(
    "Welcome. This is a story about one thin moon, and about one evening in every month when somebody has to decide something.",
    "(No facts on this slide.)"));

  s = slide("Story", "s02_clock.jpg");
  s.addText("The moon is a clock everyone can see.", { placeholder: "title" });
  s.addNotes(notes(
    "One turn of this clock is one month. From one new moon to the next takes about 29 and a half days.",
    "The Islamic calendar counts its months by this clock alone. Twelve such months make a year of about 354 days, eleven days shorter than the year of the seasons. That is why Ramadan arrives about eleven days earlier every year.",
    "Source: NASA, \"Moon Phases\" (the cycle repeats every 29.5 days); NASA's eclipse pages give the average as 29.53 days, with single months between 29.26 and 29.80 days."));

  s = slide("Story", "s03_hides.jpg");
  s.addText("Once a month, the moon hides.", { placeholder: "title" });
  label(s, "the sun", ...inches(1180 - 78, 1060), "left", { w: 1.2, gap: 0.5 });
  label(s, "the moon, lost in the glare", ...inches(1180 + 2 * 78 + 26 + 76, 1052), "right", { w: 2.6, gap: 0.2 });
  s.addNotes(notes(
    "Once in every turn the moon passes right next to the sun, as we see it, and is lost in the glare. That moment is called the new moon. Nobody can see it.",
    "On this slide the bright disc with the rays is the sun. The fine ring beside it marks where the moon is: there, but not to be seen. You will meet that ring again."));

  s = slide("Story", "s04_crescent.jpg");
  s.addText("Then a thin crescent, just after sunset.", { placeholder: "title" });
  s.addNotes(notes(
    "About a day later the moon has moved a little away from the sun, roughly half a degree every hour. Just after sunset a thin crescent shows low in the west, for a short while, before it sets too.",
    "When that first crescent can be seen, the new month begins. That is the old rule, and everything in this talk grows out of it."));

  s = slide("Centre", "s05_days.jpg");
  s.addText("29 or 30 days. Never anything else.", { placeholder: "title" });
  label(s, "1", ...inches(330, 1010 + 44), "centre", { w: 0.5, italic: false });
  label(s, "29", ...inches(330 + 28 * (1900 / 29), 1010 + 44), "centre", { w: 0.5, italic: false });
  label(s, "30?", ...inches(330 + 29 * (1900 / 29) + 26, 1010 + 44), "centre", { w: 0.6, italic: false, color: C.accent1 });
  s.addNotes(notes(
    "Twenty-nine and a half days cannot be a month, because half a day cannot be a day. So the months take turns: some have 29 days, some have 30.",
    "Which of the two a month will have is not known until its 29th evening.",
    "Source: every calendar authority in this talk states that a month has 29 or 30 days and nothing else."));

  // ---- Part 2: the question -----------------------------------------------------------------------------
  section = "The question";
  pres.addSection({ title: section });

  s = slide("Question", "s06_question.jpg");
  s.addText("DAY 29 · SUNSET", { placeholder: "kicker", charSpacing: 6 });
  s.addText("Tomorrow: day 1, or day 30?", { placeholder: "title" });
  s.addNotes(notes(
    "This is the whole story. On the evening of day 29, at sunset, someone has to answer one question: is tomorrow day 1 of the new month, or day 30 of the old one?",
    "The question is asked once. If the answer is no, the old month gets its 30th day and the new month starts the day after. Nobody looks again on day 30.",
    "Source: every calendar authority in this talk says so in its own rules (Türkiye, Saudi Arabia, Malaysia, Indonesia, Singapore, Egypt)."));

  s = slide("Story", "s07_who.jpg");
  s.addText("Who answers?", { placeholder: "title" });
  [["Some look.", 560], ["Some calculate.", 1280], ["Some do both.", 1995]].forEach(([text, x]) =>
    label(s, text, ...inches(x, 960), "centre", { w: 3.4, h: 0.5, size: 22, italic: false, name: `Caption: ${text}` }));
  s.addNotes(notes(
    "In some countries people go out and look for the crescent, and what the witnesses see decides.",
    "Some calculate where the moon will be, and so they know the answer years ahead.",
    "Some do both: they print a calculated calendar, and still go out and look for the months that matter most.",
    "And in some places nobody answers for everyone. Let us watch all of them answer on one real evening."));

  // ---- Part 3: one real evening -------------------------------------------------------------------------
  section = "One real evening";
  pres.addSection({ title: section });

  s = placeSlide("s08_eclipse.jpg", "TUESDAY 17 FEBRUARY 2026 · 12:01 UNIVERSAL TIME",
    ["The moon passes the sun.", "Over Antarctica, the sun becomes a ring."], [], 0);
  s.addNotes(notes(
    "The new moon before Ramadan of the year 1447 came on Tuesday 17 February 2026, at 12:01 Universal Time.",
    "This time the moon passed exactly in front of the sun. From Antarctica the sun was seen as a ring of fire; from the far south of South America and of Africa as a sun with a bite taken out. It is the one kind of day when you can see where the new moon is.",
    "That same evening was day 29 of the month before Ramadan in much of the Muslim world.",
    "Sources: NASA's eclipse pages (an annular eclipse, greatest at 12:12 Universal Time). The time of the new moon was calculated for this talk; Türkiye's religious authority prints the same time."));

  const map = JSON.parse(fs.readFileSync(art("s09_map_points.json"), "utf8"));
  // Where each place's name sits beside its light: side, and a small step up or down where places crowd.
  const beside = { London: ["right", 0], Morocco: ["left", 0], Egypt: ["left", 0], "Türkiye": ["left", 0], Mecca: ["left", 0],
    Pakistan: ["left", 0], Malaysia: ["right", -0.2], Singapore: ["right", 0.03], Indonesia: ["right", 0.2] };
  const placeLabels = (target, only) => {
    for (const [name, [x, y]] of Object.entries(map.places)) {
      if (only && !only.includes(name)) continue;
      const [side, step] = beside[name];
      label(target, name, x, y + step, side, { w: 1.5, h: 0.28, gap: 0.18, italic: false, name: `Place: ${name}` });
    }
  };
  s = slide("Map", "s09_map.jpg");
  s.addText("TUESDAY 17 FEBRUARY 2026", { placeholder: "kicker", charSpacing: 4 });
  s.addText("Sunset travels west. Everyone gets one look.", { placeholder: "title" });
  s.addText("Each line is the sunset, three hours later than the last. Further west, the moon is older.", {
    x: 0.9, y: 1.42, w: 11.5, h: 0.36, fontSize: 15, color: C.background2, align: "left", valign: "middle", margin: 0,
    isTextBox: true, objectName: "Caption",
  });
  placeLabels(s);
  const ageWords = { 0: "the moon is new", 3: "3 hours old", 6: "6 hours old", 9: "9 hours old", 12: "12 hours old", 15: "15 hours old" };
  for (const [hours, where] of Object.entries(map.age_lines)) {
    label(s, ageWords[hours], where.south[0], where.south[1], "left", { w: 1.7, gap: 0.1, name: `Sunset line: ${ageWords[hours]}` });
  }
  s.addText(lines(["here the sun set", "before the moon was new"]), {
    x: map.age_lines["0"].north[0] + 0.22, y: map.age_lines["0"].north[1] - 0.26, w: 2.1, h: 0.52, fontSize: 12, italic: true,
    color: C.background1, align: "left", valign: "middle", margin: 0, isTextBox: true, objectName: "Note: before the new moon",
  });
  s.addNotes(notes(
    "Sunset is a line that sweeps westwards around the Earth, once a day. So every place gets exactly one look at the evening sky, and the east looks first.",
    "The first line on the right shows where the sun was setting at the moment the moon was new. Each line after it shows the sunset three hours later. The colours follow the lines: night blue in the east, where the sun set before the moon was even new; warmer towards the west, where the moon had more hours to move away from the sun, about half a degree every hour.",
    "So the further west you stand, the older the moon is when your turn comes, and the easier it is to see. Singapore, Malaysia and Indonesia looked first, before the moon was new. Mecca and Cairo looked when it was three to four hours old, London and Rabat at five to six.",
    "Source: calculated for this talk, the sky at each point's own sunset on Tuesday 17 February 2026, one point for every degree of latitude and longitude. Coastline: Natural Earth (public domain)."));

  s = placeSlide("s10_singapore.jpg", "SINGAPORE · SUNSET · 17 FEBRUARY 2026",
    ["The moon was not even new yet.", "It had set 4 minutes before the sun."], [["THURSDAY", "T"]], 3.55);
  label(s, "the moon, already down", ...inches(1610 - 40, 1300), "left");
  s.addNotes(notes(
    "Singapore decides by calculation alone, from one spot on its west coast. It asks for a moon at least 3 degrees high and 6.4 degrees from the sun at sunset.",
    "On 17 February the sun set in Singapore at 19:21. That was forty minutes before the new moon had even happened, and the moon had gone down four minutes before the sun. There was no moon in the evening sky at all.",
    "The Mufti of Singapore announced that evening: \"the crescent of the month of Ramadan is not visible above Singapore's horizon at sunset this evening because the moon set 4 minutes earlier than the sun.\" Ramadan began on Thursday 19 February.",
    "Sources: announcement by the Mufti of Singapore, 17 February 2026 (muis.gov.sg). The times were calculated for this talk and agree with the announcement."));

  s = placeSlide("s11_malaysia.jpg", "MALAYSIA · SUNSET · 17 FEBRUARY 2026",
    ["Malaysia calculates, and looks.", "Watchers at 29 places."], [["THURSDAY", "T"]], 3.55);
  label(s, "the moon, already down", ...inches(1470 - 40, 1300), "left");
  s.addNotes(notes(
    "Malaysia uses the same two numbers as Singapore, 3 degrees and 6.4 degrees, measured from its westernmost island. But it still sends people out to look, and a real sighting anywhere in the country would count.",
    "That evening the crescent was looked for at 29 places across the country. There too the sun set before the moon was new, 24 minutes before, so there was nothing to see.",
    "The Keeper of the Rulers' Seal announced that fasting would begin on Thursday 19 February, by order of the King with the consent of the Rulers.",
    "Sources: RTM, Malaysia's state broadcaster, 17 February 2026; Malaysia's official calendar for 2026. The times were calculated for this talk."));

  s = placeSlide("s12_indonesia.jpg", "INDONESIA · 17 FEBRUARY 2026",
    ["One country, two first days."], [["THE GOVERNMENT · THURSDAY", "T"], ["MUHAMMADIYAH · WEDNESDAY", "W"]], 2.75);
  label(s, "the moon, already down", ...inches(1530 - 40, 1300), "left");
  s.addNotes(notes(
    "Indonesia's government holds a decision session on the evening of day 29, with sworn observers and with the same two numbers as Malaysia and Singapore. On 17 February the numbers were not met: in the far northwest of the country the sun set ten minutes before the new moon. The government announced Thursday 19 February.",
    "Muhammadiyah, one of the country's largest Muslim organisations, follows its own calculated calendar, made for the whole world. Months earlier it had announced that Ramadan would begin on Wednesday 18 February.",
    "So neighbours in one country began on different days. We come back to the reason near the end.",
    "Sources: Indonesia's Ministry of Religious Affairs (decision on 1 Ramadan 1447); the central board of Muhammadiyah, announcement 2/MLM/I.0/E/2025 (muhammadiyah.or.id). The times were calculated for this talk."));

  s = placeSlide("s13_mecca.jpg", "MECCA · SUNSET · 17 FEBRUARY 2026",
    ["The moon is 3 hours old.", "It sets 3 minutes after the sun."], [["WEDNESDAY", "W"]], 3.55);
  label(s, "the moon", ...inches(1800 + 50, 1066), "right", { w: 1.6 });
  s.addNotes(notes(
    "Saudi Arabia's printed calendar, the Umm al-Qura calendar, asks two things on day 29, at one place, the Kaaba in Mecca: has the new moon already happened, and does the moon set after the sun? It does not ask whether anyone could see the crescent.",
    "On 17 February the sun set in Mecca at 18:19. The moon was then 3 hours and 18 minutes old, stood less than half a degree above the horizon, and set at 18:23, about three minutes after the sun. Both answers were yes, so the calendar's first day of Ramadan 1447 was Wednesday 18 February.",
    "Sources: the rule and the date are in the official printed Umm al-Qura calendar (King Abdulaziz City for Science and Technology), page 177. The times for Mecca were calculated for this talk."));

  s = placeSlide("s14_saudi_looks.jpg", "SAUDI ARABIA · THE SAME EVENING",
    ["For Ramadan, people go out and look.", "The court hears the witnesses."], [["WEDNESDAY", "W"]], 3.55);
  label(s, "the moon", ...inches(1800 + 50, 1066), "right", { w: 1.6 });
  s.addNotes(notes(
    "The printed calendar is for everyday dates. For Ramadan, for the feast that ends it and for the month of the pilgrimage, Saudi Arabia's Supreme Court decides. It asks people across the country to look for the crescent on the evening of day 29, and to bring what they saw to the nearest court.",
    "It did so for Tuesday 17 February. That night the Royal Court announced that Ramadan would begin on Wednesday 18 February. Most of the Gulf countries announced the same day.",
    "Astronomers had said that no eye could have seen the moon that evening; the court accepted a report that someone did.",
    "Sources: Saudi Press Agency (the Supreme Court's call to look, and \"Royal Court: Ramadan Begins in Saudi Arabia Tomorrow, February 18, 2026\"); press reports for the Gulf countries and for the accepted report; moonsighting.com for the astronomers' statement."));

  s = placeSlide("s15_turkiye.jpg", "TÜRKIYE · MIDNIGHT IN GREENWICH",
    ["Türkiye looks at the whole Earth.", "It asks for 8°. The moon had 6°."], [["THURSDAY", "T"]], 3.55);
  s.addNotes(notes(
    "Türkiye's religious authority, the Diyanet, calculates its calendar years ahead. It follows the sunset line around the whole Earth. If anywhere, at sunset, the moon stands at least 5 degrees high and 8 degrees from the sun, and this happens before midnight in Greenwich, the month begins the next day.",
    "On 17 February, at midnight in Greenwich, the best place on the sunset line had the moon 4.5 degrees high and 6.1 degrees from the sun. Not enough. The two numbers were first met at 03:42 Universal Time, three hours and forty-two minutes too late, over the Pacific Ocean.",
    "Türkiye's Ramadan began on Thursday 19 February.",
    "Sources: the Diyanet's calendar for 2026 and its published rule. The numbers were calculated for this talk; 03:42 is also the time the Diyanet prints."));

  // Türkiye's film: the Earth turns under the sunset line, from Singapore to the open Pacific (art/sweep_film.py).
  // The film covers the whole slide; the slide's own picture is the film's first frame, so nothing jumps when it
  // starts, and there is still a picture if the film cannot play. The kicker and title are added after the film,
  // so they sit on top of it.
  s = slide("Place", "s15c_sweep_first.jpg");
  s.addMedia({
    type: "video", path: art("s15c_sweep.mp4"), x: 0, y: 0, w: 13.333, h: 7.5, objectName: "Film: the sunset round the Earth",
    cover: "data:image/png;base64," + fs.readFileSync(art("s15c_sweep_first.png")).toString("base64"),
  });
  s.addText("TÜRKIYE · LOOKING FOR 5° AND 8°", { placeholder: "kicker", charSpacing: 5 });
  s.addText("Follow the sunset.", { placeholder: "title" });
  s.addNotes(notes(
    "[A film of 40 seconds. Start it and talk over it.]",
    "Türkiye's rule follows the sunset right round the Earth, looking for one place where the moon stands 5 degrees high and is 8 degrees from the sun. Watch the two figures at the bottom left, and the clock.",
    "Singapore, Malaysia, Indonesia: the moon has already set, and it is not even new yet. Pakistan: set. Mecca: less than half a degree high. Egypt, and Türkiye itself: the same. London, Morocco: a little higher each time, because the moon keeps moving away from the sun.",
    "New York: 3 degrees high. Midnight in Greenwich: the deadline. The moon is 6 degrees from the sun.",
    "Los Angeles: high enough at last, 5 degrees, but only 7 degrees from the sun. And then, in the open Pacific, at 03:42, both numbers are met. Three hours and forty-two minutes after the deadline.",
    "(New York and Los Angeles are not part of the story. They are stops on the sunset's way.)",
    "Source: calculated for this talk. Each place's sunset, the moon's height and direction there, and the moon's distance from the sun through the night all come from the same calculation; film time slows down while a place is at its sunset and hurries in between."));

  // Türkiye's third slide: the globe at the moment its numbers were first met (art/globe.py), to talk over.
  const globe = JSON.parse(fs.readFileSync(art("s15b_globe_points.json"), "utf8"));
  s = placeSlide("s15b_turkiye_globe.jpg", "TÜRKIYE · THE WHOLE EARTH AT 03:42", ["The numbers were met", "out here. Too late."], [], 0);
  s.addText("3 h 42 min", {
    x: 0.9, y: 3.6, w: 5.2, h: 1.05, fontFace: THEME.headFontFace, fontSize: 62, color: C.accent1, align: "left", valign: "middle",
    margin: 0, isTextBox: true, objectName: "How late",
  });
  s.addText("after the deadline", {
    x: 0.9, y: 4.62, w: 5.2, h: 0.4, fontSize: 20, color: C.background1, align: "left", valign: "middle", margin: 0,
    isTextBox: true, objectName: "How late: caption",
  });
  s.addText("At midnight in Greenwich the moon was 6° from the sun. It needed 8°.", {
    x: 0.9, y: 5.2, w: 4.9, h: 0.7, fontSize: 15, color: C.background2, align: "left", valign: "top", margin: 0,
    isTextBox: true, objectName: "Why too late",
  });
  s.addText(lines(["the first place to meet", "both numbers, at 03:42"]), {
    x: globe.first[0] + 0.32, y: globe.first[1] - 0.27, w: 2.3, h: 0.54, fontSize: 13, italic: true, color: C.background1,
    align: "left", valign: "middle", margin: 0, isTextBox: true, objectName: "Label: the first place",
  });
  s.addText(lines(["the deadline: sunset at", "midnight in Greenwich"]), {
    x: globe.deadline_line["30"][0] - 0.15 - 2.5, y: globe.deadline_line["30"][1] - 0.27, w: 2.5, h: 0.54, fontSize: 13, italic: true,
    color: C.background1, align: "right", valign: "middle", margin: 0, isTextBox: true, objectName: "Label: the deadline line",
  });
  label(s, "sunset at 03:42", globe.sunset_line["-30"][0], globe.sunset_line["-30"][1], "right", { w: 1.8, gap: 0.18, size: 13, name: "Label: the sunset line" });
  label(s, "Alaska", globe.alaska[0], globe.alaska[1], "right", { w: 1.0, gap: 0.2, italic: false, name: "Place: Alaska" });
  label(s, "Hawaii", globe.hawaii[0], globe.hawaii[1], "left", { w: 1.0, gap: 0.14, italic: false, name: "Place: Hawaii" });
  s.addNotes(notes(
    "Here is the whole Earth, the way Türkiye's rule looks at it. We are over the Pacific Ocean, and it is 03:42 Universal Time.",
    "The bright edge is the sunset line at that moment: daylight to the left of it, night to the right, over the Americas. The dashed line shows where that same sunset line stood at midnight in Greenwich. That was the deadline.",
    "At the deadline the moon was 6 degrees from the sun, and that is the same for everyone on Earth. It needed 8. The moon keeps moving away from the sun by half a degree an hour, so it got there. But by then the sunset line had moved on to the middle of the Pacific. The small light marks the first place on Earth where the moon stood 5 degrees high and 8 degrees from the sun at sunset: open ocean, south-east of Hawaii. The pale glow to its left is where the numbers went on being met as the sunset moved west.",
    "Three hours and forty-two minutes after the deadline. So for Türkiye the old month kept its 30th day.",
    "Notice Alaska, at the top. The sunset line reaches the tip of its long peninsula a few minutes later. We come back to it.",
    "Source: calculated for this talk, the sky at each point's own sunset on Tuesday 17 February 2026, one point for every degree of latitude and longitude. 03:42 is also the time printed by Türkiye's religious authority. Coastline: Natural Earth (public domain)."));

  s = placeSlide("s16_morocco.jpg", "MOROCCO AND PAKISTAN · WITNESSES DECIDE",
    ["For them, this was day 28.", "They looked one evening later."], [["THURSDAY", "T"]], 3.55);
  s.addNotes(notes(
    "In Morocco and in Pakistan, what witnesses see decides; calculation only checks or advises. Morocco's ministry gathers reports from about 270 observation points and from army units. In Pakistan committees across the country collect testimonies, and a central committee judges them.",
    "Their month before Ramadan had begun a day later than in Saudi Arabia or Türkiye. So on Tuesday they were on day 28, and did not look.",
    "On Wednesday evening the moon over Rabat was 30 hours old and 13 degrees high, and it set 73 minutes after the sun: easy to see. Both countries announced that the crescent had been seen, and began on Thursday 19 February.",
    "So the disagreement is older than one evening. It is carried over from the month before.",
    "Sources: press reports of February 2026 quoting Morocco's Ministry of Endowments and Islamic Affairs and Pakistan's Central Ruet-e-Hilal Committee. The moon's position was calculated for this talk."));

  s = placeSlide("s17_egypt.jpg", "EGYPT · SUNSET · 17 FEBRUARY 2026",
    ["Egypt does both.", "Looked. Not seen."], [["THURSDAY", "T"]], 3.55);
  label(s, "the moon", ...inches(1700 + 48, 1134), "right", { w: 1.6 });
  s.addNotes(notes(
    "Egypt sends committees out to look on day 29, and uses calculation as a filter: a report counts only if the moon could really have been there. It must set after the sun, at least 15 hours and 40 minutes after the new moon.",
    "In Cairo that evening the moon was 3 hours and 44 minutes old and set 4 minutes after the sun.",
    "Egypt's religious authority, Dar al-Ifta, announced that the crescent had not been sighted. The old month got its 30th day, and Ramadan began on Thursday 19 February.",
    "Sources: Dar al-Ifta's announcement for Ramadan 1447 and its 2016 ruling on the method. The times were calculated for this talk."));

  s = placeSlide("s18_london.jpg", "LONDON · THE SAME EVENING", ["Nobody decides for everyone."], [], 0);
  // Two answers, and under each one line on how it was reached (each from that body's own website).
  stamp(s, "EAST LONDON MOSQUE · WEDNESDAY", "W", 0.9, 2.75);
  label(s, "uses the Umm al-Qura Islamic calendar, Saudi Arabia's", 0.9, 3.48, "right", { gap: 0.1, w: 8.0, size: 13, name: "How: East London Mosque" });
  stamp(s, "WIFAQUL ULAMA · THURSDAY", "T", 0.9, 3.92);
  label(s, "looks for the moon in Britain first, then in Morocco", 0.9, 4.65, "right", { gap: 0.1, w: 8.0, size: 13, name: "How: Wifaqul Ulama" });
  label(s, "the moon", ...inches(1730 + 48, 1090), "right", { w: 1.6 });
  s.addNotes(notes(
    "Britain has no single authority, so each mosque follows someone.",
    "East London Mosque announced on 17 February: \"1 Ramadan 1447 is on Wednesday 18 February 2026.\" Its website says how it sets its dates: \"we currently use the Umm al-Qura Islamic calendar\". That is Saudi Arabia's calendar, and it had Wednesday. (The same page adds that for the start of Ramadan the mosque waits for news of the sighting of the new crescent moon.)",
    "Wifaqul Ulama, a body of scholars, decides by \"Moonsighting in UK (primary) and Morocco (secondary)\". It was still on day 28 that evening. It looked on Wednesday, and announced: \"The first day of Ramadān will be Thursday 19th February 2026.\"",
    "Same city, same moon, and neighbours fasting on different days. It was not the first time: one compilation records the same split in London for Ramadan 2019, on 6 and 7 May.",
    "Sources: East London Mosque's announcement and its page \"Understanding Prayer Times and Islamic Calendar\" (eastlondonmosque.org.uk); Wifaqul Ulama's calendar for the year 1447 (wifaqululama.co.uk); moonsighting.com for 2019."));

  // ---- Part 4: one sky, many answers --------------------------------------------------------------------
  section = "One sky, many answers";
  pres.addSection({ title: section });

  s = slide("Map", "s19_answers.jpg");
  s.addText("RAMADAN 1447 · THE FIRST DAY", { placeholder: "kicker", charSpacing: 4 });
  s.addText("One moon. One evening. Two first days.", { placeholder: "title" });
  placeLabels(s);
  [["Wednesday 18 February", C.accent1, 0.9], ["Thursday 19 February", C.accent2, 4.0]].forEach(([text, color, x]) => {
    s.addShape(pres.ShapeType.ellipse, { x, y: 1.74, w: 0.17, h: 0.17, fill: { color }, line: { color, width: 0 }, objectName: `Key dot: ${text}` });
    s.addText(text, { x: x + 0.28, y: 1.66, w: 2.7, h: 0.33, fontSize: 14, color: C.background1, align: "left", valign: "middle", margin: 0, isTextBox: true, objectName: `Key: ${text}` });
  });
  s.addNotes(notes(
    "Wednesday: Saudi Arabia and most of the Gulf, Muhammadiyah in Indonesia, some mosques in London.",
    "Thursday: Türkiye, Malaysia, Indonesia's government, Singapore, Egypt, Morocco, Pakistan, and other mosques in London.",
    "Nobody made a mistake in arithmetic. They asked different questions, from different places, and some of them were not even on the same day 29.",
    "Sources: as given on the slide of each place."));

  s = placeSlide("s20_alaska.jpg", "THE ALASKA PENINSULA · SUNSET · 04:05 UNIVERSAL TIME",
    ["Same rule. Same evening. Two answers."], [["TÜRKIYE · THURSDAY", "T"], ["MUHAMMADIYAH · WEDNESDAY", "W"]], 2.75);
  label(s, "5° above the horizon", ...inches(2330, 930 - 34), "left", { gap: 0, w: 2.4 });
  label(s, "the moon", ...inches(1890, 933 + 62), "centre", { w: 1.4 });
  s.addNotes(notes(
    "Remember Indonesia: the government began Ramadan on Thursday, and Muhammadiyah, one of the country's largest organisations, on Wednesday. Here is where that Wednesday came from.",
    "The surprise is that Muhammadiyah's calendar asks exactly what Türkiye's asks: the moon 5 degrees high and 8 degrees from the sun. And both give the moon one more chance. If the numbers are met only after midnight in Greenwich, it still counts, as long as it happens on the mainland of America and the new moon came before dawn in New Zealand.",
    "That evening the best chance on the American mainland was the Alaska Peninsula. Muhammadiyah's experts say the numbers were met there, and name places in western Alaska. Türkiye's calendar says Thursday. Muhammadiyah's expert puts the difference down to which far corners of Alaska are counted as mainland, and calls it a difference in applying the same rule.",
    "By the calculation made for this talk, at the tip of the peninsula the moon was far enough from the sun, and a hair short of 5 degrees high: four hundredths of a degree short. That is less than any calculation can honestly settle. The bending of light near the horizon changes more than that with the weather.",
    "Same rule, same evening, two answers.",
    "Sources: Muhammadiyah's article of 7 January 2026 (muhammadiyah.or.id), quoting its astronomy expert Arwin Juli Rakhmadi Butar-Butar; the Diyanet's calendar for 2026. The Alaska figure was calculated for this talk."));

  s = slide("Story", "s21_rules.jpg");
  s.addText("And the questions change.", { placeholder: "title" });
  [["1980", "Türkiye"], ["2009", "Türkiye"], ["2014", "Türkiye"], ["2017", "Türkiye"], ["2021", "Southeast Asia"]].forEach(([year, who], i) => {
    const [x, y] = inches(420 + i * 430, 800);
    label(s, year, x, y + 0.5, "centre", { w: 1.6, h: 0.4, size: 22, italic: false, name: `Year: ${year}` });
    label(s, who, x, y + 0.88, "centre", { w: 2.0, name: `Year ${year}: ${who}` });
  });
  s.addNotes(notes(
    "The rules themselves move. Türkiye's rule changed in 1980, in 2009, in 2014 and in 2017. Malaysia, Indonesia and Singapore replaced an easier rule with today's numbers in 2021 and 2022. Saudi Arabia has had at least three rules since the 1970s.",
    "Each calendar was worked out with the rule of its day, and never worked out again.",
    "So what should the calendar on your phone show? It has to pick one answer, for one place, by the rule of that year. Rebuild Türkiye's published calendar from its rules, 707 months of it, and 703 come out right. The last four each need a note of their own.",
    "Sources: the authorities' published calendars and rules. The comparison with Türkiye's 707 published months was made for this talk."));

  s = slide("Title", "s22_closing.jpg");
  s.addText(lines(["One sky.", "Many answers."]), { placeholder: "title" });
  s.addText("By Thursday evening everyone could see the same moon.", { placeholder: "subtitle" });
  s.addNotes(notes(
    "By Wednesday evening the crescent could be seen from India westwards, and by Thursday evening from the whole world. The month had begun, twice.",
    "The moon keeps perfect time. The hard part is agreeing what to ask it.",
    "Thank you.",
    "Source: moonsighting.com (\"On February 18, it can be seen easily from India westward everywhere. On February 19, it can be seen easily in the whole world\")."));

  await pres.writeFile({ fileName: OUT });
  await applyTheme(OUT, THEME);
  console.log("wrote", OUT);
})();
