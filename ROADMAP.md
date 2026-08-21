# Roadmap

This roadmap keeps the project moving from a small deterministic prototype
toward a richer Tao of Lila and I Ching engine.

## Milestones

### Milestone 1: Master SVG

- [x] Spiral board
- [x] Bagua
- [x] Taijitu

### Milestone 2: State And Rules Engine

- [x] Implement deterministic yarrow-stalk casting as a self-contained subsystem.
- Define stable identities for Lila states, hexagrams, and transitions.
- Wrap the existing casting engine behind a stable result contract; do not make
  it aware of participants, sessions, persistence, or rendering.
- Model Lila movement and I Ching change as small pure transformations.
- Use the category theory model in `docs/category-theory.md` as the conceptual
  guide without over-abstracting early code.

### Milestone 3: Hexagram Casting

- Retain every yarrow round and line result, not only the resulting hexagram.
- Complete the binary-keyed hexagram and moving-line data.
- Expose primary, transformed, upper, lower, and nuclear trigram results through
  the casting contract.

### Milestone 4: Persistent Journey Engine

- [x] Define a prototype user, game session, current state, and `GameEvent`
  as explicit domain concepts with stable identities.
- [x] Record questions on encounters and events, never on shared Lila state definitions.
- [x] Preserve append-only event history so a session can be reconstructed instead
  of retaining only its latest position.
- [x] Store the complete current casting and completed casting result.
- [x] Implement the prototype turn pipeline: question, casting result, movement,
  accessible states, new state, and reflection context.
- [x] Place PostgreSQL persistence behind a boundary outside the pure game engine.

### Milestone 5: Dynamic Renderer Contract

- Define a renderer input model containing the current and previous positions,
  accessible states, special transitions, casting result, trigrams, changing
  lines, and movement.
- Keep rendering read-only: it receives resolved state and never calculates
  game movement or changes session history.
- Render the relevant local neighbourhood rather than requiring the complete
  72-state board on every screen.
- Treat the Lila field and I Ching symbolism as equal visual systems describing
  the same moment.

### Milestone 6: Mobile Rendering And Animation

- Make the local Lila topology legible on small screens.
- Visualize current, previous, and accessible states plus ladders, snakes, and
  special transitions.
- Visualize six lines, changing lines, primary and nuclear trigrams, and their
  symbolic attributes.
- Animate resolved transitions without placing rule logic in the animation
  layer.

### Milestone 7: Advice And Commentary

- Compose advice from the participant's question, Lila state, casting result,
  trigram and line symbolism, and optionally prior journey context.
- Keep generated advice separate from canonical source material and persistent
  game-state transitions.
- Make every synthesis traceable to the inputs and sources that produced it.

### Milestone 8: Publication

## Near Term

- Keep the Cabal project building cleanly with `cabal test`.
- Establish and test the game-engine contract that consumes the existing
  `CastingResult` without refactoring the casting state machine.
- Define append-only journey events and a pure transition from one `GameState`
  to the next.
- Define the renderer snapshot produced by a resolved game state.
- Expand tests around domain lookup tables and reading generation.
- Add focused tests for transition composition as the engine grows.
- Add complete I Ching seed data for all 64 hexagrams.
- Add complete moving-line text for all six lines per hexagram.
- Keep root documentation aligned with the current module boundaries.

## Hexagram Model

- Treat binary value `0..63` as the canonical internal hexagram identifier.
- Add a King Wen to binary lookup table.
- Add upper and lower trigram lookup tables keyed by binary value.
- Add changing-line transformations by flipping the corresponding line bits.
- Represent resulting hexagrams explicitly in reading output.

## Leela Model

- Expand the Leela state corpus toward the intended 72 states.
- Model Tao of Lila transitions as data rather than hard-coded behavior.
- Connect Leela state movement with I Ching change patterns.
- Add game metadata needed by the board visualization.

## Journey Ownership

- A Lila state owns only shared meaning and topology.
- A game session owns the participant's current state and event history.
- A journey event owns its question, raw casting, resolved movement, and any
  journal entry or generated advice.
- Persist facts needed to replay a journey; derive renderer snapshots and other
  presentation models from those facts.

## Interpretation

- Separate source text from interpretation composition.
- Support multiple I Ching translations or commentary layers.
- Treat different commentary systems as interpretation mappings over the same
  domain transitions.
- Make generated interpretations traceable to the state, hexagram, and active
  line data that produced them.

## API And UI

- Keep the HTTP API thin over the pure engine.
- Add endpoints only when they expose stable domain concepts.
- Grow the browser UI from the current minimal board into an exploratory
  reading interface.
- Preserve deterministic behavior for omitted inputs unless randomness is added
  as an explicit feature.

## Deployment

- Keep Heroku and Docker deployment paths working.
- Document required local tool versions once the build environment settles.
- Avoid introducing runtime services until persistence or collaboration needs
  justify them.
