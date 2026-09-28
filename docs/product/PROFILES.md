# Local Profiles

Decided 2026-09-27/28 (Trello card 170, "Local profiles: one per child, plus
an adult profile that sees the dev screens"). Deliberately tiny — resist
growing this into the stepping-stones journey, parent dashboards, or sync;
none of that is here yet on purpose.

## What this solves

1. **Adult testing stops polluting a child's data.** Everything collected
   before this card was Cooper testing the app himself, not real play.
2. **The dev tier/agency picker is gated to the adult profile**, not just an
   internal build — an internal (TestFlight) build a child is using must not
   show dev tools either.
3. **Two children are tracked separately** rather than mixed into one record.
4. **The foundation the stepping-stones journey needs later** — not throwaway
   work, even though the scope here is minimal.

## Shape

- `Profile` (`lib/models/profile.dart`): id, name, `isAdult`, and an optional
  `agencyOverride` a parent can set directly (they already know whether their
  child can drag — no need to make the child prove it across several rounds).
  No avatar, no account, no network identity.
- `ProfileState` (`lib/app/state/profile_state.dart`): the list of profiles,
  the active one for this session, and `canUseDevTools` (`devToolsEnabled &&`
  the active profile is the adult's — both conditions, not either alone).
- **At most one adult profile can exist.** A second `addProfile(isAdult:
  true)` call returns the existing one rather than creating another.
- **The active profile is never persisted across launches.** "Pick a profile
  at launch" (the card's own words) is a deliberate step every time on a
  shared device — not a remembered default that could silently apply the
  wrong child's session. The profile *list* does persist; only "who's
  currently playing" doesn't.
- `ProfilePickerScreen` (`lib/ui/screens/profile_picker_screen.dart`) is the
  app's real first screen (`AppRoutes.profilePicker`, ahead of the branded
  landing screen) — deliberately plain, no illustrated character art, since
  it's functional plumbing rather than a play moment.

## The one real data migration in this whole architecture rework

Card 168 ("agency is capability, not difficulty") needed none — nothing had
ever persisted agency. **This card is different**: introducing profile-scoped
keys obsoletes the flat, unscoped keys `ProgressState`/`SkillState` used
before profiles existed (`total_sessions`, `skill_xp_*`, etc.). That old data
is entirely Cooper testing the app, not real play, so `ProfileState.load()`
**purges it outright, once** (behind its own `profiles_v1_purged_pre_profile_data`
flag), rather than trying to migrate it into whichever profile gets created
first.

`ProgressState`/`SkillState` each gained a `loadForProfile(profileId)` method
that prefixes every key with `profile_<id>_`. The old parameterless `load()`
still works, unscoped, as a legacy fallback for any caller with no profile
context — kept mainly so the bulk of the existing test suite (which
constructs these screens directly, without the app's full provider stack)
didn't need to be rewritten to care about profiles it isn't testing.

## Gating dev tools: a fallback for tests, not a loophole

`HighLowScreen`/`SkillProfileScreen` read `ProfileState.canUseDevTools`
instead of the bare `devToolsEnabled` global. `HighLowScreen` specifically
falls back to `devToolsEnabled` alone if no `ProfileState` is found in the
widget tree (`ProviderNotFoundException`) — most of its existing widget tests
construct the screen directly, without the app's full provider stack, and
don't care about profile gating at all. The real app (`EarTrainerApp`) always
provides a `ProfileState` at its root, so production gating is never affected
by this fallback; tests that specifically prove the gating provide one
explicitly and get the real value (see
`test/games/high_low/high_low_screen_test.dart`'s "the dev gate is scoped to
the adult profile" group).

## Not built here (resisting scope creep, per the card's own warning)

- No avatar picker (the card said "optionally" — skipped; an easy add later).
- No "switch profile" control once one is picked — the picker only appears
  at launch; switching mid-session means restarting the app. Deliberate for
  this minimal pass, not an oversight.
- Agency's `agencyOverride` field exists on `Profile` and can be set
  (`ProfileState.setAgencyOverride`), but nothing in the app *reads* it into
  an actual game session yet — that's the advancement/demotion card's job.
- No UI for a parent to actually set the agency override — the model and
  state support it; the picker screen doesn't expose it yet.
