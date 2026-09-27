# High/Low — Screen Layout, Character Art and Poses

The rules behind the play screen's composition. The numbers live in
`lib/games/high_low/models/scene_layout.dart` (pure geometry, tested at real
viewports); this file is the reasoning, so a change to one is a change to both.
Tier and agency rules are in `HIGH_LOW_TIERS.md`.

## One scene for every level

Decided 2026-09-26 (Cooper: "let's try the tree version at all levels and
agency and we'll see if it works"). Two instruments (A0–A2), three instruments
and the A4 ordering screen are the **same composition with more or fewer things
in it**:

- **Instruments on stumps, at the left.**
- **The tree at the right**, with both characters on it: **Clef on the top
  platform, Piper on the bottom one.**
- **Caption centred at the top; Listen Again directly beneath it, centred.**
- **Close top-left, Skip top-right.** Nothing along the bottom.

Why: agency is an independent axis, so the scene must not rearrange each time a
child moves up a level; only the task changes. It also removes the centre
character, which was the root of a run of patches (Clef oversized, the arrow
colliding with a character, the A0-versus-A1 centre contest, Listen Again
shuffling sideways).

This is an experiment to be judged on a device. If A0/A1 turn out to be worse
for it, an alternate two-instrument arrangement for the lower levels is an
acceptable outcome — it just costs the consistency argument.

### Invariants (tested in `scene_layout_test.dart` / `high_low_screen_test.dart`)

1. **Clef's platform is above Piper's.** Clef owns high, Piper owns low, so the
   scene restates the concept every round at no cost, most valuably at A0/A1
   where high and low are introduced. Where a character stands tells the child
   which *pole* is being asked about — never which instrument sounded higher.
2. **The instruments do not lose prominence.** At A0/A1 tapping them is the
   whole activity. They stay at half the screen height (0.50 H), far larger than
   the characters, and the tree may not squeeze them.
3. **The tree is present at every level; its slots are drawn only where
   something can be placed** — the A4 ordering screen. On the play screens
   (A0–A2) the tree is scenery and character seating, with no receptacles: an
   empty slot on a screen where nothing can be placed is a false affordance a
   small child will spend real time failing at. At A2 the drop target is the
   character on her perch (the existing lean-in cue), not a slot.
   **Known weakness:** the tree art has four platforms baked in, so the two
   middle platforms are visible, empty, wooden discs at A0/A1/A2. They are not
   marked as receptacles (no "?"), but they can still look like places to put
   things; they cannot be hidden without a different tree image.
4. **The layout never reflows.** Stump positions depend only on the index and
   the count, never on what has been picked up. A vacated stump shows a greyed
   ghost on the ordering screen.
5. **Both characters are the same size**, and stay put. Being this round's
   target changes pose and the drop lean-in, not size or place.
   *Superseded:* "prominence follows the task" (target larger than the one
   standing by) — it was a size that changed per round, which this composition
   cannot do without rearranging the scene.

## Where things sit

- Ground line (stump surface): 0.16 H up from the bottom. The tree's top
  platform's feet are at 0.355 H; the bottom platform is a little below the
  stumps' line. The tree is centred about 0.78 W across, pulled in if the
  right-hand platform would touch a notch.
- Instruments: packed left to right from the safe-area edge, pitch at most 1.12
  boxes, so two instruments look like two and a free column remains before the
  tree.
- **The A0 earned arrow** sits in that free column, level with the middle of the
  instruments. It is big, bright and gradient-filled; Skip is small, cream and
  quiet. With the old "I want something new" subtitle gone, that difference in
  how they *look* is what tells a child's control from an adult's — do not let
  the two converge into a matched pair.
- On a correct drop the instrument slides to the target's perch and shrinks to
  the size an instrument has on the tree, and the target is painted **in front
  of** it, so the celebration pose is never hidden by the thing it celebrates.
  (Found in an offscreen render: the piano covered Clef.)
- Bells are drawn at half size and hang slightly above their stump
  (`HighLowInstrument.floatFraction`, 0.12); the number is a guess to check on a
  device.
- A drop that lands exactly on a header control (Listen Again, Skip, Close) is
  taken by that control, not by the scene. Aim the tree, not the middle.

## Header

`HighLowHeader` reserves the same width on both sides of the caption
(`sideWidth`), so the caption is centred on the *screen*. It used to sit well
left of centre because the right-hand side was narrower than the left.

- **Skip** is a small cream pill: the icon and the word, nothing else. It was
  far too large, with a subtitle; Cooper is fine losing the text for now.
- **Caption plate** is a switch (`HighLowCaption.defaultPlate`), not a layout:
  on or off, the padding is identical, so flipping it moves nothing. On = the
  cream plaque with warm dark brown text; off = white text with a soft shadow.
  Cooper is undecided (most concept art has none; the newest concept uses a tan
  banner). The case for the plate is legibility — the caption now sits over
  trees and hills, and a caption whose audience is the watching adult is
  worthless if it vanishes. On by default.

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

| Pose | When (target character only) |
| --- | --- |
| speaking (mouth frames: closed / open / wide) | resting, and whenever it is talking |
| celebrating | on a correct drop |
| thinking | on a wrong drop, and on the idle nudge |

Only *speaking* has mouth frames; the others are single images. The one who is
not the target just speaks. Thinking on a wrong drop is not a failure mark — it
describes the character, not a verdict on the child ("describe the answer, not
the attempt").

**The non-speaking character is never made transparent.** It was dimmed to 55%
while the scale pulse was the only speaking cue. Removed (Cooper: "i don't like
that"): reduced opacity already means *unavailable*, which is wrong for a
character who is present and simply not talking — it makes them look as if they
are leaving; and the mouth animation now carries the cue the dimming covered.
If de-emphasis is ever wanted, alpha is the wrong channel — a small drop in
saturation or contrast keeps a character solid. Don't build that until someone
asks. Until Piper's real mouth frames land her cue is the pulse alone and reads
weaker than Clef's; the answer to that is her frames, not the dimming.

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

## Simulator screenshots without tapping

`tool/screenshot_main.dart` is a separate entry point that opens one scene
directly (A0, A0 with the arrow, A1, A2, a correct or wrong A2 drop, the
ordering screen with two or three instruments). Write the scene name into
`/tmp/hl_scene`, build with
`flutter build ios --simulator --debug -t tool/screenshot_main.dart`, install,
`xcrun simctl launch`, then `xcrun simctl io <udid> screenshot` (the framebuffer
is portrait; rotate 90° clockwise to read it). Nothing in the app imports it.

## Design rules this leans on

Prominence follows the task *for what the child acts on* (the instruments);
ticks on correct only and nothing on wrong; motion means one thing (who is
sounding) and there are no idle loops; a sound and a visible event go together;
the layout does not reflow; progress and Skip are separate objects; transparency
never means "not the speaker"; chrome is on cream plaques with warm brown, no
true black in the scene.
