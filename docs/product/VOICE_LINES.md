# Voice lines — living reference

Every spoken line in the app, in one place: what is recorded, what is wired into a
round, what is still to record, and the rules that govern all of it. Sits alongside
[`HIGH_LOW_TIERS.md`](HIGH_LOW_TIERS.md) and [`CHARACTER_VOICES.md`](CHARACTER_VOICES.md).

Update this file in the same commit as any line that is added, changed, wired, unwired or
retired.

**Source of truth, in order:**

1. `lib/audio/voice_line.dart` — the `VoiceLine` enum. What the code can play.
2. `assets/audio/voice/` — the recorded `.mp3` files, one per enum member.
3. `tool/build_voice_lines.py` — `UPLOAD_TO_VOICE_LINE`. The wording of record: each
   recording's source filename transcribes the line Cooper delivered, and this map ties it
   to its enum member.

Wording below was checked against (3). The audio itself has not been auditioned against
the text as part of this doc. Wired/unwired status was checked against the call sites in
`lib/games/high_low/state/high_low_game_state.dart`.

**Captions are not voice lines.** They are separate strings with a different audience and
live in their own section at the end. Never record a caption.

---

## The rules that govern all of it

These are design rules. They are not checked by any code or test.

- **One voice across every age band.** Tone does not ladder; only vocabulary does. The
  reference is Bluey's Bandit — he talks to a six-year-old and a four-year-old completely
  differently but is plainly the same person, and never talks down to the younger one.
- **Describe the answer, never judge the attempt.** "That's the low one", "Ooh, nearly!" —
  never "nope", "wrong one", "that's a no".
- **Clef's voice must be audibly higher than Piper's.** In the delivered set Clef sits about
  a fifth above her, roughly 196 Hz against 128 Hz. This outranks every other voice choice:
  the characters own opposite poles, so vocal pitch is a second representation of the
  concept. **If the voice changes, preserve this first.**
- No sing-song presenter voice. No baby talk at any band. No over-praising. Real
  conversational rhythm, comfortable leaving a gap.
- **High/low vocabulary only.** Up/down belongs to Ascending/Descending.
- **Side-agnostic** — never reference left or right. The layout keeps moving.
- **Clef is never placed on the low one, and Piper never on the high one.** Clef owns high
  (the top of the tree); Piper owns low (beside the tree, on the ground). The first-person
  "give me" framing is retired along with the drag-to-character mechanic; see A2.
- **The "and…" pattern:** in A0 the two notes are narrated as one joined sentence, so each
  narration line has an "and…" variant for the second note.

**Levels:** the delivered set came in uneven — Clef spanned about 6.8 dB, Piper about 3.8 —
and had to be evened in normalisation. Aim for the middle of each character's range.

**Current generation settings** (from the source brief, not verifiable from the code):
Piper = Gemini *Pulcherrima*, Newscaster style, natural pace, British (Brixton). Clef =
*Despina*, Newscaster, natural pace, neutral. Both provisional and may be replaced by a
human voice actor.

**Age bands.** No age-band selector exists in the app yet. Lines for the 4-5 and 6-7 bands
are recorded and committed but only the 2-3/4-5-shared lines are wired into a round today.
The band picker is its own, unstarted epic (Trello card PqqgLOwF).

---

# HIGH vs LOW

Enum names are given in `code` format. "Wired" means a live round calls it today.

## A0 — Observe

The pair plays and the characters narrate. Nothing here references the mechanic, so the
tree change did not break these.

| Character | Line | Enum | Recorded | Wired |
|---|---|---|---|---|
| Clef | "Ooh, that one sounds high." | `clefSaysHigh` | yes | yes |
| Clef | "And ooh, that one sounds high." | `clefSaysHighSecond` | yes | yes |
| Piper | "That one sounds low." | `piperSaysLow` | yes | yes |
| Piper | "And that one sounds low." | `piperSaysLowSecond` | yes | yes |

