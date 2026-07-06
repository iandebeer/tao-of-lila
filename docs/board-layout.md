# Board layout

The first visual board layout is a browser-rendered mandala that maps the
project principle into a spatial interface:

```text
State -> Change -> Meaning
```

## Regions

### Outer Leela ring

- Target capacity: 72 positions.
- Geometry: evenly spaced points around a circular path.
- Purpose: represents the Leela states of consciousness.
- Current behavior:
  - All 72 slots are visible.
  - Seeded states from `data/leela.json` are highlighted.
  - Selecting a seeded node updates the reading form state selector.
  - Generated readings highlight the active Leela state.

### Inner I Ching grid

- Target capacity: 64 positions.
- Geometry: 8x8 square field rotated into a diamond inside the ring.
- Purpose: represents transformational hexagram patterns.
- Current behavior:
  - All 64 slots are visible.
  - Seeded hexagrams from `data/hexagrams.json` are highlighted.
  - Generated readings highlight the active hexagram.

### Moving-line pathways

- Target capacity: six active lessons.
- Geometry: six radial dashed pathways crossing the board center.
- Purpose: represents the line focus moving from foundation to transcendence.
- Current behavior:
  - All six moving-line positions are visible.
  - Generated readings highlight the active moving lines.

### Center

- Purpose: displays the active transformation summary.
- Current behavior:
  - Default message: `State -> Change -> Meaning`.
  - Generated readings show active state and hexagram.

## Expansion notes

- The board should remain data-driven. Completing the 72 Leela states or 64
  hexagrams should not require layout code changes.
- Future graphical work can replace the CSS/DOM implementation with SVG or
  Canvas while preserving the same regions and selection semantics.
- Board interaction should continue to call the API rather than embedding
  interpretation logic in the browser.
