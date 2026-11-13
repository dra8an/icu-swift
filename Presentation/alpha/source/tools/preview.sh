#!/bin/sh
# Render a .pptx the way the audience will see it: through Keynote itself.
# Usage: sh preview.sh <deck.pptx> <output folder>
# Writes <name>.pdf and <name>-N.jpg (one per slide, 1600 px wide) into the output folder.
# Keynote opens the file, exports it and closes it without saving. It refuses to run if Keynote already has a
# document of the same name open, so it can never close something of the user's.
set -e
deck="$1"
out="$2"
tools="$(dirname "$0")"
name="$(basename "$deck" .pptx)"
mkdir -p "$out"
already="$(osascript -e "tell application \"Keynote\" to return (exists document \"$name\")")"
if [ "$already" = "true" ]; then
  echo "Keynote already has a document named $name open; close it first." >&2
  exit 1
fi
rm -f "$out/$name.pdf" "$out/$name"-*.jpg
open -a Keynote "$deck"
osascript "$tools/keynote_export.applescript" "$name" "$out/$name.pdf"
pdftoppm -jpeg -scale-to-x 1600 -scale-to-y -1 "$out/$name.pdf" "$out/$name"
ls -1 "$out/$name"-*.jpg
