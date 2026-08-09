# Architecture

The application follows a small functional-core, imperative-shell structure.
The pure domain model should remain easy to test without HTTP, files, databases,
or browser code.

## Core Model

```text
State -> Change -> Meaning
```

The conceptual transformation model is categorical. Leela states form a
consciousness category, I Ching hexagrams form a change category, Taoist
cosmology informs symbolic categories, and player journeys carry context through
reflection. See `docs/category-theory.md` for the full ontology.

The long-term internal key for I Ching data is the six-bit binary hexagram
value from `0` to `63`:

```text
bit 5 = top line
bit 0 = bottom line
```

Broken Yin lines are encoded as `0`, solid Yang lines as `1`. This makes
changing-line transformations efficient because each moving line maps directly
to one bit.

## Functional Core

- `Domain.Types` defines immutable records for Leela states, hexagrams, moving
  lines, readings, and interpretations.
- `Domain.HexagramIndex` provides O(1) lookup tables keyed by binary hexagram
  value, beginning with binary value to King Wen number.
- `Engine.Reading` turns a `ReadingRequest` and loaded `DomainData` into a
  `Reading` without IO.
- `Interpretation.Engine` composes meaning from state, change pattern, and
  active lines without knowing about HTTP, files, or databases.

Future engine modules should model transitions as explicit composable values
before introducing stronger categorical abstractions. The architecture should
earn abstractions from repeated transition logic, not from terminology alone.

## Imperative Shell

- `Domain.Loading` reads JSON seed data at startup.
- `API.Server` exposes the pure engine through Servant endpoints.
- `app/Main.hs` resolves the port, loads data, and starts Warp.
- `app/public/index.html` provides the minimal browser UI.

## Dependency Direction

Domain logic should not import API, persistence, or deployment modules. New
features should keep dependencies pointed inward:

```text
Main/API/Storage -> Engine/Interpretation -> Domain
```

## Data Direction

The current seed data is intentionally representative rather than complete.
The architecture should grow toward binary-keyed domain tables:

- binary value to King Wen number
- King Wen number to binary value
- binary value to upper and lower trigrams
- binary value to changing hexagrams
- binary value to Tao of Lila transitions
- binary value to commentary from multiple translations

The binary value should remain the primary internal identifier even when public
APIs continue to accept or return King Wen numbers for familiarity.
