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
The deeper transformation model is described in `docs/category-theory.md`, where
Leela states, I Ching changes, Taoist cosmology, and player reflection are
treated as composable categories, functors, and contextual transformations.

## Stack

- Haskell
- Cabal
- Servant
- Aeson
- Warp
- PostgreSQL

## Project Layout

```text
app/
  Main.hs              # HTTP executable entry point
  public/index.html    # Minimal journey prototype
  public/yarrow/       # Isolated yarrow ceremony page
src/
  API/                 # Servant API
  Domain/              # Domain types, loading, and lookup tables
  Engine/              # Pure casting, reading, and game movement
  Interpretation/      # Interpretation composition
  Persistence/         # PostgreSQL users, sessions, castings, and history
web/
  yarrow-casting/      # TypeScript ceremony layer (SVG stalks, pacing)
data/
  leela.json           # Seed Leela state data
  hexagrams.json       # Seed I Ching hexagram data
  lines.json           # Moving-line lesson data
docs/
  board-layout.md      # Leela ring, I Ching grid, and moving-line layout
test/
```

## Run Locally

The convenience scripts prepare the local `libpq` path, start the Podman VM when
needed, start and check PostgreSQL, build the application, and launch the web
server in the background:

```bash
./scripts/start-prototype.sh
```

Open `http://localhost:8080/`. Runtime logs and the API process ID are kept in
the ignored `.runtime/` directory.

Stop the API and PostgreSQL cleanly with:

```bash
./scripts/stop-prototype.sh
```

The PostgreSQL volume is preserved by the stop script, so registered users and
journey history remain available the next time the prototype starts.

For manual startup, use `docker compose up -d postgres` followed by
`cabal run tao-of-lila-api`.

The default database connection is
`postgresql://tao:tao@localhost:5432/tao_of_lila`. Override it with
`DATABASE_URL`. Database tables are created idempotently at application startup.
On macOS, building `postgresql-simple` requires the `libpq` formula and its
`pg_config` executable on `PATH`.

The service listens on `PORT` when set, otherwise `8080`.

Open `http://localhost:8080/` for the journey prototype. It supports user
registration/login, persistent continuation, per-encounter question CRUD,
yarrow casting, casting-driven movement, and journals.

Completed journey events can progressively reveal canonical Chinese, lexical
possibilities, the Tao of Lila working translation, and the separately labelled
James Legge (1882) comparison for the initial Hexagram 11 → 36 corpus slice.
The **Contemplate this casting** action is deliberately separate and requires
`OPENAI_API_KEY`; `OPENAI_MODEL` defaults to `gpt-5-mini`. The Responses API is
called with provider storage disabled, and never calculates casting mechanics.

Model usage, latency, success, and cost estimates are recorded in
`llm_requests`. Cost estimates default to zero until deployment-specific rates
are configured, avoiding volatile pricing in domain code. The authenticated
`GET /game/contemplation-costs` endpoint returns the participant's monthly
aggregate.

Open `http://localhost:8080/yarrow/` for the isolated yarrow ceremony. Haskell
computes each casting step; the browser only performs it visually. Rebuild that
client after TypeScript changes with `./scripts/build-yarrow.sh`.

## Test

```bash
cabal test
```

## API

- `GET /health` returns service health.
- `GET /casting/initial` returns the pure yarrow engine's initial state.
- `POST /casting/next` advances a supplied `CastingState` without persistence.
- `GET /states` returns loaded Leela states.
- `GET /hexagrams` returns loaded hexagrams.
- `POST /reading` generates a full reading.
- `POST /interpret` returns only the interpretation for a reading request.
The authenticated prototype API uses `Authorization: Bearer <token>`:

- `POST /auth/register` creates a user and initial game session.
- `POST /auth/login` creates a bearer session.
- `GET /game` returns the current square, six reachable squares, question,
  casting, and recent journey events.
- `POST`, `PUT`, and `DELETE /game/question[/<id>]` manage the current
  encounter's question.
- `POST /game/casting/new` begins a per-user casting.
- `POST /game/casting/next` advances the yarrow engine and persists movement
  when casting completes.
- `PUT /game/journal/<event-id>` creates or updates an event journal entry.

Passwords are stored as bcrypt hashes. Raw yarrow casting state and completed
casting results are retained as PostgreSQL JSONB, while movement is recorded as
append-only game events.

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
- `docs/category-theory.md` defines the conceptual model of transformations.
- `docs/yarrow-casting.md` defines the numerical yarrow casting state engine.

### Movement from changing-line positions

New castings derive movement with `sum(changingLines) mod 7`, where line 1 is
at the bottom and line 6 at the top. `numberChanging` retains the actual count;
`lilaMoveSquares` stores the separate movement. Stillness can include changing
lines and a transformed hexagram: lines 2 and 5 change, but movement is zero.
Try `/journey/?demo&scenario=still-changing#splash`.

New results identify `movementRule: "changing-line-positions-mod7-v1"`. Existing
saved casts retain their count-based movement and decode as the earlier rule.
The yarrow sampling and hexagram calculations have not changed.

`cabal test tao-of-lila-test` passes the movement examples, exact probability
proof, compatibility checks and existing regression tests. `cabal test
movement-statistics` runs 100,000 full castings and currently **fails**: the
existing yarrow sampler does not match the traditional line-value frequencies.
Consequently, aggregate `cabal test` is not green. See
[the statistical findings](docs/responsive-journey.md#statistical-acceptance-findings).
