# Ear Training App — Claude/Cowork Handoff Packet

This is a working product + curriculum handoff for implementation, filed into the repo under `docs/`.

## Start here

1. `LEARNING_ARCHITECTURE.md` (originally this packet's own `CLAUDE.md`) — compact implementation guardrails and architectural rules. See also the repo root `CLAUDE.md`, which points here.
2. `EAR_TRAINING_APP_PRODUCT_SPEC.md` — full product vision, learning architecture, interaction ideas, and open questions.
3. `IMPLEMENTATION_NOTES.md` — advisory guide for reconciling these ideas with the app that is already built; not a replacement architecture.
4. `../curriculum/` — cleaned implementation-facing snapshot of the current curriculum spreadsheet, as CSVs.

The original packet also included `source/Ear_Training_Music_App_Skill_Tree.xlsx`, an untouched workbook snapshot. It was **not** committed here: it's a binary snapshot of a live Google Sheet, and checking it in risks someone treating a stale copy as authoritative. The Google Sheet remains the source of truth:

https://docs.google.com/spreadsheets/d/1vxXz3n31fSAlQ3BuixzlEY9ko_aaaJvohofMru8Pfyg

## Curriculum files

- `nodes.csv` — node identities and learning goals.
- `skills.csv` — current skill inventory.
- `skill_progression_working.csv` — four-tier progression plus current working agency/prerequisite mappings.
- `difficulty_tiers.csv` — human-readable node-level musical parameter matrices.
- `agency.csv` — canonical A0 Observe through A4 Precision model.
- `age_band_defaults.csv` — high-level age presentation philosophy.
- `ui_presentation_scaffold.csv` — generic age/tier prompt + visual scaffold; not final game-specific UI.
- `visuals_notes.csv` — working visual/journey notes.

## Important cleanup applied to this packet

The packet intentionally cleans a few spreadsheet artifacts so Claude does not mistake them for architectural decisions:

1. **Replay removed from Difficulty Tiers.**
   Replay is now treated as Agency/UI scaffolding, not musical concept difficulty.

2. **Age-band Excel date conversion corrected.**
   The UI sheet had `2-3`, `4-5`, and `6-7` converted to Excel date serial values. The CSV uses the intended age labels.

3. **Agency bleed removed from UI scaffold.**
   The spreadsheet's generic `InteractionStyle` text tied timing/agency demands to age. That conflicts with the core architecture, so the clean UI CSV includes prompt/visual presentation only. Agency requirements should come from the Agency model.

4. **Working progression assumptions are labeled.**
   Current min/max agency and prerequisite mappings are useful scaffolds but have not all been individually curriculum-reviewed.

5. **Legacy reward note labeled.**
   The Visuals sheet's older `"you're doing super!"` completion idea is retained as history but marked superseded by the current milestone jingle in the product spec.

## Source-of-truth hierarchy

- **Google Sheet:** current curriculum working data.
- **Product Spec:** product intent and reasoning.
- **LEARNING_ARCHITECTURE.md:** implementation guardrails (packet-specific; see also the repo root `CLAUDE.md`).
- **Clean CSVs:** implementation-facing snapshot derived from the sheet, with known inconsistencies normalized.

When something conflicts, do not silently guess. Surface the discrepancy for product review.
