# CLAUDE.md — Ear Training App for Kids

## Product & Curriculum Handoff

A separate design/curriculum handoff packet lives under `docs/`. It describes a broader long-term learning architecture (`Skill + Concept Tier + Agency + Age Presentation`), the full node/skill curriculum taxonomy, and a library of interaction ideas — a larger future scope than the MVP described below.

- Start with `docs/product/LEARNING_ARCHITECTURE.md` for the compact guardrails, then `docs/product/EAR_TRAINING_APP_PRODUCT_SPEC.md` for full rationale.
- Read `docs/product/IMPLEMENTATION_NOTES.md` before treating any of it as a rewrite mandate — it explicitly says to reconcile with, not replace, the app that already exists.
- Curriculum data (nodes, skills, tiers, agency, age bands) lives as CSVs in `docs/curriculum/`. The Google Sheet named in `docs/product/HANDOFF_README.md` remains the live source of truth for curriculum data; the CSVs are a cleaned snapshot.

This section and the MVP-focused guidance below it are both authoritative — the handoff packet is aspirational/architectural context, this file (and the rest of this document) is the current build's operating guardrails.

## WHAT (Project Goal)

Build a playful, “squishy” 2D ear-training mobile app for kids using Flutter.

The v1 product is an offline-first app that:

- teaches foundational listening skills through mini-games (not “lessons”)
- delivers fast, delightful feedback (animations, sounds, rewards)
- supports short sessions (2–5 minutes)
- works great on iOS first, with minimal friction to ship Android later

### MVP Feature Set (v1)

- Core loop:

  1. Home → choose game (or “Play”)
  2. 8–12 quick prompts
  3. Reward screen (sticker/confetti/character reaction)
  4. “Play again” / “Next”

- Mini-games (start with 1–2, expand later):

  - High vs Low (pitch direction)
  - Same vs Different (pitch or timbre)
  - (Optional later) Match the sound (one-of-3), Rhythm copy (tap back)

- Local-only progress:
  - simple streaks / session counts
  - lightweight “unlocks” can be in-memory or local storage later
  - no accounts, no cloud sync, no backend in v1

### Non-Goals (for now)

- No backend API
- No database
- No user accounts
- No microphone/pitch detection
- No MIDI/synthesis requirements
- No monetization SDKs (ads/IAP) in v1

## WHY (Design Principles)

- Kids learn by repeating fun, high-feedback interactions. The app must feel like a toy.
- Scope control: the most important thing is a delightful, repeatable core loop.
- “Offline-first” reduces complexity and makes iOS→Android easier.
- Audio UX matters: avoid latency, inconsistent volumes, and complicated audio pipelines.

Guiding principles:

- Fast prompts, big tappable UI, minimal reading
- Positive reinforcement; misses are gentle, quick to recover
- Simple difficulty ramp; avoid overwhelming choices
- Accessibility: large tap targets, clear contrast, avoid tiny text

## HOW (Architecture & Workflow)

### Tech Stack

- Flutter (Dart) single codebase
- Audio: bundled audio assets (note samples + SFX) using a lightweight Flutter audio plugin
- State management: start simple (e.g., ChangeNotifier/Riverpod later if needed)
- No backend/persistence in v1 (keep code structured so we can add later)

### Repo Structure (proposed)

- lib/
  - app/ App bootstrap, routing, theme
  - ui/ Reusable UI components (buttons, cards, progress dots)
  - audio/ Audio engine + asset mapping
  - games/
    - high_low/ Game logic + screens
    - same_different/ Game logic + screens
  - rewards/ Reward screens, stickers, unlock logic (in-memory for v1)
  - models/ Small data models (prompt, result, etc.)
- assets/
  - audio/notes/ note samples (e.g., piano C4–B5)
  - audio/sfx/ UI SFX, correct/incorrect, reward
  - images/ characters, stickers, UI icons
- tool/
  - scripts/ one-command scripts invoked by Makefile

### One-command Developer Workflow

Goal: everything important should be runnable from terminal with a single command.

#### Commands (Makefile)

- `make bootstrap` → install deps, verify toolchain
- `make test` → run tests (fast)
- `make lint` → analyze + format check
- `make format` → apply formatting
- `make run-ios` → run on iOS simulator
- `make build-ios` → build iOS (debug/release as configured)
- `make clean` → clean build artifacts

We prefer Makefile wrappers so Claude can reliably run commands without remembering flags.

### iOS Requirements (Reality Check)

- Xcode is still required for iOS simulator and App Store builds.
- We keep Xcode usage minimal by running via CLI where possible:
  - `flutter run -d <simulator>`
  - `flutter build ios`
- Any required signing steps should be documented in README, but not automated in v1.

### Android Later (Minimal Work Strategy)

- Avoid iOS-only plugins and platform-specific code unless necessary.
- Keep assets and audio logic platform-agnostic.
- Use Flutter packages known to support both platforms.
- When adding persistence later, choose a solution with a smooth mobile story:
  - local: SharedPreferences/Hive/Isar/SQLite
  - cloud: evaluate later (Firebase/Supabase/custom API)
- Backend (Node + Postgres) is explicitly deferred until we know:
  - what data must sync across devices
  - whether we need accounts
  - what the progression model becomes

## Audio Implementation Notes (v1)

- Use pre-rendered note samples for consistency (recommended for early builds).
- Keep volume normalized across notes and SFX.
- Avoid realtime pitch shifting/synthesis until needed.
- Ensure no audio clicks by using short fade-in/out or trimmed samples.

## Product “Definition of Done” (v1)

- One mini-game fully playable end-to-end with rewards
- Stable audio playback (no obvious latency issues)
- Smooth animations (“squishy” feel)
- Runs on iOS simulator from one command
- Tests + lint/format are one command each
- Clear README for setup and running

## Collaboration Expectations for Claude Code

When making changes:

- Prefer small, incremental PR-sized commits
- Keep “one command” workflows working (Makefile must not rot)
- Add/adjust tests when logic is added
- Avoid premature abstraction; optimize for clarity and iteration speed
- If adding a dependency, explain why and ensure cross-platform support

### Shell commands: keep them plain

Run bare commands — `flutter test`, `make lint`, `git commit -m "..."` — rather than
wrapping them in `export PATH=...; cd ... && ...` or chaining several commands together
with `;`/`&&`. This isn't a style preference: Claude Code's permission allowlist matches
against the *entire* command string, so a prefix like `export PATH=...` or `cd $DIR &&`
makes an otherwise-approved command (e.g. `flutter analyze`) fail to match its allowlist
entry (`Bash(flutter analyze *)`) and forces a manual approval prompt every time. PATH is
already configured project-wide (`.claude/settings.local.json` → `env.PATH`), so `flutter`,
`pod`, and homebrew-installed `ruby`/`gem` resolve without an `export` prefix. Run commands
from the repo root (Claude Code's Bash tool already starts there) instead of `cd`-ing into
it. If a task genuinely needs multiple steps, run them as separate Bash calls rather than
one chained string — each one can then match the allowlist independently.
