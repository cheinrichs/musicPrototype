# High/Low — Concept Tiers and the Progression Rules

Decided 2026-09-02/03. This supersedes the Pitch Awareness row of `docs/curriculum/difficulty_tiers.csv`, which predates several of these decisions.

This document covers the **concept tier** axis for High/Low only. Agency (A0–A4), skill, and age presentation remain separate axes as described in `LEARNING_ARCHITECTURE.md`.

---

## The governing rule

**One new demand per step, and relax the others when you add one.**

The ladder zigzags rather than climbing straight. Every time a tier introduces something new, it gives back difficulty somewhere else. This is not politeness — it is the only way to know *what* a child is struggling with. If two things get harder at once and she stalls, the data can't tell you which one did it.

A tier is therefore not a single number. It is a position in an ordered list of introductions.

---

## The ladder

Eight tiers, a complete 2×2×2 across three independent properties: **interval width** (wide 7–12 / narrow 4–7), **instruments** (one / varying), and **note count** (2 / 3).

| Tier | Interval | Instruments | Notes | What's new |
|---|---|---|---|---|
| **T1** | 7–12 (5th to octave) | one | 2 | — |
| **T2** | 4–7 (3rd to 5th) | one | 2 | narrower gap |
| **T3** | 7–12 (widened back) | **varying** | 2 | timbre must be ignored |
| **T4** | 4–7 | varying | 2 | narrower gap again |
| **T5** | 7–12 (widened back) | back to **one** | **3** | third note — "which is highest" |
| **T6** | 4–7 | one | 3 | narrower gap again |
| **T7** | 7–12 (widened back) | varying | 3 | both demands combined |
| **T8** | 4–7 | varying | 3 | narrower gap again |

Each new demand is introduced **on its own with everything else relaxed**, then hardened by narrowing the interval, then eventually combined. The interval widens back to 7–12 at T3, T5 and T7 — every point where something new arrives.

### On features switching off

Instrument contrast is on at T3–T4, **off** at T5–T6, back on at T7–T8. That is deliberate and correct.

An earlier draft objected to this on the grounds that a ladder should be monotonic — features accumulating and never withdrawn. That objection was wrong. It contradicts the governing rule: when you add a demand you relax the others. A ladder where nothing ever switches off *cannot* obey that rule, because there is nothing left to give back. Reverting to a single instrument while the third note arrives is the rule working, not a tidiness failure.

### Note: T7 and T8 may prove redundant

By T7 the child has mastered varying instruments (T3–T4) and three notes (T5–T6) separately. Combining two already-mastered abilities is usually easier than acquiring either, so the combination may not warrant two dedicated tiers.

Ship all eight, but **watch the tracking data** for whether T7 and T8 are actually distinguishable from T5 and T6 in practice. If they aren't, collapse them.

### Note: the narrowest interval band is gone

Every tier now uses 7–12 or 4–7. The old T4's **2–4 semitone band no longer appears anywhere**, so the tightest gap in High/Low is a major third.

This is consistent with the judgement that a near-semitone discrimination is an ear-acuity test rather than a high-versus-low one — a different skill, and a frustrating one at five. Flagged here so it stays a deliberate choice rather than an artefact of building the grid.

### Why three notes is a tier, not an agency level

Earlier framing put three notes at A4 with ordering. Separating them is better and solves the jump problem:

- **Tier** introduces the third note at T5, asked as *"give me the highest one."* Still selection.
- **Agency A4** later asks her to *arrange* them. By then three notes is familiar and the only new thing is the ordering operation.

Item count is a demand on what she can hold. Ordering is a demand on what she can do with it.

### Never advance tier and agency together

If a tier increase and an agency increase both come due, **show only the new agency and pause the tier for a stone.** Agency takes priority because it changes what she is being asked to *do*; a tier change only changes how hard the same task is.

This needs the per-round tracking log to enforce — something has to know what changed last.

### Replays

Three replays at both A3 and A4. Do not drop to zero when the third note arrives — that would tax memory load and scaffolding in the same step, and a single missed hearing would burn a round the child understood perfectly. Let the *count* of replays used be the signal rather than the constraint.

---

## Tempo is not a tier axis

The curriculum CSV lists tempo (slow → variable) as a tier parameter. Do not implement it. **The axis runs backwards for this game.**

Playing the two notes closer together is *easier*, not harder. Pitch memory decays quickly; a long gap means comparing a sound against a fading memory of a sound rather than against the sound itself. The long pause is the hard version.

The current inter-note gap is a fixed 2300 ms (`_noteRingDuration` in `HighLowGameState`). Cooper: *"it does feel like a long gap currently and it tries the patience of the little ones."* **Shorten it and tune for comfort, at every tier.** It is not a difficulty control.

