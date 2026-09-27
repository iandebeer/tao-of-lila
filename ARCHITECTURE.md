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

The application separates three explicit concerns:

```text
State and rules -> Persistent journey engine -> Rendering
       |                    |                       |
I Ching/Leela facts   Participant history     Visual projection
```

The state and rules layer determines casting, hexagram change, movement, and
Lila topology. The journey engine records a participant's session as events.
The renderer receives a resolved snapshot and must not calculate movement or
mutate the journey. Advice is a separate interpretation over recorded facts,
not part of state transition logic.

`Domain.Contemplation` builds a compact, immutable context from a completed
game event and canonical textual material. `Interpretation.ContemplationModel`
is the provider-neutral effect boundary; `Interpretation.OpenAI` is its first
imperative adapter. Neither module can feed values back into casting or
movement.

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

The working `Engine.Casting` state machine remains a self-contained subsystem.
The game engine consumes its result through a stable contract rather than
embedding participant, persistence, or rendering concerns in casting.

## Journey Model

The persistent model grows around this ownership hierarchy:

```text
Participant
  Profile
    GameSession
      GameState
      GameEvent
        Question
        IChingCasting (including raw yarrow rounds)
        Movement
        JournalEntry
        Advice
```

`GameState` is the current projection of a session. `GameEvent` is the durable
record of how it changed. Events are append-only so the journey can be replayed
instead of merely overwriting a current position.

A question belongs to a participant's encounter recorded by a game event. It
does not belong to the shared Lila state definition. Journal entries and advice
have the same event context, while canonical Lila and I Ching source material
remain shared domain data.

The pure turn contract is conceptually:

```text
GameState + Question + CastingResult
  -> movement
  -> accessible states
  -> special transitions
  -> GameEvent + new GameState
```

Persistence stores sessions, states, events, and complete raw castings behind a
repository boundary. It does not enter the rule functions.

## Rendering Boundary

The renderer consumes a projection containing the current and previous Lila
positions, accessible positions, special transitions, hexagram and trigram
results, changing lines, and resolved movement. It renders the relevant local
neighbourhood rather than requiring the full 72-state topology.

The Lila field answers where the participant is and can move. The I Ching view
describes the pattern of change through lines, trigrams, and symbols. These are
two visual coordinate systems for one event; neither owns or computes the other.

The yarrow ceremony is a separate visual projection of `Engine.Casting`. Haskell
remains the source of truth for every numerical transition. TypeScript in
`web/yarrow-casting/` interpolates stalk positions, ceremonial pacing, and SVG
appearance. It must not divide heaps, count remainders, or decide line values.
The isolated page is served at `/yarrow/` and talks to the pure
`/casting/initial` and `/casting/next` endpoints, not to the journey board.

The contemplation flow belongs to completed journey events. Reading canonical
text (`GET /game/contemplation-context/:eventId`) is independent of requesting
AI assistance (`POST /game/contemplation/:eventId`). The latter is always an
explicit participant action. Provider storage is disabled, and request logs
retain operational metadata rather than duplicated prompts.

Future engine modules should model transitions as explicit composable values
before introducing stronger categorical abstractions. The architecture should
earn abstractions from repeated transition logic, not from terminology alone.

## Imperative Shell

- `Domain.Loading` reads JSON seed data at startup.
- `API.Server` exposes the pure engine through Servant endpoints.
- `app/Main.hs` resolves the port, loads data, and starts Warp.
- `app/public/index.html` provides the minimal browser UI.
- `web/yarrow-casting/` is the TypeScript ceremony layer for yarrow casting.
- `app/public/yarrow/` is the isolated SVG ceremony page served by the API.

## Dependency Direction

Domain logic should not import API, persistence, or deployment modules. New
features should keep dependencies pointed inward:

```text
Main/API/Storage/Browser
          |
          v
Journey Engine -> Rules/Casting/Interpretation -> Domain
          |
          v
Renderer Snapshot
```

Imports continue to point inward: domain and rule modules never import journey
persistence, HTTP, or browser rendering. Renderer snapshots are derived at a
boundary and contain no behavior that can change game state.

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

## Standalone interpretation test

`tao-of-lila-interpretation-test` is an imperative command-line shell over
`Domain.Contemplation.buildPairContemplationContext` and the existing
`Interpretation.OpenAI` adapter. It accepts a primary/resulting King Wen pair,
a question, and an optional Leela state. King Wen inputs are resolved by
inverting the explicit binary-keyed lookup table. Binary differences determine
the changing lines without inventing casting history or journey movement.
The pure context builder requires the existing canonical corpus; unsupported
hexagrams fail before contacting the provider. Dry-run mode only prints the
context. This executable has no runtime dependency on a database or API server.

The same executable's `--web` mode serves the local interface from
`app/public/interpretation-test/` on loopback port 8081. Its separate Servant
shell (`app/interpretation-test/Web.hs`) exposes `GET /api/states`,
`POST /api/preview`, and `POST /api/interpret`. Both POST endpoints accept
`primary`, `resulting`, `question`, and `leelaState`; context construction and
changing-line derivation stay in Haskell. The API key stays in the server
process. These test endpoints are not added to the public journey API.

## Movement projection

`Engine.Movement.movementFromChangingLines` derives board movement from the
bottom-to-top changing-line positions using their sum modulo seven. The casting
result assembler records this projection in `lilaMoveSquares` while retaining
`changingLines` and `numberChanging` for interpretation. Sampling, heap operations,
line values, binary hexagrams and transformations are unchanged.

`movementRule` versions the recorded projection. Legacy JSON without this field
keeps its saved movement and is labeled `changing-line-count-v1`; new results use
`changing-line-positions-mod7-v1`. No database rewrite or historical replay is
performed. Presentation shows the formula and recorded movement; it does not
calculate an alternative result.
