# High/Low — Screen Layout, Character Art and Poses

The rules behind the play screen's composition. The numbers live in
`lib/games/high_low/models/scene_layout.dart` (pure geometry, tested at real
viewports); this file is the reasoning, so a change to one is a change to both.
Tier and agency rules are in `HIGH_LOW_TIERS.md`.

## One scene for every level

Decided 2026-09-26 (Cooper: "let's try the tree version at all levels and
agency and we'll see if it works"), refined 2026-09-27, recomposed
2026-10-06 (Trello card 187, decided with Cooper 2026-10-04/05). Two
instruments (A0–A2) and three are the **same composition with more or fewer
things in it**:

- **Piper on the ground at the left edge**, at foreground scale.
- **The instruments on stumps through the middle**, set back in space.
- **The tree on the right** (`PitchTree_v2.png`), full screen height with a
  quarter of its width off the right edge, with **Clef on the middle platform
  when two instruments are in play (card 214: high above him, low below), and
  on the branch reaching left when three are** (see "Clef's seat" below).
- **One top row** (card 216): Close on a cream plate, a short progress bar,
  the round's one-line instruction on its plate, Skip. No game name.

The high/low reading survives the recomposition: Clef is up the tree, Piper is
on the ground.

**One tree across the whole game** (Cooper, 2026-10-07, Trello card 188):
the A4 ordering screen uses the same tree and the same scene, without Piper.
The tree's job is that height means pitch; a child who meets one tree while
choosing and another while ordering learns that less firmly, not more.

## Clef's seat says how many slots are in play

Decided by Cooper, 2026-10-07 (Trello card 188), revised 2026-10-12 (card 214):

- **Two instruments:** Clef sits on the **middle platform**. High goes above
  him, low below. A clef is a reference pitch — the thing every other note is
  placed relative to — and it is where he sits over the Loud or Quiet dial too.
  It also makes "on top" true of the screen; with him on the top platform it was
  not. Still one slot per round.
- **Three instruments:** Clef moves to the **branch**, freeing all three.

**He is sized to fit between the shelves** (`SceneLayout.characterHeight`): the
gap from the middle platform up to the top slot, at his largest pose. The shelves
are about a sixth of the screen apart and he used to be a quarter of it tall, so
at his old size his head stood in the top slot. That is about half his old
height, one size in either seat — for Cooper to judge on device.

**A platform with Clef on it must look clearly unlike a live drop slot**, or a
child will try to put an instrument where he is sitting. Slots carry a visible
treatment (`OrderingSlot`: a dark dip with a "?") and his platform doesn't.
Watch on a device: the dip was designed on the old tree's darker wood and
barely shows on this one's, so the "?" is doing most of the work.

Why: agency is an independent axis, so the scene must not rearrange each time a
child moves up a level; only the task changes. It also removes the centre
character, which was the root of a run of patches (Clef oversized, the arrow
colliding with a character, the A0-versus-A1 centre contest, Listen Again
shuffling sideways).

This is an experiment to be judged on a device. If A0/A1 turn out to be worse
for it, an alternate two-instrument arrangement for the lower levels is an
acceptable outcome — it just costs the consistency argument.

## The drop target is a slot on the tree, not a character

Decided 2026-09-27 (Cooper: "if we're using the tree visually in the 2
instrument setup, we should change the voice lines to be 'Bring the high one to
the tree' and have a slot for it on the tree available"). This superseded the
"drag the instrument to Clef/Piper" mechanic build 69 shipped with.

**Why it's worth the churn.** Dragging to Clef means "high" only because the
child has *learned* Clef means high — a symbol standing in for the concept.
Dragging to a slot near the top of the tree means high because it is
physically up there. The action becomes the concept instead of a convention
that requires instruction — the same reason the A4 ordering tree works at all.
It also dissolves the target-prominence problem outright: nobody needs to be
the biggest thing on screen for this to work, so the "Clef is oversized"
tuning problem stops existing rather than being solved.

**One slot, not two, for a two-instrument round** — two slots would quietly
become a two-item ordering task, a harder and different thing to ask.

**Which platform holds the slot** (`SceneLayout.slotPlatformFor`): the
highest platform Clef isn't on for a high round, the bottom one for a low
round.
- **Two instruments** (Clef on top): **high → the middle platform**, low → the
  bottom. This still reads as up because the slots are relative: the higher
  of the two available.
- **Three instruments** (Clef on the branch): high → the top, low → the
  bottom.

*Wording to recheck with Cooper:* the Decide caption says "put the higher one
up on top", and the agreed (unrecorded) Clef line "up here on top". With two
instruments the high slot is just under Clef: "up here" is right, "on top"
means the top of the available ones.

**No character may overlap a drop slot.** Piper's tail used to cover half the
bottom slot when she stood right of the tree. Moving her left fixed it, and
`scene_layout_test.dart` checks it at every phone size rather than assuming
it, because a character over a target can reappear in any arrangement.

**Slots render only where something can be placed.** None at A0/A1 (nothing is
draggable there — an empty slot would be a false affordance a small child
would spend real time failing at); exactly one at A2; all three (besides
Clef's own) at A4. Reuses the A4 ordering screen's own slot widget
(`OrderingSlot`/`SlotState`) — empty, hovering, or gone once this round is
answered correctly (the landed, ticked instrument shows in its place, so
nothing doubles up the same information).

**A miss is a real miss.** The slot's hitbox is generous — wider than the
platform's own face, matching the A4 ordering screen's slots — but it is no
longer the *entire screen*. A release outside it does nothing at all: no
wrongness recorded, and no spring-back animation is needed, because the
instrument never visually left its stump during the drag (its
`childWhenDragging` stays dimmed in place; only a floating copy follows the
finger). This is a real behaviour change from build 69, where any release
anywhere on screen counted as an answer.

## Observe: heard-it rings, then the instruments fly to the tree

Trello card 173 (Cooper, 2026-09-27): the child taps each instrument as often
as they like; each one **heard** gets a mark that stays; once every one has
been heard the earned arrow appears; when the child chooses to tap it, the
instruments **fly to the tree one at a time, lowest pitch first**, so the
last thing they watch is the highest one rising.

- **The "heard it" mark** is a thin cream ring, edged in warm brown, lying on
  the ground under the instrument. Deliberately quiet: it must not read as
  the Explore sparkle ("this is the answer"), nor as the glow removed from
  playing instruments, nor as a tick (ticks mean a correct placement). No
  glow, no blur, no motion. One candidate look, for Cooper to judge.
- **The arrow goes** once it has sent the instruments flying.
- **The flight** uses `ArcFlight` (`lib/ui/components/arc_flight.dart`), the
  one primitive every instrument flight uses, so the gesture looks the same
  wherever a child meets it (the drag-demonstration card is next). The arc
  **rises first and then slides level onto the platform**, finishing its
  shrink before the final approach. It used to lift over and drop down onto
  the platform, which passed straight through Clef when he sat on the top
  platform; a test checks every frame of the flight against him, and with him
  on the middle shelf the same shape carries the high one in over his head.
- **Where they land:** the free platforms, bottom up — with two instruments
  the bottom and the top (Clef has the middle), with three all three.
- **They rest there for a beat** (`HighLowGameState.observeFlightHold`, 1.2 s)
  before the next round, or the highest one would be swept away the instant
  it arrived.
- **Behind a switch until Cooper has seen it:** the dev gate's "Arrow: Next /
  Fly" chooses between the old immediate advance and the flight; children's
  games keep the immediate advance. The rings are on for everyone.

## The celebration is the social payoff — it must fire reliably

The voice line still asks a favour ("pop the high one up here by me" —
see "Voice lines" below), so the character being visibly pleased afterwards is
what makes it read as one, not just a correctness mark (the tree slot now
carries "correct" durably via its tick). This makes the celebration pose more
important than it looked before this change: it is carrying the exchange's
whole social payoff. `_poseFor`'s celebrating branch and the "fires every
time" tests must keep working for every correct placement, including after a
preceding wrong attempt.

**Which character asks is not an enforced rule.** Clef narrates high rounds
and Piper narrates low ones because that is who is naturally positioned to —
not because of a designed, protected binding. See `CHARACTER_VOICES.md` for
why that was walked back, and for the one thing that *does* still matter on
its own merits regardless: Clef's voice stays audibly higher than Piper's.

**The cost, recorded rather than quietly lost:** High/Low no longer has a
character as the literal recipient of the correct instrument — some of the
original "handing something to a friend" warmth is gone. Keeping the voice
lines personal ("by me", not "to the tree") and making the celebration matter
more is how most of it is recovered, not eliminated.

## Piper is off the tree

Decided 2026-09-27, after Cooper saw the first tree build on device: Piper
used to perch on a lower platform, which rendered her tiny against the tree's
own perspective. "Just have her standing beside the tree on the right at her
proper scale. She should probably stand so her head reaches the 3rd tree
platform, her feet could be cut off on the frame and I think that's okay."

- She stands on the ground, anchored to the screen's right edge
  (`SceneLayout.piperRightInset`), not centred on anything — she is no longer
  on a platform.
- Her height (`SceneLayout.piperHeight`) is a clearly larger, "foreground"
  scale — deliberately not Clef's `characterHeight`. **A guess to check on a
  real device**, the same spirit as the bells' `floatFraction` elsewhere in
  this scene.
- The one hard constraint is her head reaching the tree's third platform
  (Cooper's own words); her feet may fall below the visible frame as a
  consequence, and that is the accepted look, not a bug — the background
  layer's default clip crops her there, the same way it always clipped
  anything positioned past the screen edge.
- Every other frame of hers — pulse, poses, sparkle, the "never dimmed"
  rule — is identical to Clef's; only her position and scale are different
  (see `HighLowScreen._buildPiper` vs `_buildClef`, which share one inner
  `_characterCore` builder).

This also frees her old platform for a slot (see above) — a second, unplanned
benefit of the move.

### Piper moves to the left edge (2026-10-06, Trello card 187)

Pushing the new tree a quarter off the right edge removed the ground she stood
on, so she stands at the **left edge**, full foreground height, feet cropped at
the ankles at most (`SceneLayout.piperLeftInset`, measured to her widest pose).
This breaks any voice line in which Piper says "here by me" — already handled:
the Decide lines name the position, not the speaker (see `VOICE_LINES.md`).

**Half again as big (2026-10-08, Trello card 192):** three-quarters of the
screen's height, up from half — **capped where the touch-target floor would
break.** Her width comes out of the instruments' room, so on a phone as narrow
as an iPhone SE the full size would push the smallest instrument below 64 px;
there she is as big as the floor allows (about 0.6 of the height). Every
notched phone has room for the full size. The cap is worked out for two
instruments, so a three-instrument scene has the same Piper. Once the
six-second guidance makes the caption plate taller, the plate comes down over
her ear tips on an iPhone 14 — chrome over scenery, not over a target; for
Cooper to judge on a device.

### The tree: full height, a quarter off the right edge

**It bleeds past the top and bottom of the screen** (2026-10-08, Trello card
190): 2% of the height each way. The art has a few transparent rows under its
roots, so fitted exactly it left a gap at the bottom. It grows about its left
edge, so the instruments' room — what the touch floor needs on an SE — is
unchanged; the extra width goes off the right.

**Smaller does not work, and that was tested** at 55%, 65%, 80% and full
height. The platforms are about a tenth of the image's width, so at any size
where the canopy stays clear of the meadow they are too small to aim an
instrument at. What the crop removes is only trunk and a hollow. The branch
reaching left overhangs the meadow, which is acceptable where it isn't covering
text. Platform and perch positions were measured off the art on a grid; see
`SceneLayout.platformCentres` and `SceneLayout.branchPerch`.

### Invariants (tested in `scene_layout_test.dart` / `high_low_screen_test.dart`)

1. **The tree is full height with a quarter off the right; every platform face
   is on screen and inside the safe area.**
2. **Clef's seat follows the instrument count** — the middle platform with
   two (high slot above him, low below), the branch with three — fully on
   screen, and never on or in a slot.
3. **Piper stands at the left, inside the safe area**, clearly larger than Clef,
   cropped at the ankles at most.
4. **The instruments stand between them**, clear of each other, of both
   characters and of the platform column.
5. **The touch-target floor.** The smallest instrument (the bells, at half
   size) never falls below `SceneLayout.minTouchTarget`, 64 logical pixels.
   That, not looks, limits how far back the stumps go. On an iPhone SE it is
   the binding constraint.
6. **One floor.** The stumps' ground line agrees with the tree's base — within
   5% of the height of the bottom platform.
7. **No character overlaps a drop slot.**
8. **Exactly one slot platform per round.**
9. **The layout never reflows.** Stump positions depend only on the index and
   the count, never on what has been picked up.
10. *Superseded, 2026-10-06:* "the instruments stay at half the screen height"
    — card 187 sets them back in space (smaller and higher), bounded by the
    touch-target floor instead.
11. *Superseded, 2026-09-27:* "both characters are the same size" and
    "prominence follows the task" (the target character larger than the one
    standing by) — both were about a centre character that no longer exists;
    see `HIGH_LOW_TIERS.md`'s own superseded-decision note for the parallel
    case on the three-note layout.

## Where things sit

- Ground line (stump surface): 0.225 H up from the bottom (0.775 H down), where
  the tree's root flare meets the grass and 0.036 H below its bottom platform.
  Raised from 0.16 H. An earlier attempt to raise it was reverted because the
  old tree's bottom platform could not move; this tree's base is where the
  stumps now stand.
- Instruments: 0.38 H, down from 0.50 H, capped so two fit between Piper and
  the platforms without their boxes overlapping. The group is centred in that
  band; the gaps either side of it are half the edge margin.
- **The A0 earned arrow** sits in a column the layout reserves for it, between
  the last instrument and the platform column, level with the middle of the
  instruments.
- **Listen Again** (2026-10-08, Trello card 191): the icon and the words on one
  cream pill, like every other control, centred between the stumps. It was
  dark text on the dirt path, barely legible, and read as left of centre
  because the eye centred on the bare icon. The text stays: a parent benefits
  from knowing a replay exists.
- **Explore's correct-tap sparkle is on the instrument** (2026-10-08, Trello
  card 189, Cooper: "the indicator needs to be on the instrument"). The child is
  identifying an instrument, so the answer lands on the thing they chose; on a
  character it read as "Clef approves" rather than "that one". One ✨ per
  correct tap so far, at the instrument's top-right, staying for the round:
  **progress** toward the confetti at five, where the music notes are a per-tap
  **response** that resets. Each ✨ pops in once and then holds still (no idle
  motion). It is big, bright and gradient-filled; Skip is small, cream and
  quiet. With the old "I want something new" subtitle gone, that difference in
  how they *look* is what tells a child's control from an adult's — do not let
  the two converge into a matched pair.
- On a correct drop the instrument slides to the slot and shrinks to the size
  an instrument has on the tree, and the asking character is painted **in
  front of** it, so the celebration pose is never hidden by the thing it
  celebrates. (Found in an offscreen render: the piano covered Clef.)
- Bells are drawn at half size and hang slightly above their stump
  (`HighLowInstrument.floatFraction`, 0.12); the number is a guess to check on a
  device.
- A drop that lands exactly on a header control (Listen Again, Skip, Close) is
  taken by that control, not by the scene. Aim the tree slot, not the middle.

## The caption

**In the top row, one line, adult-facing** (Trello card 216, 2026-10-13). It sits
between the bar and Skip. The child can't read it; the voice carries the
instruction and the caption is quiet redundancy for the adult alongside (card 211).

- **No game name.** "High vs Low" and "Loud or Quiet" came off: a non-reader cannot
  use them, and a child looking at the screen knows what they are playing.
- **Written short, never set small.** A row-height slot takes one line, so every
  caption is at most `HighLowCaption.maxLength` (30) characters, which fits whole on
  an SE; the games' tests hold the copy to it. Current copy: "Encourage them to tap
  both." / "Find the higher one." / "Higher one goes on top." / "Lower one goes
  below." The caption is a separate string from the voice line, with a different
  audience; don't let one drive the other's wording.
- **Guidance joins beneath, never replaces** (card 193). Explore's six-second line
  ("Keep tapping the higher one.") fades in under the instruction; the plate grows
  downward and nothing else in the row moves. Out of the scene, it can no longer
  push the caption over Piper's head on an SE.
- **The plate is a switch** (`HighLowCaption.defaultPlate`), not a layout: off draws
  white text with a soft shadow at identical size. On since card 187.
- **Skip** is a small cream pill: the icon and the word, nothing else.
- **Close sits on a solid cream plate** with a bold warm-brown cross — the same
  backing as Skip. A light glyph with no backing vanished into the art (the third
  time: card 150's credits button, card 215's "?"). The whole plate takes the tap,
  and nothing in the row is moved by a translate (that once left most of Close dead).

## The progress bar is back (Trello card 196, 2026-10-12)

It was removed when every set was five rounds ("it's always 5 rounds"). It returned
once set length began to vary by agency (Observe 3, Explore 4, Decide 5, from the
shared `RoundSetLength`), and once Cooper watched what it does for a small child: it
tells him the thing will end. For a three-year-old the bar is a contract, not a reward.

- **One continuous bar, not pips.** It fills a step as each round ends. It lives in
  `RoundSetProgressBar`, shared by High vs Low and Loud or Quiet through
  `HighLowHeader.progress`.
- **Short and chunky** (card 216, superseding "the bar dominates"): a third of the
  row it used to fill, 22 px tall, and each step fills over 0.7 s with a slight
  overshoot, so a step reads as motion. At a five-round set a step is about 26 px
  on an SE — `test/render/progress_bar_steps_render_test.dart` draws every step of
  3-, 4- and 5-round sets.
- **A full bar really ends the set.** After a short beat it goes to the games screen
  (`RoundSetEnd`), never a silent restart and no longer the reward screen with
  "play again". Once stones exist, the ending becomes the stone's celebration and
  the bar counts the stone's rounds.
- **It stays a separate, non-interactive object,** never merged with Skip.
- **Sage green,** outside Loud or Quiet's cream-gold-orange loudness ramp.

## Poses

Each character has three poses, drawn by one `CharacterSprite` at one shared
scale so they never jump in size (`character_art.dart`):

| Pose | When (the asking character only) |
| --- | --- |
| speaking (mouth frames: closed / open / wide) | resting, and whenever it is talking |
| celebrating | on a correct drop, and on Explore's fifth correct tap |
| thinking | on a wrong drop, and on Explore's five-wrong-tap nudge |

Only *speaking* has mouth frames; the others are single images. The character
who isn't asking about this round's pole just speaks. Thinking on a wrong drop
is not a failure mark — it describes the character, not a verdict on the child
("describe the answer, not the attempt").

**Correct taps 1–4 at Explore get no pose change** (decided 2026-10-06): the
sound and the escalating sparkle are the per-tap reward, and celebrating each
one would flatten that escalation. **Explore's six-second guidance caption does
not drive the pose.** It used to, and since its timer runs from round start
whatever the child is doing, it put the thinking face on a child tapping the
right answer (Cooper, on device). The caption is for the parent; the pose
answers the child. Thinking on the nudge holds for the nudge line or 1.4 s,
whichever is longer — the same dwell as a wrong drop — and a correct tap ends
it at once.

**Neither character is ever made transparent.** Non-speaker dimming (55%
opacity) was tried and removed (Cooper: "i don't like that"): reduced opacity
already means *unavailable*, which is wrong for a character who is present and
simply not talking — it makes them look as if they are leaving; and the mouth
animation now carries the cue the dimming covered. If de-emphasis is ever
wanted, alpha is the wrong channel — a small drop in saturation or contrast
keeps a character solid. Don't build that until someone asks. Until Piper's
real mouth frames land her cue is the pulse alone and reads weaker than
Clef's; the answer to that is her frames, not the dimming.

## Voice lines

`giveMeHigh`/`giveMeLow` are the recorded audio still spoken at Trigger, but
the mechanic has moved on twice since they were written (first the drag
direction reversed; now the target is a slot, not a character), so "give me"
is dated: the wanted wording is something like "pop the high one up here by
me" or "bring the high one up to my branch" (Cooper) — see each enum value's
doc comment in `lib/audio/voice_line.dart`. No re-record has been made yet, so
the old, still-warm line keeps playing rather than going silent; this is a
known, documented gap, not something quietly fixed by a rename. When new
audio exists, only the enum's *content*/asset needs to change — nothing in
`HighLowGameState` selects lines by name in a way that would need updating
again.

## Art pipeline

Source art: `SongStone-UI-Kit/Assets/Cast/<Character>/` (restyled, per-character
folders). Belle is **not** wired. Reference sheets are never rendered.
`_rejected/` is not used except the Piper stopgap below.

- `tool/prepare_character_pose.py` — crop a single pose to the figure and scale
  it down (`--scale`), used for the celebration and thinking images.
- `tool/slice_mouth_frames.py` — slice a three-frame mouth sheet into equal,
  registered frames (`--crop-bottom`, `--alpha-floor`, `--despeckle`,
  `--stopgap`). Registration is by arm-free body bands; a drift over 4 px stops
  the tool unless `--stopgap` says the imperfection is deliberate.

New assets go in `assets/images/characters/<name>/`; each directory must be
listed in `pubspec.yaml` (directories are not recursive; a test checks this).
`CharacterArt` holds the frame and pose pixel sizes; a test checks them against
the PNG headers.

## Piper's mouth frames are a stopgap

Piper's proper mouth sheet does not exist yet. The frames in use were sliced from
`_rejected/Piper_MouthSheet_REJECTED_unregistered.png`, which is unregistered:
her body wobbles slightly between frames (6 px measured against a 4 px limit).

Replacing them is a file swap, not a code change:

1. Slice the new sheet with the same tool into
   `assets/images/characters/piper/piper_mouth_{0,1,2}.png`
   (three equal frames, same frame size, or update `CharacterArt.piper.frameSize`).
2. Drop `--stopgap` — the drift check should now pass.

There is no Piper-specific code path to remove.

## A3 and the three-note screen

**A3 ("Timed") is not a separate screen, and is correctly absent from the dev
agency picker.** `AgencyStage` never modelled it — its own doc comment says
so — because it is silent speed tracking layered on A2, not a visible
difference: nothing changes on screen, the app would just measure whether a
child is getting faster at the same task. There is nothing to pick.

**The three-instrument (T5–T8) selection screen's only remaining blocker was
layout**, and that blocker is gone: with no centre character to compete with
anything, there is no more "the target character and the centre-back pedestal
both want the middle" conflict (see `HIGH_LOW_TIERS.md`'s superseded-decision
note). `SceneLayout` already places three stumps and can already pick a slot
platform for any pole. The tier and prompt generator have been ready for a
while (`HighLowScreen._buildThreeNoteNotBuiltPlaceholder`'s own text says so);
this is next.

## Simulator screenshots without tapping

`tool/screenshot_main.dart` is a separate entry point that opens one scene
directly (A0, A0 with the arrow, A1, A2, a correct or wrong A2 drop, the
ordering screen with two or three instruments). Write the scene name into
`/tmp/hl_scene`, build with
`flutter build ios --simulator --debug -t tool/screenshot_main.dart`, install,
`xcrun simctl launch`, then `xcrun simctl io <udid> screenshot` (the framebuffer
is portrait; rotate 90° clockwise to read it). Nothing in the app imports it.

## Offscreen renders, no simulator needed

`test/render/high_low_scene_render_test.dart` paints the real screen — real
art, real positions — to PNG files at an iPhone SE, iPhone 14 and Pro Max size,
for every agency level and both poles:

`flutter test test/render/high_low_scene_render_test.dart --dart-define=RENDER_DIR=/some/dir`

It is skipped unless `RENDER_DIR` is set, so `make test` is unaffected. Text
draws in the test font, as solid boxes, so it shows where the caption plate
sits but not how its words read; icons are boxes too. It is a check on
composition, not a substitute for a device: it cannot show motion, a release
build's behaviour, or how the colours look on a real screen.

## Design rules this leans on

Prominence follows the task *for what the child acts on* (the instruments);
ticks on correct only and nothing on wrong; motion means one thing (who is
sounding) and there are no idle loops; a sound and a visible event go together;
the layout does not reflow; progress and Skip are separate objects; transparency
never means "not the speaker"; chrome is on cream plaques with warm brown, no
true black in the scene; a miss is silent, never a wrong answer.

**Never block, never hide (Trello card 171, confirmed as a standing rule
across the agency cards).** Drop targets are always visible and always
draggable, narration is always interruptible, and touching anything always
does something, at every agency level and every phase of a round. Bad or
premature evidence is *detected and marked* (see
`ADVANCEMENT_SIGNALS.md`'s invalid-round rule) — it is never prevented by
gating the UI. An earlier suggestion to hold the drop targets until the
prompt finished playing is explicitly withdrawn; nothing in this codebase
ever implemented it (`HighLowGameState.canDrop` has never gated on intro
state), so there was nothing to undo, but the rule is worth stating
positively so it isn't reinvented later.
