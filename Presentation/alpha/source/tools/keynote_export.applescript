-- Export a presentation that Keynote is opening or has open, report what arrived, close it without saving.
-- Usage: osascript keynote_export.applescript <document name> <out.pdf>
-- The file must be opened first with the shell command  open -a Keynote <file.pptx>  (Keynote 10.1's own
-- AppleScript "open" does not import PowerPoint files; found 2026-11-11). The script waits for the document of
-- that name and only ever touches that one.
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
			if not (exists document docName) then return "NO DOCUMENT named " & docName & " after " & waited & " s"
			delay 1
			set theDoc to document docName
			try
				export theDoc to (POSIX file outPath) as PDF with properties {PDF image quality:Best}
			on error
				export theDoc to (POSIX file outPath) as PDF
			end try
			set slideCount to count of slides of theDoc
			set report to "document: " & docName & " (appeared after " & waited & " s) | slides: " & slideCount & " | size: " & (width of theDoc) & " x " & (height of theDoc)
			repeat with i from 1 to slideCount
				set theSlide to slide i of theDoc
				set theEffect to "unknown"
				try
					set tp to transition properties of theSlide
					set theEffect to (transition effect of tp) as text
				end try
				set theNotes to presenter notes of theSlide
				set report to report & linefeed & "slide " & i & " | transition: " & theEffect & " | notes: " & (count of characters of theNotes) & " characters"
			end repeat
			close theDoc saving no
			return report
		end tell
	end timeout
end run
