# Roadmap

This roadmap keeps the project moving from a small deterministic prototype
toward a richer Tao of Lila and I Ching engine.

## Milestones

### Milestone 1: Master SVG

- [x] Spiral board
- [x] Bagua
- [x] Taijitu

### Milestone 2: Haskell Engine

### Milestone 3: Hexagram Casting

### Milestone 4: Gameplay

### Milestone 5: Animation

### Milestone 6: Commentary

### Milestone 7: Publication

## Near Term

- Keep the Cabal project building cleanly with `cabal test`.
- Expand tests around domain lookup tables and reading generation.
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

## Interpretation

- Separate source text from interpretation composition.
- Support multiple I Ching translations or commentary layers.
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