**Wording change from the first version of this doc.** The 2-3 original ("That sounds
high.") is retired. The 4-5 wording with "one" is canonical for both bands: the four A0 files
(`clefSaysHigh`, `clefSaysHighSecond`, `piperSaysLow`, `piperSaysLowSecond`) were re-recorded
in place on 2026-09-07, so the original 2-3 takes no longer exist under those names.

**A0 6-7 band:**

| Character | Line | Enum | Recorded | Wired |
|---|---|---|---|---|
| Clef | "That note's higher." | `clefSaysHigher67` | yes | no |
| Clef | "And that note's higher." | — | **no** | no |
| Piper | "That one's lower." | `piperSaysLower67` | yes | no |
| Piper | "And that one's lower." | `piperSaysLower67Second` | yes | no |

Clef's second-note 6-7 line is not recorded, and no enum member exists for it. Until it does,
6-7 Observe cannot be wired even once a band picker exists.

## A1 — Explore

| Character | Line | Enum | Recorded | Wired |
|---|---|---|---|---|
| Clef | "Ooh, listen for the high one." | `listenForHigh` | yes | yes |
| Piper | "Listen for the low one." | `listenForLow` | yes | yes |
| Clef | "Which one sounds high?" | `listenForHigh45` | yes | no |
| Piper | "Which one sounds low?" | `listenForLow45` | yes | no |
| Piper | "Listen for the lower note." | `listenForLower67` | yes | no |
| Clef | "Listen for the higher note." | — | **no** | no |

Corrections against the first version: Piper's line has no "Ooh," in the recording
(`listenForLow` is the take Cooper confirmed as usable earlier), and the 4-5 and 6-7 lines
were missing entirely.

## A2 — Drag

**Currently in the app, superseded by the tree mechanic (interim):**

| Character | Line | Enum | Recorded | Wired | Problem |
|---|---|---|---|---|---|
| Clef | "Give me the high one." | `giveMeHigh` | yes | yes | First person. The drop target is a tree slot, not a character. |
| Piper | "Give me the low one." | `giveMeLow` | yes | yes | Same, and Piper now stands beside the tree, not on it. |

These are the only A2 lines a live round plays. They stay until the replacements below are
recorded. Silence would be a worse interim than a dated but warm line (see the enum's own
doc comment).

**Agreed replacements, 2026-10-05 — not recorded, no enum member, nothing wired to them:**

| Character | Line |
|---|---|
| Clef | "Put the high one up here on top." |
| Clef | "Pop the high one up on the top branch." |
| Piper | "Put the low one down on the bottom." |
| Piper | "Pop the low one down on the bottom branch." |

Clef says "up here" and it's true — he sits in the tree. Piper's lines carry no "here", so
they work from the left of the screen.

**A2 4-5 band** (recorded, not wired — the replacements above supersede these for 2-3 and
the 4-5 wording is a question rather than an instruction):

| Character | Line | Enum | Recorded | Wired |
|---|---|---|---|---|
| Clef | "Can you give me the high one?" | `giveMeHigh45` | yes | no |
| Piper | "Can you give me the low one?" | `giveMeLow45` | yes | no |

**A2 6-7 band** (recorded, not wired; Clef's counterpart is not recorded):

| Character | Line | Enum | Recorded | Wired |
|---|---|---|---|---|
| Piper | "Which note is lower?" | `whichIsLower67` | yes | no |
| Clef | "Which note is higher?" | — | **no** | no |

## Ordering

Not recorded. The source draft has a paired "and…" line (Piper: "Put them in order — the
lowest down at the bottom…", Clef: "…and the highest up at the top."). **There is no
`VoiceLine` member for ordering in the code.** Nothing is wired and nothing is recorded.

**Only one direction is needed.** On a vertical tree there is a single correct arrangement,
so "low to high" and "high to low" describe the same ladder from opposite ends and place the
instruments identically. Neither line counts the instruments, so both work unchanged for
two- and three-instrument ordering.

## Wrong-answer nudges

Two pools, one per character. Lines belong to their character. **Avoid immediate repeats**
rather than picking at random; track the last played per character and exclude it. The
rotating pool itself is not built (Trello card KmufGcge). Today a round always plays the
fixed 2-3/4-5 line.

| | Clef | Piper |
|---|---|---|
| 2-3 / 4-5 (wired, fixed) | "Ooh, nearly! Listen again." `tryAgainClef` — wired | "Nearly! Have another listen." `tryAgainPiper` — wired |
| 4-5 (recorded, unwired) | "Ooh, so close! Let's hear that again." `tryAgainClef45` | "So close! Let's hear it again." `tryAgainPiper45` |
| 6-7 | **not recorded** | "Not that one — one more listen." `tryAgainPiper67` (recorded, unwired) |
| 8+ | — | "That's not it. Try again." `tryAgainPiper8plus` (recorded, unwired) |

**Removed from the first version:** two Clef lines, "Ooh, not that one. Listen again." and
"Ooh, that's not it. Listen again.", do not exist in the code or the script of record. They
are not candidates for the pool unless someone writes and records them.

The pool design holds: these describe the answer rather than judging the attempt, and the
Piper pool is deliberately shared across bands rather than a compromise.

## Arrow cue

| Character | Line | Enum | Recorded | Wired |
|---|---|---|---|---|
| System cue (not a character) | "Tap the arrow when you're ready." | `tapTheArrowWhenReady` | **no** | yes |

Played once per session, the first time the earned arrow appears at A0. **It is wired but has
no recording**, so it currently plays as a silent no-op. It is not spoken by either character;
the `isPiper` value on this member is bookkeeping and does not assign a speaker.

## Retired and naming

- **`putClefOnLow` does not exist.** The first version of this doc flagged it as a
  misnamed file still in the app. It was renamed on 2026-09-01 (commit `4c49ceb`, Card 101)
  to `putMeOnLow` and later to `giveMeLow`. Nothing in the current code, assets, tool or
  tests refers to it. The warning is withdrawn.
- **`giveMeHigh`/`giveMeLow`** still carry the first-person framing in their names. They
  name the line's content, not its character, and they retire with the rest of A2.
- **Historical enum names:** `putMeOnHigh` → `giveMeHigh` (2026-09, when the drag direction
  reversed).

---

# LOUD or SOFT

Not yet recorded. A full draft inventory of roughly fifty lines exists separately and should
be folded in here once agreed. There are no `VoiceLine` members for it.

**Cast:** Clef owns LOUD, Piper owns SOFT — the same poles as High vs Low, because the two
genuinely correlate.

**Loud and soft live in the DELIVERY, never the recording level.** A stage whisper reads as
quiet while staying audible; an actually-quiet take is the first thing lost on an iPad speaker
in a noisy room. Record everything at the same level and let performance carry it.

**Not first person** — the drop target is the dial, so there is nobody to hand anything to.

---

# CAPTIONS — do not record

On-screen text, in `HighLowGameState.captionText` and `secondaryCaptionText`. A separate
string with a different audience: the watching adult, who cannot rely on the child to read
it. Captions are keyed by agency stage and pole only. They do not vary by age band or tier.

| Stage | Pole | Caption (as in the code) |
|---|---|---|
| Observe (A0) | both | "Encourage them to tap each instrument." |
| Explore (A1) | higher | "Let them tap both and find the higher one." |
| Explore (A1) | lower | "Let them tap both and find the lower one." |
| Drag (A2) | higher | "Help them drag the higher instrument up the tree." |
| Drag (A2) | lower | "Help them drag the lower instrument up the tree." |

**Secondary guidance** appears in Explore only, about six seconds into an unanswered round:

| Pole | Secondary caption |
|---|---|
| higher | "Encourage them to keep tapping the higher one." |
| lower | "Encourage them to keep tapping the lower one." |

Observe and Drag have no secondary caption. Their six-second nudges were removed along with
the timed move-on control (Trello card xpAkja5b).

**Corrections against the first version:**

- The A0 caption is "Encourage them to tap each instrument." (the first version said "Let
  them explore freely.").
- "Clef sparkles when they find it" is not in the code and is withdrawn.
- The A2 captions were rewritten for the tree on 2026-09-27 and no longer name a character.
  The "⚠️ needs rewriting" is resolved.

**Open contradiction, not yet resolved.** The first version said that at 4-5 captions should
use "low" rather than "lower". The code's own design says captions vary by stage and pole
only, not by age band, so this rule cannot be honoured with the current caption set. Pick
one: either the captions split by band, or the "low"/"lower" rule is dropped.

**A0 does not name which character owns which pole.** It hands the parent the answer, and a
parent who says it aloud removes the listening.

---

## Reconciliation log

Changes made when this doc was first checked against the code:

- **Wording corrected:** A0 lines (canonical 4-5 wording), Explore's Piper line (no "Ooh,").
- **Added, recorded:** 4-5 and 6-7 lines for A1, A2 and nudges; the 8+ nudge; the arrow cue.
- **Added, not recorded:** Clef's 6-7 second-note line, Clef's 6-7 A1 and A2 and nudge, the
  ordering lines, the agreed 2026-10-05 A2 replacements.
- **Marked as not existing:** the two Clef nudge lines in the first version, and
  `putClefOnLow`.
- **Marked as wired without a recording:** `tapTheArrowWhenReady`.
- **Corrected status:** the A2 caption rewrite has landed; the "sparkles" caption is withdrawn.
- **Open:** the low/lower caption contradiction.

---

## Maintenance

Update this file whenever a line is added, changed, wired, unwired or retired, in the same
commit as the asset. A line that exists only in a Trello card or a chat is a line that will be
re-litigated.
