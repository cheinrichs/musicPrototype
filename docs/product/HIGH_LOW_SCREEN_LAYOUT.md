# High/Low — Screen Layout, Character Art and Poses

The rules behind the play screen's composition. The numbers live in
`lib/games/high_low/models/high_low_layout.dart` (pure geometry, tested at real
viewports); this file is the reasoning, so a change to one is a change to both.
Tier and agency rules are in `HIGH_LOW_TIERS.md`; the design rules that
recur in Cooper's feedback are summarised at the end.

## One composition, built for three instruments

The layout is designed once for three instruments. The two-instrument screen is
that same composition with one instrument removed — nothing is re-flowed between
them, because small children find things again by position.

## Prominence follows the task

The character the child is asked to drag to (the *target*) is the prominent one.
The one waiting at the edge recedes to `waitingRatio` (0.68) of the target's
height. Depth from standing at the screen's edge is a secondary effect and must
never outrank the task. Where nothing is being asked (A0, observe) the two are
the same size. `high_low_layout_test.dart` checks target > waiting and that the
ratio stays below 0.85, so a later "just make her bigger" edit fails loudly.

Sizes come from the screen height; edge characters are kept inside the safe area
including their speaking pulse (Clef's right hand was running off the screen).

## Where things sit

- Centre of the screen: clear of controls. It holds the target character
  (A1 and up) or the earned arrow (A0).
- Bottom-left: Listen Again, plus the status line.
- Bottom-right: progress and Skip, side by side but **separate objects**.
  Progress is small, colourful and non-interactive (small children poke it;
  it ignores pointers). Skip is the adult's quiet control. Never merge them.
- Top: close (left), caption plaque (centre), dev report button (right).
- Bells are drawn at half size and hang slightly above their stump
  (`HighLowInstrument.floatFraction`, 0.12 of the drawn size) rather than
  embedded in it. 0.12 is a guess to be checked on a device.
- On a correct drop the instrument slides to the target. The target is painted
  *in front of* the instrument, so the celebration pose is never hidden by the
  thing it is celebrating. At rest nothing overlaps.

## Caption plaque

The prompt caption sits on the same cream plaque as every other control, with
warm dark brown text (`AppColors.inkBrown`), not black. This also removes a
legibility bug where black text sat directly on non-sky backgrounds. No plaque is
drawn when there is no caption.

## Poses

Each character has three poses, drawn by one `CharacterSprite` at one shared
scale so they never jump in size (`character_art.dart`):

| Pose | When (target character only) |
| --- | --- |
| speaking (mouth frames: closed / open / wide) | resting, and whenever it is talking |
| celebrating | on a correct drop |
| thinking | on a wrong drop, and on the idle nudge |

Only *speaking* has mouth frames; the others are single images. The one standing
by always just speaks. Thinking on a wrong drop is not a failure mark — it
describes the character, not a verdict on the child (see "describe the answer,
not the attempt").

All five layers per character stay mounted and are toggled by opacity, so a pose
change never waits on an image decode.

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

## Open: three-instrument formation for the selection screen

At T5–T8 three notes are played and the child must pick from three. The target
character (centred) and a centre-back pedestal both want the middle of the
screen. Recommendation: in three-instrument rounds the target stands at an
edge, at target size, and the middle-back position belongs to the pedestal.
Not built until confirmed.

## Design rules this leans on

Prominence follows the task; ticks on correct only and nothing on wrong; motion
means one thing (who is sounding) and there are no idle loops; a sound and a
visible event go together; layout does not reflow; progress and Skip are
separate; chrome is on cream plaques with warm brown, no true black in the scene.
