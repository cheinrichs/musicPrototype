# Cleanup / Reconciliation Notes

This snapshot was reconciled against the current `Ear Training Music App Skill Tree` workbook.

## Changes made only in the handoff export

The source workbook itself was **not edited**.

### Difficulty Tiers
Removed:
- Pitch Awareness → `Replays Allowed`
- Rhythm & Timing → `Replay Allowed`

Reason: current architecture places replay support under Agency/scaffolding rather than Concept Difficulty.

### UI Presentation
Corrected age-band values that Excel had auto-converted into numeric date serials:
- `46056` → `2-3`
- `46117` → `4-5`
- `46180` → `6-7`

The clean UI presentation CSV omits the generic `InteractionStyle` column because its current age-based timing assumptions conflict with the independent Agency axis. Prompt and visual scaffolding are retained and labeled as generic placeholders.

### Skill Progression
No progression values were silently changed. The CSV labels current agency ranges and prerequisites as a **working scaffold** because they were generated as an initial architecture pass and have not yet been individually reviewed skill-by-skill.

### Visuals
The older completion line `"you're doing super!"` is preserved but labeled legacy. Current direction is the jingle:

`I've come so far / Keep watching me / I love music!`

with `far → Fa`, `me → Mi`, and a resolving `Do`, plus the Shake the Sound mechanic.

## Still to review

- skill-specific tier matrices (current Difficulty Tiers are mostly node-level)
- skill-by-skill agency ranges
- prerequisite graph
- skill/tier/age-specific UI designs
- MVP subset
