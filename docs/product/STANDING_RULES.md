# Standing rules

Rules decided once that apply to everything built from here. Each came out
of a specific bug or decision; the reason is kept so it can be applied to
cases nobody has met yet.

## Input

**Every interaction must behave correctly when tapped as fast as a child can
tap.** Spamming is not an edge case for a three-year-old, it is the default.
Treat rapid-repeat as a standard case to test for every interactive thing:
fire taps far faster than its animation and assert it still ends up right.
(Three instances before this was written down: the dial moving only on the
first of four rapid taps; decorations needing interruptible-not-queued
reactions; Explore's round hanging when the right instrument was spammed
after the confetti.)

**Input may not interfere with an advance that is already underway.** Once
a round is resolved and on its way out, later input still makes its sound —
the apparatus answers honestly when touched (card 212) — but it cannot
delay, reset, re-score or re-enter advancement. Separate "this makes a
sound" from "this counts". At Observe nothing is underway until the arrow is
pressed, so tapping stays fully live before that (card 156); the rule needs
no exception for it.

**Reactions are interruptible, not queued.** A re-tap restarts a reaction
from wherever it is rather than stacking another behind it, and the number
playing at once is capped.

## What children see

**Locked content may be visible as long as it does not reveal what it is.**
Greyed-out content showing the thing itself (its name, its picture) is a
known source of frustration for children. Journey stones stay visible
because they are interchangeable; the chest says a prize is coming without
saying which; a locked game would show exactly which game is withheld, so
locked games are hidden from a child's library, never greyed.

**Shape language.** Rail items are circles (inactive) and rounded squares
(the page you are on). Rewards are diamonds. A reward must never read as a
navigation item.

**A reward is depicted by the thing itself, not by a symbol for its
category.** A reward token is generally an existing asset in a frame (the
instrument's own art for an instrument), not bespoke per-reward art.

**Creatures make noises, instruments make notes.** Map decorations and other
ambient sounds are non-pitched — rustles, squeaks, plops, flutters; texture,
never tone. The games train pitch discrimination, which depends on pitched
sound being special.

**Objects get physical reactions, creatures behavioural ones.** Objects
wobble, squash and tip; creatures leap, withdraw, open their wings. Objects
may be mirrored (a flip only moves the light); creatures never (a flip reads
as the animal turning round). Reuse the app's existing wobble feel.

## Art and voice are provisional

All art and all voice is AI-generated, good enough for a beta, and expected
to be redone for production. Build so that a wholesale replacement is a
drop-in:

1. **Never hard-code a duration to match a clip.** Drive every timing from
   the actual playback duration — speaking motion, needle sweeps, the iris,
   the pause before a set ends. A human actor's delivery will not match
   today's clip lengths, and a timer that happens to fit breaks silently on
   re-record. (Same family as `play()` resolving on start rather than
   completion, which has bitten twice.)
2. **Assets are referenced by id, never by scattered filename.** One table
   maps ids to files (reward types: `lib/journey/reward_catalogue.dart`).
3. **Keep naming and sizing consistent across an asset family**, and keep
   state suffixes identical across families (`_locked/_current/_done`,
   `_closed_plain/_closed_glow/_open_burst`), so a replacement set drops in
   without per-file adjustment.
4. **A wired but unrecorded line must be graceful in its absence.** The
   round plays correctly in silence rather than waiting on, or erroring
   over, a missing clip.

## Builds

**Dev screens are never reachable in a public App Store build.** The dev
profile is compiled out of a release build entirely. The reading gate in
front of it on internal builds is a signpost for a child on a shared iPad,
not a security boundary, and it re-asks on every use (no session-level
"adult verified" flag).
