# Piper and Clef — Character Voices

Recorded 2026-09-04. Voice generation settings are **provisional** — likely to change, and possibly to be replaced by a human voice actor. The character descriptions below are the durable part; the tooling is not.

---

## Piper

The fox. **Owns low.**

Warm, unhurried, pitched a little lower. Curious rather than instructive — asks more than she tells. A shade gravelly, soft edges. The sibling who's genuinely interested in what you think, not the adult checking your work. Never syrupy.

**Current generation settings (Gemini):** voice *Pulcherrima*, Newscaster style, Natural pace, British (Brixton) accent.

## Clef

**Owns high.**

Brighter, higher, quicker, bouncier. Impish. The one who gets excited first, and slightly too much. Where Piper wonders, Clef reacts.

**Current generation settings (Gemini):** voice *Despina*, Newscaster style, Natural pace, Neutral accent.

---

## Clef's voice must be audibly higher than Piper's

Not subtly. This is deliberate design, not flavour.

The entire game is about pitch height, and the two characters own opposite poles. When a child hears Clef ask in a high voice and Piper ask in a low one, the voice itself becomes a second representation of the concept being taught. That's the project's existing principle — sound should cause a visually analogous event; visuals are a second representation of musical structure, not decoration — applied to speech.

It can't become a crutch. The voice tells her *which* one to go looking for, not which instrument is higher, so it cannot be used to shortcut the answer.

If the generation tooling changes, **preserve the pitch relationship first.** Everything else about these voices is negotiable; this isn't.

**Which character asks about which pole is not a rule to protect** (2026-09-27, Cooper: "I think we're placing too much importance on this. I don't think it truly matters that much"). An earlier draft of this document was about to add a designed, enforced character-to-pole binding (with Loud or Quiet's randomised-asker rule as the explicit counter-example) — that got walked back before it was written. A child hears a loud low note and a soft high note within a minute of playing; direct sensory evidence beats any association picked up from which character happens to ask, and now that the tree and its slots carry the high/low concept (see `HIGH_LOW_SCREEN_LAYOUT.md`), the characters are asking questions rather than being the answer, so there is far less to bind to in the first place. In practice Clef will keep asking about high and Piper about low, simply because that's who is naturally positioned to — Clef lives on the tree, Piper stands at its low end — not because of any enforced mapping. No randomisation machinery, no special-casing: whoever asks is whatever reads naturally.

---

## The shared floor

Both characters sit on the same tonal foundation, which comes from the project-wide rules in `LEARNING_ARCHITECTURE.md`:

- **One voice across every age band.** The tone doesn't ladder — only the vocabulary does. Word choice and sentence length vary by band; personality, warmth and silliness do not.
- **Reference is Bluey's Bandit.** He talks to a six-year-old and a four-year-old completely differently but is plainly the same person doing it, and never talks down to the younger one. Crash Bandicoot is a secondary reference for physical comedy and attitude.
- **Describe the answer, not the attempt.** When a child gets something wrong, point at the answer rather than delivering a verdict on the child. "That's not it," "that's the low one," "ooh, nearly" — never "nope," "wrong one," "that's a no."
  The same rule governs marks, not just words: a correct placement gets a persistent tick, a wrong one gets nothing (no cross, no red) — see `LEARNING_ARCHITECTURE.md`, "Mark what's right; never mark what's wrong."
- Humour doesn't arrive at 8+, it grows up — slapstick at the youngest, wordplay at the oldest.

And the negative constraints, which matter as much:

- No sing-song children's-presenter voice.
- No baby talk at any age band.
- No over-praising. What reads as babyish to a child isn't the characters, it's being over-explained to and over-congratulated.
- Real conversational rhythm. Comfortable leaving a gap.
- Warm without performing warmth.

The test: **if it sounds like someone talking *to* a child rather than *with* one, it's wrong.**

---

## Note on on-screen text

The caption is a **separate string** from the voice line, with a different audience. At 2-3 the caption is for the adult sitting alongside, since the child can't read. At 4-5 it should use the simplest available word, because some children are starting to read. The two converge around 6-7.

So don't assume a voice line's wording transfers to the caption, or the reverse.
