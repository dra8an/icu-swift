#!/bin/sh
# Show how Keynote prints the speaker notes: export "slide with notes" pages and turn the first two into pictures.
# Usage: sh notes_check.sh <deck.pptx> <output folder> [tag]
# Writes <name>_notes[_tag].pdf and <name>_notes[_tag]-N.jpg. Keynote opens the file and closes it without saving;
# it refuses to run if Keynote already has a document of that name open.
set -e
deck="$1"
out="$2"
tag="${3:+_$3}"
name="$(basename "$deck" .pptx)"
mkdir -p "$out"
already="$(osascript -e "tell application \"Keynote\" to return (exists document \"$name\")")"
if [ "$already" = "true" ]; then
  echo "Keynote already has a document named $name open; close it first." >&2
  exit 1
fi
pdf="$out/${name}_notes$tag.pdf"
open -a Keynote "$deck"
osascript - "$name" "$pdf" <<'EOF'
on run argv
	set docName to item 1 of argv
	set outPath to item 2 of argv
	with timeout of 170 seconds
		tell application "Keynote"
			set waited to 0
			repeat while (not (exists document docName)) and waited < 60
				delay 1
				set waited to waited + 1
			end repeat
			if not (exists document docName) then return "NO DOCUMENT named " & docName
			delay 1
			set theDoc to document docName
			export theDoc to (POSIX file outPath) as PDF with properties {export style:SlideWithNotes}
			close theDoc saving no
			return "exported slides with notes"
		end tell
	end timeout
end run
EOF
pdftoppm -jpeg -r 60 -f 1 -l 2 "$pdf" "$out/${name}_notes$tag"
ls -1 "$out/${name}_notes$tag"-*.jpg
