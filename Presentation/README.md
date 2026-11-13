# The Twenty-Ninth Evening

A presentation about how the Islamic month begins, told as one real evening: Tuesday 17 February 2026, the evening
before Ramadan 1447. A child looks at the sky; on the 29th evening of the month someone must say whether tomorrow is
day 1 or day 30; and around the world the same thin moon gets different answers.

Every number in it comes from this repository's astronomy engine. Every picture, and the film, is drawn by code from
those numbers.

## What is here

Each folder is one saved version, frozen on the day it was saved and not edited afterwards.

| Folder | Saved | What it is |
|---|---|---|
| `alpha/` | 2026-11-12 | The first complete version: 24 slides, one of them a 40-second film, with speaker notes and a printable speaker's script |

In each version:

- the deck (`.pptx`, made to be opened in Keynote), the film (`.mp4`) and the speaker's script (`.pdf`);
- `source/`: everything needed to build them again;
- `MANIFEST.md`: what is in the version, checksums, how to rebuild it, what was checked and what is still open.

## Where the work happens

Not here. The working folder is `Research/presentation/`, which git ignores along with the rest of `Research/`.
A version is copied here when it is worth keeping. The rebuild command in each `MANIFEST.md` is run from that working
folder.

The state of the work, the decisions taken and the working rules are in `Docs/ISLAMIC_CALENDARS_DECK_BRIEF.md`.
