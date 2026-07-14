# The Tao of Lila

The Tao of Lila is an interactive contemplative system combining the traditional
Leela game with the cosmology and divination framework of the I Ching. The
project aims to produce a historically respectful yet original digital
instrument rather than simply a board game.

The core model is:

```text
State -> Change -> Meaning
```

Domain logic is kept independent of UI, persistence, and deployment concerns.

## Stack

- Haskell
- Cabal
- Servant
- Aeson
- Warp

## Project Layout

```text
app/
  Main.hs              # HTTP executable entry point
  public/index.html    # Minimal browser UI and board layout
src/
  API/                 # Servant API
  Domain/              # Domain types, loading, and lookup tables
  Engine/              # Pure reading generation
  Interpretation/      # Interpretation composition
data/
  leela.json           # Seed Leela state data
  hexagrams.json       # Seed I Ching hexagram data
  lines.json           # Moving-line lesson data
docs/
  board-layout.md      # Leela ring, I Ching grid, and moving-line layout
test/
```

## Run Locally

```bash
cabal update
cabal run tao-of-lila-api
```

The service listens on `PORT` when set, otherwise `8080`.

Open `http://localhost:8080/` for the minimal UI.

## Test

```bash
cabal test
```

## API

- `GET /health` returns service health.
- `GET /states` returns loaded Leela states.
- `GET /hexagrams` returns loaded hexagrams.
- `POST /reading` generates a full reading.
- `POST /interpret` returns only the interpretation for a reading request.

Example reading request:

```json
{
  "question": "What state is asking to be seen?",
  "leelaStateId": 2,
  "hexagramNumber": 24,
  "movingLines": [1, 5]
}
```

Only `question` is required. When state, hexagram, or moving lines are omitted,
the pure engine derives them deterministically from the inquiry.

## Hexagram Indexing

The internal hexagram identifier is the six-bit binary value from `0` to `63`.
Broken Yin lines are `0`, solid Yang lines are `1`, and the bottom line is bit
`0`. `Domain.HexagramIndex` maps this binary value to the King Wen number with
an O(1) lookup table.

## More Docs

- `ARCHITECTURE.md` describes the functional-core architecture and boundaries.
- `ROADMAP.md` tracks planned product and domain-model work.
- `AGENTS.md` gives guidance for AI agents working in this repository.
- `docs/board-layout.md` documents the initial board visualization contract.
