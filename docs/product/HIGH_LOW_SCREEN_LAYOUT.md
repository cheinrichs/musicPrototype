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
  quarter of its width off the right edge, and **Clef on the branch that
  reaches left** — not on a platform, so all three platforms can be slots.
- **The game's name and the round instruction on a cream plate, centred over
  the meadow** (see "The caption" below). Listen Again below the stumps.
- **Close top-left, Skip top-right.**

The high/low reading survives the recomposition: Clef is up the tree, Piper is
on the ground.

**The A4 ordering screen has not moved.** It still draws the previous
four-platform tree with Clef on the top platform, in its own copy of the old
geometry (`OrderingTreeScene`). Whether it should follow onto the new tree is
an open question for Cooper.

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

**Which platform holds the slot** (`SceneLayout.slotPlatformFor`):
- **High** → the top platform (index 0) — "up on top".
- **Low** → the bottom platform (index 2) — "down at the bottom".

The widest contrast three platforms allow, now that Clef sits on the branch
rather than the top platform (before 2026-10-06 it was the platform under Clef
and the bottom one of four).

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

### The tree: full height, a quarter off the right edge

**Smaller does not work, and that was tested** at 55%, 65%, 80% and full
height. The platforms are about a tenth of the image's width, so at any size
where the canopy stays clear of the meadow they are too small to aim an
instrument at. What the crop removes is only trunk and a hollow. The branch
reaching left overhangs the meadow, which is acceptable where it isn't covering
text. Platform and perch positions were measured off the art on a grid; see
`SceneLayout.platformCentres` and `SceneLayout.perch`.

### Invariants (tested in `scene_layout_test.dart` / `high_low_screen_test.dart`)

1. **The tree is full height with a quarter off the right; every platform face
   is on screen and inside the safe area.**
2. **Clef sits on the branch**, fully on screen, covering no platform.
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
  Clef without their boxes overlapping. The group is centred in that band; the
  gaps either side of it are half the edge margin.
- **The A0 earned arrow** sits in the open air below the branch, between the
  last instrument and the platform column, level with the middle of the
  instruments. It is big, bright and gradient-filled; Skip is small, cream and
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

Decided 2026-09-27 (Cooper: "game name large, parent instruction smaller
beneath it, both inside the tan bubble"). This game's name is **"High vs
Low"**.

**Both lines are adult-facing.** The child can't read either one — the name
is orientation for whoever's sitting alongside, not a heading for the player,
same audience as the instruction beneath it.

**The name is constant; only the instruction changes per round**, so only the
instruction crossfades between rounds — the plate and the name never rebuild
for that (`HighLowCaption`). The instruction's own wording changed too, now
that the target is a slot rather than a character: "Help them put the higher one
up on top" (reworded 2026-10-05 from "drag ... up the tree", which named a direction
of travel and was wrong for the lower pole), not "...to Clef." The caption is a separate string
from the voice line and has a different audience (the watching adult, not the
child) — it doesn't need the voice line's social "by me" framing, just an
accurate instruction. Don't let one drive the other's wording.

**Grows taller, never wider.** A second line was the reason for this
restructure; solving it by growing the bubble sideways instead would crowd the
close button on one side and Skip on the other. `HighLowHeader` reserves a
fixed width on each side regardless of what the caption contains — it only
ever asks for more *height*.

**Centred over the meadow, not the screen** (Trello card 187). The composition
is no longer symmetric, and screen-centred text lands in the tree's canopy.
`HighLowScreen` passes `HighLowHeader` a caption span from just right of Close
to the tree's left edge (`SceneLayout.meadowRight`); Close and Skip stay at the
edges. On a phone whose meadow is narrower than 280 px — an iPhone SE — the
plate reaches into the canopy rather than squeeze the instruction onto three
lines; it can, because the plate is opaque. Without a span, `HighLowHeader`
still centres the caption on the screen between equal `sideWidth` columns.

- **Skip** is a small cream pill: the icon and the word, nothing else. It was
  far too large, with a subtitle; Cooper is fine losing the text for now.
- **Caption plate** is a switch (`HighLowCaption.defaultPlate`), not a layout:
  on or off, the padding is identical, so flipping it moves nothing. On = the
  cream plaque with warm dark brown text; off = white text with a soft shadow.
  **On** (Trello card 187, 2026-10-06). It was switched off on 2026-09-28
  while the text sat on open sky; with the tree behind part of it, plain text
  doesn't read, and it was already low-contrast against pale sky before the
  new tree (confirmed on device).

## The progress indicator is gone (a decision, not a deletion)

Cooper: "it's only 5 rounds and it's always 5 rounds." It told the child nothing.
**Bring it back if round counts stop being fixed** — adaptive lengths, or A1
completing on taps rather than a round count — because it then becomes
meaningful again. If it returns it must stay a separate, small, non-interactive
object, never merged with Skip (progress is colourful and small children poke
it; Skip is the adult's quiet control).

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
