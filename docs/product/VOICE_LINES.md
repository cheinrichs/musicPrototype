# Voice lines — implementation status

**The wording lives in the Google Doc, not here:**
[SongStone — Voice Lines (authoring copy)](https://docs.google.com/document/d/1TFaYuu4gTD9aDDd0QxO_9OTWkRIU1TID1jSoeTc95fY/edit).
Edit wording there. The rules (control of error, talk in the gaps, name the position,
Clef a fifth above Piper, and the rest) live there too.

This file tracks only what the build has: which lines are **recorded**, which are **wired**
(a live round plays them), and **which asset** each maps to. Keeping the two jobs apart is
deliberate: the skill-tree spreadsheet drifted out of sync because one document tried to be
both the design and the build record.

- **Mechanic:** Trello card 231. At A1 Explore, in both games, repeated tapping is retired:
  the child **pops a bubble to commit**.
- **⚠️ NO AUDIO IS BEING GENERATED.** Trello card 210 stands: whether a human voice actor
  replaces the provisional voices is open, and the inventory is large enough that nobody
  wants to record it twice. Nothing below is wired until that is settled.

**Where the build's lines live:** `lib/audio/voice_line.dart` (`VoiceLine`, game lines),
`lib/audio/shared_voice_line.dart` (`SharedVoiceLine`, lines any game uses),
`assets/audio/voice/<enum name>.mp3` (one file per enum member), and
`tool/build_voice_lines.py` (which source recording became which file).

Update this file in the same commit as any line that is recorded, wired, unwired or retired.

Status checked against the code on 2026-11-20.

---

## What the build plays today, against the doc's current wording

"Matches the doc" means the recording says what the Google Doc now says. A recorded,
wired line that no longer matches still plays until its replacement is recorded: silence
would be worse.

### High vs Low

| Stage | Line (by role) | Asset | Recorded | Wired | Matches the doc? |
|---|---|---|---|---|---|
| A0 | Clef narration, first / second note | `clefSaysHigh`, `clefSaysHighSecond` | yes | yes | ⚠️ No. Recorded "Ooh, that one sounds high"; the doc now has "That sounds high" |
| A0 | Piper narration, first / second note | `piperSaysLow`, `piperSaysLowSecond` | yes | yes | ⚠️ No. Recorded "That one sounds low"; the doc has "That sounds low" |
| A1 | Clef intro | `listenForHigh` | yes | yes | ⚠️ No: superseded by the bubble line (below) |
| A1 | Piper intro | `listenForLow` | yes | yes | ⚠️ No: superseded by the bubble line |
| A2 | Clef / Piper ask | `giveMeHigh`, `giveMeLow` | yes | yes | ⚠️ No: RETIRED in the doc (first person, wrong target) |
| any | Clef / Piper wrong-answer nudge | `tryAgainClef`, `tryAgainPiper` (shared) | yes | yes | ⚠️ No: RETIRED ("Nearly" is untrue with two options); replaced by "Hmm" |
| A0 | Arrow cue | `pressTheArrowWhenDone` (shared) | no | yes | ⚠️ No: RETIRED ("press" → "tap", "done" → "ready"); the A0 sign-off carries the arrow now |
| any | Character-tap giggle, Clef / Piper | `giggleClef`, `gigglePiper` (shared) | no | yes | ⚠️ No: the giggle is RETIRED |

### Loud or Quiet

Nothing in the doc's Loud or Quiet section is recorded. The game today speaks only the
shared nudges and giggles above (`lib/games/loud_quiet/state/loud_quiet_game_state.dart`).

---

## To record (none recorded, none wired, no enum member yet)

Wording: the Google Doc. This is the list by role, so nothing is missed when recording
resumes.

### New at A1 Explore, the bubble mechanic (card 231): 6 lines

| Game | Role | Clef | Piper |
|---|---|---|---|
| High vs Low | Intro | "Listen for the high one…" | "Listen for the low one…" |
| High vs Low | After | "Pop the bubble on the high one." | "Pop the bubble on the low one." |
| Loud or Quiet | Intro | "Listen for the loud one…" | "Listen for the quiet one…" |
| Loud or Quiet | After | "Pop the bubble on the loud one." | "Pop the bubble on the quiet one." |
| Both games (shared) | Stall nudge | "Pop a bubble when you've decided." | "Pop a bubble when you're ready." |

(That is ten takes for six roles: the stall nudge is one pair shared by both games.)

### Elsewhere, per the doc

- **High vs Low A0:** the openings (one each), the narration in the doc's new wording, and the
  sign-off (both record it, alternating).
- **High vs Low A2:** intro and after, one each.
- **Ordering:** one full line each, leading with her own pole.
- **Nudges, both games:** a single **"Hmm"** per character. ⚠️ The six earlier nudges are
  superseded. Do not re-expand them: Cooper will see whether "Hmm" feels insufficient in
  game first.
- **Loud or Quiet A0:** openings, narration, the occasional reactive lines, and the sign-off.
- **Loud or Quiet A2:** the lock line, which is ALSO the Decide intro prompt (one line now,
  each character recording only her own pole), and the after lines.
  ⚠️ **"Far end" / "near end", not "loud end" / "quiet end".** The child already knows which
  instrument is loud, so repeating the pole word locates nothing; "far" does. The far-is-loud
  mapping is taught by the apparatus (card 208: the needle sweeps further for louder).
  **"Far" means far ALONG THE DIAL, not far across the screen.** That distinction is what
  retired "over at the far side". No layout change may break it: the loud end must stay the
  end the needle reaches last.
- **Shared celebration:** two per character.

---

## Retired

Asset status as of 2026-11-20. "Still wired" means the code still calls it: that is for the
recording pass to resolve (wire the replacement and unwire this in the same commit), not
before, per card 210.

| Retired line | Why | Asset | Still wired? |
|---|---|---|---|
| A1 keep-going cue, "Try tapping the high one again and again", and its siblings, both games | Taught the dead tapping mechanic (card 231) | none: never recorded, never in the code | no |
| Loud or Quiet stall nudges "Try tapping one", "Go on, give one a poke" | Same | none: never recorded, never in the code | no |
| "Give me the high one" / "Give me the low one" | First person, wrong target | `giveMeHigh`, `giveMeLow` (+ `45` variants) | ⚠️ yes (A2) |
| "Nearly" / "so close" nudges | Untrue with two options; evaluative | `tryAgainClef`, `tryAgainPiper` (+ `45`, `67`, `8plus` variants) | ⚠️ yes (the two base takes) |
| The six-nudge set | Superseded by a single "Hmm" | as above | ⚠️ yes |
| "Press the arrow when you're done!" | press → tap, done → ready | `pressTheArrowWhenDone` (not recorded) | ⚠️ yes (A0; silent, no file) |
| The giggle | Retired in the doc | `giggleClef`, `gigglePiper` (not recorded) | ⚠️ yes (silent, no files) |
| "Tap Piper Fox / Clef to hear it again" | Nobody to redirect to with one character on screen | none | no |
| All "Pop the…" / "Pop it on the dial" variants of the British idiom | The British "pop" is killed so "pop the bubble" is unambiguous | none | no |
| "over at the far side" | Side-specific; the layout moves | none | no |
| "Ready when you are" | Redundant with the sign-off | none | no |
| "That one was the soft one, have another listen" and that set | Wrong-answer commentary | none | no |
| `putClefOnLow.mp3` | Misnamed: Clef never owns low | none (renamed long ago, commit `4c49ceb`) | no |

**Recorded but never wired, now outside the doc:** the band variants `listenForHigh45`,
`listenForLow45`, `giveMeHigh45`, `giveMeLow45`, `clefSaysHigher67`, `piperSaysLower67`,
`piperSaysLower67Second`, `listenForLower67`, `whichIsLower67`, `tryAgainClef45`,
`tryAgainPiper45`, `tryAgainPiper67`, `tryAgainPiper8plus`. The doc keeps tone the same across
age bands and names only two vocabulary changes (2–3 "big/little", 8+ shorter prompts), so
none of these match it. They stay as files until the recording pass decides.

---

## Captions — not voice lines, do not record

On-screen text for the watching adult: `captionText` and `secondaryCaptionText` in
`HighLowGameState`, `captionText` and `guidanceText` in `LoudQuietGameState`. The Explore
guidance that said "Keep tapping the higher one" (and the loud/quiet equivalent) was changed
on 2026-11-20 to "Listen for the higher one." / "Listen for the loud one.": it names no
gesture, so it is true for today's tapping and for card 231's bubble alike.
