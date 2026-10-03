# The Tao of Leela - Developer Manual

## From symbolic model to running code

*Prototype edition | Source reviewed on 23 September 2026.*

This manual is a guide to the implementation, not a replacement for the canonical
[Architecture](../ARCHITECTURE.md). It follows a Persona from creation through
casting, reflection and persistence, and identifies places where the conceptual
model is richer than the code currently supports.

## Contents

1. [Read the model](#1-read-the-model)
2. [Map concepts to implementation](#2-map-concepts-to-implementation)
3. [Run the project](#3-run-the-project)
4. [Construct and evolve a Persona](#4-construct-and-evolve-a-persona)
5. [Trace an encounter](#5-trace-an-encounter)
6. [Understand casting and movement](#6-understand-casting-and-movement)
7. [Persist identity and history](#7-persist-identity-and-history)
8. [Use the API](#8-use-the-api)
9. [Build interpretation context](#9-build-interpretation-context)
10. [Understand browser responsibilities](#10-understand-browser-responsibilities)
11. [Validate changes](#11-validate-changes)
12. [Extend the model deliberately](#12-extend-the-model-deliberately)

## 1. Read the model

The Player is the real person using an account. The Persona is a constructed
identity owned by that Player. A Journey is the Persona's recorded passage
through the Leela Field. Avatar is a representation, not a substitute for Persona.

```mermaid
flowchart LR
    Player -->|owns many| Persona
    Persona -->|has an optional| Avatar
    Persona -->|currently has one| Journey
    Journey --> Position
    Journey --> Questions
    Journey --> Castings
    Journey --> Reflections
    Persona -->|retains provenance for| Context[Initial and evolving context]
```

The board, hexagram tables and source texts are shared domain material. A
Persona's state and interpretation history are not shared with other Personas.
Current interaction awareness is **Independent**, or Level 0.

The conceptual transformation is `State -> Change -> Meaning -> Reflection`.
The implementation keeps numerical transitions separate from interpretation:

```mermaid
flowchart TD
    Browser[Browser: present and request] --> API[Servant API]
    API --> Repository[Persistence and journey orchestration]
    Repository --> Rules[Pure casting and movement]
    Repository --> Context[Pure contemplation context]
    Repository --> DB[(PostgreSQL)]
    Repository --> Model[Effectful interpretation adapter]
    Rules --> Domain[Immutable domain values]
    Context --> Domain
```

Category theory provides a way to think about relationships, composition and
transformation. It does not require a `Category`, `Functor` or `Monad` wrapper
around every entity. Use the existing small functions until a stronger abstraction
simplifies actual composition. See [category-theory.md](category-theory.md).

## 2. Map concepts to implementation

| Concept | Haskell representation / entry point | Persistence or presentation |
| --- | --- | --- |
| Player / account | `Player` in [Domain.Persona](../src/Domain/Persona.hs); authenticated `User` in [Domain.Game](../src/Domain/Game.hs) | `users`; bcrypt password hashes |
| Selected Persona | `User.userPersonaId :: Maybe Int` | `auth_sessions.persona_id`, captured during authentication |
| Persona | `Persona`, `PersonaDraft`, `newPersona`, `revisePersona` | `personas.document` JSONB with relational owner and archive columns |
| Initial and emergent attributes | `PersonaAttribute`, `Origin`, initial/evolving fields | Persona document and before/after audit snapshots |
| Recurring themes | `PersonaTheme`, `Evidence`, `observeTheme` | Persona document; trusted `recordEvidence` repository operation |
| Avatar | `Avatar` with description and optional asset reference | Embedded in Persona JSON; UI currently edits a description |
| Journey / position | `JourneyState` in `Domain.Game` | `game_sessions`, one per Persona today |
| Active encounter | `Workflow`, `JourneyCommand`, `allowedStage` in [Domain.Journey](../src/Domain/Journey.hs) | `journey_workflows.document`, keyed by Persona |
| Legacy question | `Domain.Game.Question` | `questions`, unique per session/state |
| Responsive question provenance | Workflow text and repository SQL | `persona_questions`: proposal, final text, basis, timestamps, event reference |
| Casting | `CastingState`, `CastingResult` in [Engine.Casting](../src/Engine/Casting.hs) | Workflow snapshot, session casting, event raw/result JSON |
| Movement | `movementFromChangingLines`; `applyCastingMovement` | Resolved event destination; session position after acknowledgment |
| Encounter history | `GameEvent` and JSON projection | `game_events`; journal is a field on the event |
| Interpretation | `ContemplationContext`, `ContemplationResponse` | `contemplations`, one stored response per event |
| Audit history | Repository SQL trigger | `persona_audit`, before and after documents |
| Future relationships | `PersonaRelationship` | Dormant type only; no relationship table or gameplay |

**Naming matters:** the ontology calls this a Journey, but the code has no single
aggregate named `Journey` holding all history. `JourneyState`, `Workflow`, events
and repository projections collectively implement it. Likewise `Player` is a
minimal ownership value, while `User` remains the authentication DTO. Avoid
claiming that the future conceptual schema already exists as literal classes.

## 3. Run the project

### Prerequisites

Use GHC and Cabal compatible with [tao-of-lila.cabal](../tao-of-lila.cabal),
PostgreSQL, and `libpq` development tools. The package requires `base >= 4.17`.
Node/npm are needed to rebuild the TypeScript animation bundles, not to run the
Haskell rules. No Stack configuration is required.

From the repository root, the existing convenience script is:

```sh
./scripts/start-prototype.sh
```

It expects `podman`, `docker`, `cabal`, `pg_config` and `curl`. It starts the
Podman machine if needed, starts the Compose PostgreSQL service, builds the API
and records its PID/log under `.runtime/`. It does not rebuild the browser bundles.

Alternatively, with a configured container runtime:

```sh
docker compose up -d postgres
cabal run tao-of-lila-api
```

Open `http://localhost:8080/journey/`. Stop the convenience-script installation with:

```sh
./scripts/stop-prototype.sh
```

The stop script preserves the database volume. The sample Compose credentials
are for local development. An existing database is migrated automatically at
API startup; review and back it up before upgrading a deployment with valuable data.

### Configuration

[app/Main.hs](../app/Main.hs) resolves these environment variables:

| Variable | Current behavior |
| --- | --- |
| `PORT` | Defaults to `8080`. |
| `DATABASE_URL` | Defaults to `postgresql://tao:tao@localhost:5432/tao_of_lila`. |
| `OPENAI_API_KEY` | Enables optional external contemplation; absent means a disabled model adapter. |
| `OPENAI_MODEL` | Current code default is `gpt-5-mini`; this is a source default, not a model recommendation. |
| `OPENAI_INPUT_COST_MICROS_PER_MILLION` | Configured input-cost estimate; defaults to zero. |
| `OPENAI_CACHED_INPUT_COST_MICROS_PER_MILLION` | Configured cached-input estimate; defaults to zero. |
| `OPENAI_OUTPUT_COST_MICROS_PER_MILLION` | Configured output-cost estimate; defaults to zero. |

Keep provider credentials on the server. Zero recorded cost means rates may be
unconfigured; it does not establish that requests are free. No current price
schedule is embedded in this manual.

### Browser builds

```sh
./scripts/build-yarrow.sh
```

The script installs dependencies when needed and rebuilds both
`app/public/journey/ceremony.js` and `app/public/yarrow/casting.js`. Regular guided-screen composition
is JavaScript under `app/public/journey/`.

## 4. Construct and evolve a Persona

### Creation and Player intervention

The pure constructors have these source signatures:

```haskell
newPersona :: Int -> Player -> Text -> PersonaDraft -> Either Text Persona
revisePersona :: Text -> PersonaDraft -> Persona -> Either Text Persona
```

`newPersona` validates a nonblank name, stamps supplied attributes as
`PlayerSpecified`, copies initial description/context and starts revision zero.
IDs and timestamps are supplied by the shell. `Persistence.Persona.createPersona`
allocates the database ID and creates the Persona's session in a transaction.

`revisePersona` rejects archived entities and stale `draftRevision` values. It
updates current description, context and avatar while preserving initial fields.
The supplied attribute list replaces the current evolving-attribute list and is
marked `PlayerIntervention`; this is not a field-by-field patch API. Prior snapshots
remain in the audit history. The browser editor preserves its existing evolving
attributes when submitting its simpler description form.

`Origin` distinguishes `PlayerSpecified`, `PlayerIntervention`, `AIInferred` and
`Gameplay`. Attribute names and values remain open-ended (`Text` and Aeson `Value`).
There is no diagnostic taxonomy.

### Evidence and uncertainty

```haskell
observeTheme :: Text -> Evidence -> Persona -> Either Text Persona
```

For a given theme, an observation contains a stable evidence ID, origin, reference,
positive weight at most one, support/contradiction flag and observation timestamp.
Duplicate evidence IDs within that theme do not add support again. Invalid weights
and archived Personas are rejected.

The current score is:

```text
confidence = (1 + sum of supporting weights) / (2 + sum of all weights)
```

A weight-one supporting observation gives `2/3`. Adding a weight-one contradiction
gives `2/4 = 0.5`. This is an uncertainty-preserving support ratio with a neutral
prior, not a calibrated psychological probability or a full Bayesian network.

`Persistence.Persona.recordEvidence` locks the Persona, applies this pure function,
increments its revision only when changed and saves it. `rejectTheme` removes a
current theme while the trigger retains its previous document in audit history.
Evidence ingestion is not a public endpoint where clients can label arbitrary
claims as AI findings. Automatic theme extraction is not wired into the current
interpretation flow.

The implementation uses text timestamps, not a validated domain timestamp type;
`themeLastObserved` uses lexical ordering. Future producers should standardize
sortable timestamp formats before relying on cross-source chronological ordering.

## 5. Trace an encounter

[Persistence.Journey](../src/Persistence/Journey.hs) is the imperative coordinator.
It does not calculate a new yarrow procedure or alternative movement rule.

A responsive command authenticates a `User`, verifies any supplied Persona ID,
locks the active Persona/session, checks the workflow revision and stage, applies
a transition, increments the revision, saves, and returns a projection in a
transaction. `guardPersona` prevents an archive racing an accepted mutation.

| Command | Permitted stage | Result and durable effect |
| --- | --- | --- |
| `question` | progress or question | Enters question; captures current/previous position. |
| `suggest` | question | Uses the first question from the latest saved contemplation; inserts proposal and basis. No new model call. |
| `draft` | question | Updates workflow text and latest unfinalized proposal's Player text if present. |
| `begin` | question | Requires nonblank text, finalizes or creates a question record, enters casting with initial engine state. |
| `next` | casting | Advances `nextCastingState`; rejects an already completed casting. |
| `visual` | casting | Saves visual metadata only if its embedded engine equals the server snapshot. |
| `result` | casting | Requires six completed lines; records event, raw/result casting, question and planned destination. |
| `interpretation` | result | Changes workflow screen only. |
| `reflection` | interpretation | Enters reflection, with or without AI output. |
| `journal` | reflection | Saves journal on the event and workflow. |
| `movement` | reflection | Saves reflection and enters movement review. |
| `acknowledge` | movement | Applies resolved position to the session and resets the workflow to progress. |

For example, suppose a Persona starts at state 10 and an engine result contains
changing lines `[1,4]`. Movement is five. At `result`, the event records 10 to 15,
but the session is still at 10. At `acknowledge`, it becomes 15. This separates
the fact of the completed casting from the Player's acknowledgment of movement.

The earlier `/game/casting/next` flow differs: it updates position when casting
completes. `guardWorkflow` blocks conflicting prototype mutations while the
responsive flow owns an active encounter. Do not merge the two timelines casually.

Workflow stages are `Text` values plus `allowedStage`, not a closed algebraic data
type. Stage validation at the command boundary is therefore essential.

## 6. Understand casting and movement

### Canonical hexagrams

The internal hexagram key is a six-bit value in `0..63`. Yin is zero, Yang is one;
the bottom line is bit zero and the top is bit five. A changing line flips its
bit. King Wen numbering comes from explicit lookup tables in
[Domain.HexagramIndex](../src/Domain/HexagramIndex.hs); do not derive it by a formula.

### Yarrow engine

`Engine.Casting.initialCastingState` and `nextCastingState` expose explicit
ceremonial facts: heaps, removals, remainders, completed lines and a final result.
Three rounds produce one line. Six lines produce the hexagram. See the full
[yarrow contract](yarrow-casting.md) rather than duplicating it in a browser module.

The current initial seed is the literal `827364923`. Both live orchestration paths
start from that same initial state; fresh entropy is not currently supplied per
encounter. Deterministic replay is useful, but does not imply independent random
castings. The statistical suite separately detects line-frequency discrepancies.
Do not describe this implementation as statistically validated traditional sampling.

### Movement projection

These are the actual pure functions, from
[Engine.Movement](../src/Engine/Movement.hs) and [Engine.Game](../src/Engine/Game.hs):

```haskell
movementFromChangingLines :: [Int] -> Int
movementFromChangingLines positions = sum positions `mod` 7

applyCastingMovement :: Int -> CastingResult -> Int
applyCastingMovement current castingResult =
  min 72 (current + lilaMoveSquares castingResult)
```

The first function expects canonical line positions `1..6`; it does not validate
an arbitrary external list. `numberChanging` is the count, while `lilaMoveSquares`
is the separate projection. `[2,5]` changes the hexagram but moves zero squares.
`accessibleStateIds` lists up to the next six positions through 72; it is not a
complete snake/ladder topology.

New results record `movementRule = "changing-line-positions-mod7-v1"`. The custom
JSON decoder labels older results without that field as `changing-line-count-v1`
and preserves their stored movement. Historical results are not reprojected using
the newest rule. Keep that compatibility behavior when changing schemas.

## 7. Persist identity and history

[Persistence.Postgres.migrate](../src/Persistence/Postgres.hs) creates the original
tables and invokes [migratePersonas](../src/Persistence/PersonaSchema.hs), within a
transaction. Migrations are idempotent startup SQL, not numbered migration files
or a separate migration framework.

| Table | Ownership and purpose |
| --- | --- |
| `users` | Account ID, username and password hash. No board position. |
| `auth_sessions` | Bearer token, account and selected Persona. |
| `personas` | Relational ID/owner/archive status plus full JSON document. |
| `game_sessions` | Session ID, owner, unique Persona, current/previous state, saved casting. |
| `journey_workflows` | One non-null unique Persona key and workflow JSON. Legacy user column remains nullable. |
| `questions` | Earlier prototype question representation, with optional AI proposal/finalized timestamp. |
| `persona_questions` | Responsive proposal/final question, Persona/journey IDs, contextual basis and timestamps. |
| `game_events` | Encounter question, source/destination, casting facts, optional raw casting/previous state, mutable journal. |
| `contemplations` | Saved model response linked to an event. |
| `llm_requests` | Account-level operational usage/cost metadata linked to events. |
| `persona_audit` | Persona-owned before/after documents and event labels. |

Composite foreign keys enforce that session and authentication selection ownership
match the Persona's Player. `game_sessions.user_id` is no longer unique;
`game_sessions.persona_id` is unique. The current implementation therefore permits
many Personas per Player, but one session per Persona.

### Legacy adoption

For every session without a Persona, migration creates a neutral **Legacy persona**,
attaches the existing session and workflow, and fills unselected existing bearer
sessions for that account. It preserves session/event IDs and saved JSON. It does
not derive identity attributes from the username. Original dates that were never
stored cannot be reconstructed; the adopted Persona is created at migration time.

### Audit and archive

The `persona_history` trigger captures inserts, updates and deletes on Personas,
sessions, events, both question tables and workflows. Labels are implementation
labels such as `personas:UPDATE`, plus `LegacyJourneyAdopted`, rather than the full
conceptual event vocabulary. Journals and workflow documents are mutable, with
before/after audit snapshots; this is not complete event sourcing with a supplied
replay engine. Audit snapshots can include substantial casting/visual JSON, so
retention and storage growth require a future policy.

Archive marks the Persona document and relational flag, increments its revision,
and clears selections referring to it. It does not delete its session/events or
other Personas. There is no unarchive or permanent-delete operation today.

## 8. Use the API

[API.Server](../src/API/Server.hs) is the route contract. Authenticated operations
use `Authorization: Bearer <token>`. Get the token from registration or login;
never embed one in documentation or client source.

| Operation | Route |
| --- | --- |
| Register / log in | `POST /auth/register`, `POST /auth/login` |
| List / create | `GET /personas`, `POST /personas` |
| Read / update / archive | `GET`, `PUT`, `DELETE /personas/:id` |
| Select for this bearer session | `POST /personas/:id/select` |
| Select and load journey | `POST /personas/:id/journey` |
| Inspect audit / generation context | `GET /personas/:id/history`, `GET /personas/:id/question-context` |
| Reject a theme | `DELETE /personas/:id/themes/:theme` |
| Read / command active journey | `GET /journey-session`, `POST /journey-session` |
| Read active legacy projection | `GET /game` |
| Read canonical event context | `GET /game/contemplation-context/:eventId` |
| Request or retrieve interpretation | `POST /game/contemplation/:eventId` |
| Read account usage | `GET /game/contemplation-costs` |

### Create and select a Persona

After authentication, send this body to `POST /personas`:

```json
{
  "draftName": "Mira, keeper of the library",
  "draftDescription": "A fictional scholar learning to listen.",
  "draftAttributes": [
    {
      "attributeName": "responsibilities",
      "attributeValue": ["Maintain a community library"],
      "attributeOrigin": "PlayerSpecified",
      "attributeEvidence": []
    }
  ],
  "draftContext": "A younger colleague has challenged a cherished idea.",
  "draftAvatar": {
    "avatarDescription": "A plain robe and a worn notebook",
    "avatarAsset": null
  },
  "draftRevision": null
}
```

Take `personaId` from the response, then POST to its `/select` or `/journey` route.
Registration does not create a default Persona. Login currently selects the first
active Persona for backward-compatible clients, while the guided UI still presents
selection. Separate bearer sessions can hold different selections.

To edit, PUT a complete `PersonaDraft` with `draftRevision` equal to the returned
`personaRevision`. A stale value returns a conflict, not a blind overwrite.

### Submit a journey command

Read the current projection, then POST a body such as this. The numbers below are
illustrative: use IDs and revisions from your own response.

```json
{
  "expectedRevision": 3,
  "commandPersonaId": 12,
  "commandAction": "draft",
  "commandText": "What might Mira learn by listening first?",
  "commandVisual": null
}
```

Send `commandPersonaId` even though it is optional for compatibility. A mismatched
selection is rejected before mutation. `expectedRevision` must match the saved
workflow; each accepted command increments it. Never blindly retry a failed
mutation after an ambiguous network response: reload and reconcile first.

The projection includes `workflow`, `game`, `history`, `questions`, movement and
available contextual states. `terminal` and `topologyAvailable` are currently false.

Authentication failures use 401; missing/foreign Personas use 404; state, revision
and archive conflicts use 409; invalid input uses 400; model failures use 503.
Refer to `renderStoreError` for exact mappings and returned JSON error messages.

## 9. Build interpretation context

[Domain.Contemplation](../src/Domain/Contemplation.hs) builds canonical text and
casting context without a provider. [Interpretation.ContemplationModel](../src/Interpretation/ContemplationModel.hs)
contains the effect boundary:

```haskell
contemplate :: ContemplationContext -> IO ModelResult
```

This is a record selector for the configured adapter, not part of movement logic.
[Interpretation.OpenAI](../src/Interpretation/OpenAI.hs) implements the provider
request, response decoding and usage metadata. `contemplateEvent` checks context
and ownership, reuses stored responses where present, and records new output and
usage through persistence. Interpretation cannot feed a value back into casting.

`personaPrompt` serializes selected Persona fields, not the account username or
Player ID, and explicitly says they describe a fictional or constructed Persona.
The system instruction repeats that distinction and treats narrative content as
data, not commands. Stored journal text is not added to the current
`ContemplationContext` as a dedicated field.

`questionContext` is a different, future-facing boundary: it supplies Persona
context, current state/journey, event history including casting history, and
unresolved questions. It returns a richer snapshot for a future generator; the
current `suggest` action simply reuses the latest contemplation's first question.
Do not claim a history-aware generation pipeline already runs on each turn.

Proposal text and Player-final text are distinct columns in `persona_questions`.
The proposal's contextual basis records the source context. Subsequent edits do
not replace the proposal, and question differences must not be repurposed to infer
real Player characteristics.

The canonical source corpus currently covers hexagrams 11 and 36. Missing source
material fails before a model request. Provider storage is requested disabled;
that request setting does not establish an installation-wide privacy policy.

For an isolated, non-network context check:

```sh
cabal run tao-of-lila-interpretation-test -- --dry-run 11 36 "What might Mira notice?"
```

The direct-pair tool derives changing lines by comparing binary lookup values;
it does not invent casting history, create a Persona or record a journey event.

## 10. Understand browser responsibilities

| File | Responsibility |
| --- | --- |
| [app.js](../app/public/journey/app.js) | Auth and Persona forms, stage screens, navigation, draft saving and errors. |
| [api.js](../app/public/journey/api.js) | HTTP and session-storage bearer token. |
| [service.js](../app/public/journey/service.js) | Current projection, commands, recovery and explicit preview selection. |
| [components.js](../app/public/journey/components.js) | Escaped content, hexagrams, interpretation and movement presentation. |
| [demo.js](../app/public/journey/demo.js) | Browser-only fixtures, clearly separated from live rules. |
| [journey.ts](../web/yarrow-casting/src/journey.ts) | Integration with existing stalk renderer and choreography. |
| [line.ts](../web/yarrow-casting/src/line.ts) | Advances engine-owned steps through a complete line, saving intermediate snapshots and stopping at the reveal. |

The browser can interpolate stalk positions and display ceremonial phases. It
cannot divide heaps, determine line values, decide movement or invent transitions.
The server accepts a visual snapshot only when its embedded engine state matches
the saved engine state.

Questions and journals debounce saves by approximately 900 ms. Navigation paths
flush pending edits; failed writes remain unsaved in the UI. Tab crashes inside
the debounce window can still lose unsent text. Preview state uses its own session
storage; the standalone yarrow page uses local storage. Neither is the live
journey repository.

The new Persona screen currently exposes simple narrative fields and a technical
audit view. It has no generated-avatar UI, unarchive control, structured-attribute
editor, or theme-rejection button. Those are distinct from API/domain capability.

## 11. Validate changes

Use Cabal as the primary check:

```sh
cabal test
```

The last recorded implementation validation reports core and Persona acceptance
passing, but **aggregate `cabal test` is not green**: `movement-statistics` fails
its traditional yarrow-frequency assertions. See
[the statistical findings](responsive-journey.md#statistical-acceptance-findings).
Do not widen tolerances or alter movement to conceal a sampler discrepancy.
These are recorded implementation results, not tests rerun for this documentation.

For focused work:

```sh
cabal test tao-of-lila-test --test-show-details=direct
TAO_PERSONA_TEST_DB='postgresql://postgres:test-password@127.0.0.1:55439/postgres' \
  cabal test persona-persistence --test-show-details=direct
node scripts/journey-test.mjs
node scripts/persona-ui-test.mjs
node scripts/yarrow-line-test.mjs
```

The database URL above is an example; supply an actual disposable test connection.
`persona-persistence` creates and removes a uniquely named schema and checks repeat
migration, saved state/questions/journals, ownership, independent Personas, evidence
rejection, question provenance and archive retention. Without `TAO_PERSONA_TEST_DB`,
it prints SKIP; a green process exit in that mode is not database acceptance.

Against a separately started disposable API:

```sh
python3 scripts/persona-api-test.py http://127.0.0.1:8080
```

That script creates test accounts and leaves them in that test database. It covers
HTTP creation, selection, resume, editing, privacy and ownership isolation without
requesting AI. The Node tests exercise journey fixtures, login/signup and Persona-creation
handlers with a simulated DOM/API, and six-click casting with saved-phase
recovery and retry after engine acceptance. Install the frontend build dependencies
before running the line test. These checks do not cover live PostgreSQL or
visual browser rendering. The older `journey-api-test.py` predates explicit Persona
creation; review its registration/setup assumptions before using it unchanged.

When changing UI behavior, separately inspect live and preview flows, saved-stage
recovery, keyboard navigation and narrow layouts. Visual QA of the new Persona
selection screen remains an outstanding acceptance item in the implementation notes.

## 12. Extend the model deliberately

| Change | Start here | Boundary to preserve |
| --- | --- | --- |
| Add descriptive Persona dimensions | `PersonaAttribute`, API/editor | Open values, explicit origin, preserved initial context. |
| Add evidence extraction | `questionContext`, trusted `recordEvidence` | Stable references, uncertainty, inspection/rejection, no Player diagnosis. |
| Generate fresh next questions | Provider-neutral adapter and proposal storage | Store the proposal and basis before Player edits; no silent finalization. |
| Change movement | `Engine.Movement`, `Engine.Game`, result versioning | Preserve recorded historical movement and keep sampling independent. |
| Fix casting distribution / seed sourcing | `Engine.Casting` and imperative initialization boundary | Reproducible snapshots, explicit entropy, numerical and statistical tests. |
| Add source texts | `Domain.Contemplation` and canonical data | Attribution, coverage errors and binary-keyed domain identity. |
| Evolve avatar visuals | `Avatar`, asset/presentation layer | Traceable symbolic history; no simplistic emotional appearance mapping. |
| Support multiple journeys per Persona | Session uniqueness, selection and repositories | Introduce explicit journey choice; migrate existing sessions intact. |

Persona relationships, symbolic proximity, awareness, encounters, influence and
cross-player interaction remain deferred. The relationship type is only a future
boundary. Board distance, thematic similarity, trigram/I Ching patterns and shared
history should not be prematurely collapsed into one compatibility score.

Human decisions are still needed on evidence calibration, permanent deletion and
audit retention, restart/multiple-journey semantics, authoritative board topology,
and how future model-generated interpretations are reviewed. Keep those decisions
visible rather than burying them in helper functions.

The [User Manual](user-manual.md) describes what a Player can actually do. Update
it alongside public behavior changes, and update the [pamphlet](introduction-pamphlet.md)
only when new capabilities are ready to be represented to prospective Players.

## Documentation sources and pamphlet build

The [pamphlet](introduction-pamphlet.md) and [User Manual](user-manual.md) are
editable Markdown alongside this manual. The pamphlet has a five-page A5 PDF
renderer in [scripts/build-pamphlet.py](../scripts/build-pamphlet.py). In a Python
environment with `reportlab` installed, run:

```sh
python3 scripts/build-pamphlet.py
```

It reads the pamphlet Markdown and writes `output/pdf/tao-of-leela-pamphlet.pdf`.
The renderer checks page overflow; it uses explicit section groups, so review
pagination if the headings or copy change. Inspect the rendered pages before
sharing a new edition. This publication workflow is separate from game builds.

The live interface-flow figure is shared by the pamphlet and user manual. Its
vector source is [scripts/interface_flow.py](../scripts/interface_flow.py), which
writes [the Markdown SVG](diagrams/user-interface-flow.svg); both PDF builders
embed the same drawing. Update its stages against `Domain.Journey.allowedStage`
and the guided UI before regenerating the publications.
