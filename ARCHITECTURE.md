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
I Ching/Leela facts   Persona history     Visual projection
```

The state and rules layer determines casting, hexagram change, movement, and
Lila topology. The journey engine records a Persona's journey as events.
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
Player (authenticated User)
  Persona (many per Player; constructed identity)
    Avatar (visual representation)
    Journey (existing GameSession; one resumable journey initially)
      GameState / workflow
      GameEvent / Question / casting / journal / advice
```

`GameState` is the current projection of a session. `GameEvent` is the durable
record of how it changed. Events are append-only so the journey can be replayed
instead of merely overwriting a current position.

A question belongs to a Persona's encounter recorded by a game event. It
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

The Lila field answers where the Persona is and can move. The I Ching view
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

## Responsive journey workflow

`app/public/journey/` is a separate responsive presentation layer with hash routing,
shared components and an isolated authentication/JSON adapter. `/` opens this
interface; the legacy diagnostic client remains at `/?prototype`. Login and
registration open Persona selection. Creating a Persona selects it before loading
its journey; no game load is attempted without selection. `/journey-session`
provides its durable projection and revision-checked commands. `Domain.Journey`
defines workflow stages; `Persistence.Journey` coordinates the existing casting,
movement and interpretation services under a session row lock.

The responsive workflow records a completed casting event before interpretation,
then applies the engine-resolved movement only after reflection and acknowledgment.
Questions cannot be edited during or after casting. The existing prototype retains
its original orchestration, with conflicting mutations blocked while a responsive
encounter is active. No casting or movement rule is implemented in JavaScript.

The integrated ceremony imports the existing renderer/choreography through
`web/yarrow-casting/src/journey.ts`. Engine snapshots and visual phases are saved
separately; visual metadata is validated against the server-owned engine snapshot.
Both casting clients use `web/yarrow-casting/src/line.ts` to request intermediate
engine transitions automatically until one complete line is ready. Each click
reveals one line; six generation clicks complete a fresh hexagram. Accepted
intermediate snapshots support retry and reload without recalculating results
in the browser.
See [responsive journey](docs/responsive-journey.md) for recovery semantics,
contract changes, domain gaps and validation status.

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

## Persona foundation and impact assessment

Before this evolution, `Domain.Game.User` and PostgreSQL `users` represented the
account, while `game_sessions.user_id UNIQUE` and `journey_workflows.user_id`
implied one account = one game piece. `JourneyState` represented position;
`questions`, `game_events`, and `contemplations` already held session/event-owned
questions, castings, journals and interpretations. `Domain.Journey` and
`Persistence.Journey` own responsive orchestration; `API.Server` is the API
specification. There was no Avatar entity, external schema directory, or ADR
system. README, this document, docs/architecture.md, docs/category-theory.md,
docs/responsive-journey.md, ROADMAP and the Category of Tao book are the relevant
manifests/design material; historical book notes remain historical.

Development state is disposable. The obsolete account-owned workflow schema is
reset transactionally at startup, including persona/game data and auth sessions;
account credentials remain. No synthetic Legacy personas or legacy-data migration
are created. The current schema directly declares per-persona sessions and
workflows, with ownership enforced by foreign keys. Current-schema restarts are
idempotent. Production migration/versioning is deferred until the model stabilizes.

Auth sessions select a Persona. A sole active Persona is selected on login;
multiple Personas require a choice. No active Personas opens creation. Existing
Personas open cards with Continue Journey and explicit Create New Persona.
Requests capture selection during authentication, and journey commands reject a
mismatched Persona ID. The `/game` and `/journey-session` APIs use that selection.

`Domain.Persona` owns constructed identity, initial and evolving attributes,
evidence-weighted themes, avatar, and a dormant relationship boundary. Persistence
records revision snapshots and gameplay changes in an audit table. Initial context
is immutable; later Player edits and AI evidence remain distinguishable. Theme
confidence is an evidence ratio, not a calibrated probability or diagnosis.
AI suggestions are inspectable data; they never silently replace Player context.

API: authenticated GET/POST `/personas`, GET/PUT `/personas/:id`, POST
`/personas/:id/select`, POST `/personas/:id/journey`, and DELETE `/personas/:id`
(archive only). Updating uses the returned revision; archive preserves all history.
GET `/personas/:id/question-context` supplies constructed Persona context, current
state, history, recent casting history, themes and unresolved questions for a
future question generator. Question proposals and edits retain separate records.

The Leela Field is shared symbolic material inhabited by independent Personas.
Current awareness is Level 0 (Independent). Future levels are Resonance, Encounter,
Influence and Relationship. A future relationship can carry two Persona IDs,
open-ended type, timestamps, evidence/confidence, awareness and interaction
history. Board, thematic, I Ching, trigram, temporal, historical and question
proximity remain separate ideas, with no compatibility score. Relationships,
awareness, influence and cross-player interaction have no gameplay implementation.

Avatar is deliberately separate from Persona. Future visual changes may accumulate
trigram, element, colour, clothing, object, posture and environment motifs from a
journey; no simplistic emotion-to-appearance mapping is implemented. Initial
attributes accept open-ended structured values (for example life_stage,
material_circumstances, health_or_vitality, social_context, responsibilities,
aspirations, tensions and worldview) alongside natural language, never diagnoses. Explicit narrative fields include sex/gender,
age/life stage, cultural background, time period, place and defining characteristic.
`Runtime.Avatar` is an optional image-provider adapter in the imperative shell.
Authenticated `POST /personas/avatar` creates a preview from the draft context;
only an accepted preview is included in the later Persona create/update request.
It cannot change authentication, casting or journey state.

## Read-only state catalogue

`Domain.StateView` models and validates visual identity, typed snake/ladder
reference relationships, and trigram/hexagram information. `GET /state-views`
serves this catalogue independently of game mutation routes. The journey client
uses one native dialog to explore it without advancing or recomputing engine
state. Traditional reference identities remain separate from the existing game
edition; see [State Viewer](docs/state-viewer.md) for content provenance, PNG
assets, catalogue packaging and future contextual-interpretation boundaries.

Fresh casting entropy is supplied by `Runtime.Casting` in the IO shell using
`Crypto.Random`. Every live casting start passes that seed to the pure
`Engine.Casting.initialCastingStateWithSeed` constructor. Saved castings resume
without reseeding; the browser only animates their engine state.

The `LeelaBalanced` sampler version chooses four equally likely line values in
the pure Haskell engine, then realizes them through valid stalk arithmetic.
Changing-line positions remain the sole input to movement. `samplingRule` and
`samplingSeed` are durable casting metadata; missing rule fields select legacy
sampling for backward-compatible replay. No browser component samples lines or
adjusts movement probabilities.