Overlapping or simultaneous notes are out of scope entirely — two pitches at once is harmony, a different curriculum node.

---

## Register is not a tier axis

Register means where on the overall span of pitch the notes sit — low, middle, high — as opposed to how far apart they are.

It has a real but small effect: discrimination degrades at the extremes, because the ear resolves frequency poorly at the very bottom and musical pitch weakens at the very top. But the note pool is only two octaves (C4–B5) and all of it sits in the comfortable middle. **There isn't enough range for register to do anything**, and adding a fourth thing for tiers to control buys almost nothing.

Revisit only if the note pool is ever widened substantially. There are no plans to do so.

---

## Cross-instrument rounds: per-instrument ranges and the overlap rule

**Decided 2026-09-03. This replaces the shared note pool and the transposition offset entirely.**

### The problem being retired

Today every instrument is forced into one shared 24-slot pool (C4–B5). Guitar and tuba can't physically play most of it, so their samples were mapped down two octaves and a `realPitchOffsetSemitones = -24` was bolted on to record the discrepancy.

That created two competing ideas of what note something is — the **label** and the **sounding pitch** — and every bug in this area has come from code reading one while meaning the other. The T3+ scoring bug fixed on 2026-09-02 was exactly that.

Cooper: *"we're trying to force instruments into a register that they just don't play in... let's not force it and expand the app's rules instead."*

### The new model

**Each instrument declares the range it actually has samples for.** The label becomes the sounding pitch. `realPitchOffsetSemitones` is deleted, not set to zero — the concept goes away, and with it the whole class of label-versus-sounding bugs.

Relabelling is not a change to the audio. Those files already sound like C3; calling them C3 just stops the app lying about it.

### The overlap rule

**Two instruments may be paired in a round when their sample ranges overlap by at least the interval the tier is asking for, and the generator could place either one higher.**

That single rule does all the work:

- Tuba against flute is impossible — the ranges don't meet.
- Tuba against guitar works — they do.
- **The giveaway problem cannot occur.** If a pairing is legal, either instrument can be the higher one, so "tuba means low" is never a winning strategy.

### Why not register families

An earlier proposal sorted instruments into a low box and a high box. Rejected, because register is a property of the *samples you have*, not of the instrument. Cello runs roughly C2–A5, piano covers nearly everything, guitar about E2–E5 — all of them span any boundary you'd draw, so someone would be making arbitrary calls about which box they belong in, and re-sorting the boxes every time new samples arrive.

The overlap rule needs no boxes and no maintenance. Piano ends up as the natural bridge, since it can meet almost anything.

### Requirements

- Delete `realPitchOffsetSemitones`; relabel guitar and tuba samples to their true sounding pitch.
- Give each instrument an explicit sample range.
- The prompt generator picks pairs by the overlap rule, in real pitch throughout.
- **Test it**, in the same spirit as the existing same-instrument invariant: no generated cross-instrument prompt may pair instruments whose ranges don't overlap by the requested interval, and across many samples each instrument in a legal pairing must appear as the higher note sometimes.

### Timbre as a perceptual trap

Brightness is readily mistaken for height. A bright flute note can sound "higher" than a genuinely higher cello note because the timbre is doing the talking.

That confusion is precisely what T3 teaches past — but at a narrow interval it stops being learnable and becomes a coin flip. Hence the widened interval at T3.

---

## Never advance tier and agency in the same round

Cooper's rule, and the governing principle one level up:

> If tier and agency would both increase, the next round shows **only the new agency**, and the tier increase pauses for a stone.

Agency takes priority because it changes what she is being asked to *do*; a tier change only changes how hard the same task is.

This needs the per-round tracking log to enforce — something has to know what changed last and when.

---

## What this replaces

The Pitch Awareness row of `docs/curriculum/difficulty_tiers.csv` should be updated to match. Specifically:

- **Number of notes** (2 / 2–3 / 3–4 / 4–5 per tier) — partially retained. Three notes arrives at T5. Four and five notes are not planned.
- **Tempo** (slow / moderate / faster / variable) — **removed.** See above.
- **Interval size** — retained, but the specific bands change per the ladder table.
- **Timbral similarity** — not present in the CSV for this node, but is now a real axis, arriving at T3.

## Known bug this supersedes

`ConceptTier` currently gives T3 the same 4–7 semitone range as T2 — identical numbers, identical behaviour. High/Low has effectively had three tiers, not four. Nobody noticed from play because T3 simply felt like more T2. The ladder above replaces it.
