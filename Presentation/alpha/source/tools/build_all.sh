#!/bin/sh
# Build the whole deck from nothing: numbers, pictures, slides, fades, and a render through Keynote.
# Usage: sh tools/build_all.sh [engine|film|pictures|deck|preview|script ...]   (no word = pictures deck preview script)
# It never changes folder; every path is given in full.
set -e
B="$(dirname "$0")/.."
PY="$B/.venv/bin/python"
SKILL="${PPTX_SKILL:-$HOME/.claude/skills/synced/1ead4d0c-d854-458f-b3b5-788aa8d79596_c0db111d-dada-484f-ab70-514f1b8b4e00/pptx}"
LAND="$B/../crescent/naturalearth/ne_10m_land.geojson"
steps="${*:-pictures deck preview script}"

for step in $steps; do
  case "$step" in
    engine)    # the numbers from the astronomy engine (65 s to build the first time, 2 s to run)
      swift build -c release --package-path "$B/engine"
      mkdir -p "$B/engine/out"
      "$B/engine/.build/release/EveningNumbers" "$B/engine/out/places.csv" "$B/engine/out/grid.csv" "$B/engine/out/series.csv" ;;
    film)      # the 40-second film for the Türkiye part (about 3 minutes; not part of the default run)
      "$PY" "$B/art/sweep_film.py" "$B/engine/out/places.csv" "$B/engine/out/grid.csv" "$B/engine/out/series.csv" "$LAND" "$B/deck/art" ;;
    pictures)  # every picture (about a minute)
      "$PY" "$B/art/scenes.py" "$B/deck/art"
      "$PY" "$B/art/world_map.py" "$B/engine/out/grid.csv" "$LAND" "$B/deck/art"
      "$PY" "$B/art/globe.py" "$B/engine/out/grid.csv" "$LAND" "$B/deck/art" ;;
    deck)      # the slides, then a fade on every slide
      NODE_PATH="$B/node_modules" PPTX_SKILL="$SKILL" node "$B/deck/build_deck.js"
      "$PY" "$B/tools/add_fade.py" "$B/deck/the_twenty_ninth_evening.pptx" "$B/deck/with_fade.pptx"
      mv "$B/deck/with_fade.pptx" "$B/deck/the_twenty_ninth_evening.pptx" ;;
    preview)   # through Keynote: a PDF and one picture per slide (Keynote opens for a few seconds)
      # Keynote is given a copy under another name, so this works while the user has the deck itself open.
      mkdir -p "$B/deck/render"
      cp "$B/deck/the_twenty_ninth_evening.pptx" "$B/deck/render/preview_copy.pptx"
      sh "$B/tools/preview.sh" "$B/deck/render/preview_copy.pptx" "$B/deck/render" > /dev/null
      find "$B/deck/render" -name 'the_twenty_ninth_evening-[0-9][0-9].jpg' -delete
      for f in "$B/deck/render"/preview_copy-[0-9][0-9].jpg; do
        mv "$f" "$B/deck/render/the_twenty_ninth_evening-${f##*-}"
      done
      mv "$B/deck/render/preview_copy.pdf" "$B/deck/render/the_twenty_ninth_evening.pdf"
      rm "$B/deck/render/preview_copy.pptx"
      echo "rendered $(find "$B/deck/render" -name 'the_twenty_ninth_evening-[0-9][0-9].jpg' | wc -l | tr -d ' ') slides through Keynote" ;;
    script)    # the printable speaker's script, made from the deck's own notes and the Keynote renders
      "$PY" "$B/tools/make_script.py" "$B/deck/the_twenty_ninth_evening.pptx" "$B/deck/render" "$B/deck/the_twenty_ninth_evening_script.pdf" ;;
    *) echo "unknown step: $step" >&2; exit 1 ;;
  esac
done
