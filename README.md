# The Tao of Lila

The Player does not enter the Leela board directly. The Player creates and guides
one or more Personas. It is the Persona that enters the symbolic field of Leela,
moves through states, encounters the I Ching, asks questions, accumulates history
and undergoes transformation.

**Player → many Personas → independent Journeys.** A Persona is a constructed
identity, not an avatar, account profile, or journey. Its avatar is a visual
representation; its journey records position, castings, questions and reflections.
Initial characteristics are Player-authored narrative context; emergent themes
retain evidence and uncertainty without overwriting that origin.

Tao of Leela does not build a psychological model of its Player. A Persona may be
an elderly scholar, a fictional character, or someone in circumstances unlike the
Player's own. These descriptions never assert facts about the Player. Player,
Observer, Persona and Interpretation remain distinct; personal parallels belong
to the Player to recognise. **AI proposes; the Player disposes.** Questions may be
accepted, edited or replaced; edits are creative interventions, not psychological
signals about the Player. AI interpretation is assistance, not authority.

The board is the **Leela Field**, currently inhabited by independent Personas.
The affinity with Hermann Hesse's *The Glass Bead Game* is a design intention:
depth can grow through recognising relationships among Leela, I Ching, changing
lines, trigrams, Taoist ideas, Personas, questions, symbols, history and reflection,
rather than competition or optimisation. This introduces no new gameplay rule.


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

For a fully containerized server and phone access via Tailscale or Wi-Fi, see
[mobile testing instructions](docs/mobile-testing.md). Start that isolated
app-and-database stack with `./scripts/mobile.sh start`.

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

## Test interpretation in a browser

From the repository root, start the standalone local server:

```zsh
source ~/.zshrc
cabal run tao-of-lila-interpretation-test -- --web
```

Open **http://127.0.0.1:8081/**. Enter primary and resulting King Wen numbers,
a question, and a Leela state. **Preview casting** shows the hexagrams, derived
changing lines, and structured context without an AI call. **Interpret with
OpenAI** uses the same context and provider as the command-line test and shows
the interpretation, token usage, and latency. The page supports both desktop
and mobile layouts and displays validation/provider errors alongside the form.

The server binds only to `127.0.0.1`, uses `OPENAI_API_KEY` on the server, and
requires no database, login, or casting ceremony. Without a key, preview still
works and live interpretation reports the missing configuration. Stop the
server with Ctrl+C. Source-text coverage remains limited to hexagrams 11 and 36.
The OpenAI client allows up to 120 seconds for a response and reports response
timeouts separately from connection failures. Restart the test server after
changing or rebuilding the client.

## Test interpretation directly

Supply the **primary** and **resulting** King Wen numbers, in that order,
without running a casting ceremony or starting the API/database:

```bash
cabal run tao-of-lila-interpretation-test -- 11 36 "How can I retain my innocence while moving forward?"
```

Live mode requires `OPENAI_API_KEY` in the environment and uses `OPENAI_MODEL`
(default `gpt-5-mini`). It makes one model request using the same structured
context, prompt, response schema, and provider adapter as journey contemplation.
It prints the interpretation and token usage. It does not create a game event,
move a player, or write database records. Normal API token charges apply; this
standalone test does not record costs in the journey's usage ledger.

To inspect the input without an API key or a model request:

```bash
cabal run tao-of-lila-interpretation-test -- --dry-run 11 36 "How can I meet this transition?"
```

The command derives changing lines by comparing the canonical binary values
looked up from the King Wen table, bottom line first. `11 36` changes line 2
(old Yang, value 9); `36 11` changes line 2 (old Yin, value 6). An identical
pair has no changing lines. The optional final argument selects a Leela state
ID from `data/leela.json`; the default is state 1. Run from the repository root.

The current source-text corpus contains **11 and 36 only**, so supported pairs
are `11 36`, `36 11`, `11 11`, and `36 36`. Other valid numbers report missing
source text before any LLM request. Legge line comparisons remain incomplete
and are labelled as such in the context. This test uses the existing
interpretation guide; it does not add a new tradition of line-selection rules.

`cabal test` covers number lookup, pair-derived context, and Responses API
parsing (including reasoning items, refusals, and incomplete responses) without
network access. Live output quality is assessed separately with the command above.

## API

- `GET /health` returns service health.
- `GET /casting/initial` returns the pure yarrow engine's initial state.
- `POST /casting/next` advances a supplied `CastingState` without persistence.
- `GET /states` returns loaded Leela states.
- `GET /hexagrams` returns loaded hexagrams.
- `POST /reading` generates a full reading.
- `POST /interpret` returns only the interpretation for a reading request.
The authenticated prototype API uses `Authorization: Bearer <token>`:

- `POST /auth/register` creates a Player account; create/select a Persona next.
- `POST /auth/login` creates a bearer session.
- `GET/POST /personas` lists or creates Personas; `GET/PUT /personas/<id>`
  reads or edits one, preserving its initial context.
- `POST /personas/<id>/select` selects the Persona for this bearer session;
  `POST /personas/<id>/journey` selects and resumes its journey.
- `DELETE /personas/<id>` archives without deleting history.
- `GET /personas/<id>/question-context` returns Persona-specific generation context;
  `GET /personas/<id>/history` exposes audit records.
- `GET /game` returns the current square, six reachable squares, question,
  casting, and recent journey events.
- `POST`, `PUT`, and `DELETE /game/question[/<id>]` manage the current
  encounter's question.
- `POST /game/casting/new` begins a casting for the selected Persona.
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

- [Introduction and promotional pamphlet](docs/introduction-pamphlet.md): the invitation, experience and prototype scope.
- [User manual](docs/user-manual.md): Persona creation, a first encounter, recovery and troubleshooting.
- [Developer manual](docs/developer-manual.md): concepts mapped to Haskell, tables, routes and workflow transitions.

- `ARCHITECTURE.md` describes the functional-core architecture and boundaries.
- `ROADMAP.md` tracks planned product and domain-model work.
- `AGENTS.md` gives guidance for AI agents working in this repository.
- `docs/board-layout.md` documents the initial board visualization contract.
- `docs/category-theory.md` defines the conceptual model of transformations.
- `docs/yarrow-casting.md` defines the numerical yarrow casting state engine.

## Responsive journey

Open `/journey/` on the API server for the guided Question → Casting → Result →
Interpretation → Reflection → Movement cycle. Casting and movement remain in
the existing Haskell engines. The new workflow persists the active screen,
question, casting/animation snapshot and journal; acknowledgment updates progress.

Open `/journey/?demo&scenario=ordinary#splash` for the complete deterministic
preview without an account or AI calls. Nine scenarios cover changing-line counts,
special-transition fixtures, long text, interruption and completion. Live ladder,
snake and terminal rules remain unavailable in the current domain model.

See [architecture, persistence and acceptance notes](docs/responsive-journey.md).
Build the integrated animation with `npm run build:journey --prefix
web/yarrow-casting`; run `cabal test` and `node scripts/journey-test.mjs`.

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
