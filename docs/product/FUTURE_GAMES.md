# Future games: the in-a-score family

Decided with Cooper, 2026-11-13. **Nothing here is built.** It is written
down now, while the game template is fresh, so the family gets built the
cheap way when its time comes.

## One game per quality, one shared mechanic

Hearing a quality *inside music* is not a tier of the two-sound games — it
is closer to musical listening than to comparing two notes. Each quality is
its **own game, with its own name**, because the name is the musical term
for that quality:

| Quality | In a score | Game | Curriculum source (tier 4 of…) |
|---|---|---|---|
| Loud / soft | a loudness change within a phrase | **Dynamics** | Sound Awareness → Loud vs Soft |
| Long / short | within a rhythmic pattern | name TBD | Sound Awareness → Long vs Short |
| Attack | within a melody | name TBD | Sound Awareness → Attack |
| Release | phrase-based release | name TBD | Sound Awareness → Release |

"Dynamics" means loudness specifically; it would be the wrong name for any
of the others.

**But the interaction is identical**: a phrase plays, one element differs,
the child identifies which position it was. That is **one mechanic,
parameterised by which quality varies.**

## Build it on the template

When Dynamics is built, build it **on the extracted game template**
(`GameEntry` / `SetReport` / `ProgressSource` in `lib/games/game_session.dart`,
registered in `gameScreens` in `lib/games/game_catalogue.dart`) and
**parameterised by quality**, so its siblings come cheaply rather than each
being written from scratch. Concretely: the phrase-and-pick mechanic takes
the varying quality as data (what differs, by how much, along that quality's
own ladder); each sibling is that mechanic plus a name, art and a ladder.

## Agency

No timed agency level is needed (Cooper removed timing; it became
telemetry). A phrase plays, then the child picks which position was
different: that is **recall, not timing**, and works at Explore and Decide
like the existing games.

# Future task: ordering by loudness — a hard bound

Decided with Cooper, 2026-11-13. **Not built.** It bounds a future
feature, so it is written down here.

Loud or Quiet's three-instrument tiers ask for the **loudest** (or quietest).
Difficulty there is entirely **target versus nearest competitor**; the third
sound only has to sit clearly beyond them, so it sits a small fixed offset
away (`DynamicLadder.extraOffsetDb`, 3 dB), and the span a round needs is
gap + offset, not 2 × gap. Cooper: "we only need the 3 instrument tiers to
be equidistant when it moves to ordering."

**Ordering is different.** Putting three sounds in order is set by the
**smallest adjacent gap**, and equal spacing is what maximises the smallest
gap within a given span — so equidistant is the *optimum* for ordering, not
a style choice. Ordering therefore needs the **full double span**.

On this hardware the span is 12 dB: the quiet floor is −12 dB (the audible
floor on a phone speaker, never lowered — card 220) and the ceiling is full
(the loudest samples already peak at about −1 dBTP). Three equally spaced
levels get **about 6 dB per gap** — in two-instrument terms, between
moderate (8) and subtle (4).

- ⚠️ **Loud or Quiet ordering can never be an easy tier.** Its easiest
  possible version is already a mid-ladder discrimination.
- It may belong at a **higher agency** than ordering by pitch.
- This is **specific to loudness**, squeezed by the audibility floor below
  and the speaker above. High vs Low has no equivalent problem: pitch runs
  across octaves.

## Other in-a-score tier-4 rows (flagged, not decided)

The curriculum's other nodes have tier-4 (sometimes tier-3) steps that are
in music rather than harder parameters. Each may likewise identify a future
game rather than a tier — Cooper's call, node by node:

- **Rhythm & Timing** — pulse clarity: "beat embedded in music" (T3),
  "subtle or layered pulse" (T4).
- **Anticipation & Musical Punctuation** — accent strength "Embedded",
  phrase length "Full phrase".
- **Tonal Contrast & Resolution** — "Embedded in phrase" (T3), "Within
  progression", "Multi-phrase" (T4).
- **Timbre & Instrument Awareness** — "Mixed articulation in phrase" (T3),
  "Multi-instrument texture", "Register shifts within phrase" (T4).
- **Harmony & Chord Feel** — "Melody over chords" (T4).

Pitch Awareness, Contour & Shape, Guided Instrument Play and Pitch Naming
have tier 4 as harder parameters only — they keep four tiers.
