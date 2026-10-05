# Responsive Tao of Leela journey

## Run and review

Run `cabal run tao-of-lila-api` with the existing PostgreSQL configuration and
open `/` or `/journey/`. The root opens the guided journey interface; the older
prototype remains at `/?prototype` and the standalone ceremony at `/yarrow/`.
Database migrations run through the existing startup path.

For the complete browser-only development journey, open
`/journey/?demo&scenario=ordinary#splash`. No account, database, or AI calls are
made in preview mode. The banner and scenario selector remain visible. Preview
state is stored in sessionStorage, separately for each scenario; Reset clears it.

Scenarios include zero, ordinary (one changing line), six changing lines,
ladder, snake, long-reading, long-journal, resume, and nirvana. Primary/resulting
hexagrams appear in all changing-line examples. A preview-only button completes
a casting immediately. Resume starts from a saved intermediate animation pose.
Ladder/snake/Nirvana examples are explicitly synthetic presentation fixtures;
they do not establish domain rules.

## Implementation stages

1. Shared shell, visual language, routing and components are implemented.
2. Splash, authentication, contextual progress and question are implemented.
3. The existing yarrow animation is integrated with server-owned engine state,
   one complete line per Next click, saved intermediate snapshots, and a
   Pause/Exit confirmation dialog. Six generation clicks complete a new hexagram;
   the next action opens its result.
4. Hexagram results, saved AI interpretation and journal reflection are
   implemented. Questions become immutable once casting begins.
5. Movement acknowledgment updates the game and returns to progress. A history
   and extensible completion screen are present; live special transitions and
   terminal outcomes await authoritative engine data.
6. Revision checks, durable workflow snapshots, autosave, and deterministic
   recovery tests are implemented. Real PostgreSQL acceptance remains unverified
   because the local container runtime is not running.
7. Safari desktop preview acceptance passed through the full loop, including
   a manual animation step, pause/reload, reflection, and updated progress.
   Responsive spot checks covered all eight listed dimensions. Phone portrait
   stalk detail remains small and needs a dedicated visual refinement.

## Separation of concerns

`Engine.Casting` and `Engine.Game` are unchanged. No browser component chooses
line values, counts stalk remainders, calculates movement destinations, or decides
whether a live state is terminal.

- `Domain.Journey`: explicit workflow record and permitted stage/action pairs.
- `Persistence.Journey`: authenticated workflow orchestration, row locking,
  revision validation, immutable event creation, journal persistence, and
  acknowledgment. It calls the existing pure engines.
- `Persistence.Postgres`: existing accounts, event and AI services; adds migration
  fields and guards against conflicting prototype mutations during an encounter.
- `app/public/journey/api.js`: authentication and HTTP transport.
- `service.js`: journey commands and recovery; selects the separate demo adapter
  only when the explicit `demo` query parameter is present.
- `components.js`: escaped text, questions, hexagrams, interpretation and movement
  components, plus configurable artwork lookup.
- `app.js`: screen composition, controlled navigation, autosave, loading/errors,
  and accessible confirmation dialog.
- `web/yarrow-casting/src/journey.ts`: animation host reusing the existing
  assignment, layout, rendering, pacing and tween modules.

Hash routes work with static hosting. The active server stage governs which game
screen can be shown; changing a hash cannot edit a finalized question or skip a
server transition. History and Pause are available without abandoning the move.
Authentication uses the existing user ID/password model, not invented email
login. Bearer tokens live in sessionStorage; closing a tab requires login again,
while the actual journey remains in PostgreSQL.

## Contract changes and why they were necessary

These extensions were chosen to avoid rewriting the existing GameView wire
format or casting/movement engines. The rationale was recorded before the
workflow implementation: the old API stored casts and events, but not the active
screen, animation phase, acknowledgment, or a revision for safe retries.

`GET /journey-session` loads the authenticated workflow plus game projection,
origin/previous states, saved interpretation, engine-resolved movement, and full
history. `POST /journey-session` accepts:

```json
{
  "expectedRevision": 12,
  "commandAction": "journal",
  "commandText": "My reflection…",
  "commandVisual": null
}
```

Actions are `question`, `draft`, `begin`, `next`, `visual`, `result`,
`interpretation`, `reflection`, `journal`, `movement`, and `acknowledge`.
Commands lock the game session and workflow, validate the revision and stage,
then save the next revision atomically. A stale request receives 409. The UI
provides a reload action rather than blindly retrying a mutating request.

The new `journey_workflows` table stores the pending encounter. `game_events`
gains nullable `raw_casting` and `previous_state_id` fields. Existing events and
seed data are preserved. Casting completion creates the event so the existing
AI service can interpret it. Unlike the original prototype orchestration,
the responsive path updates the current square only after movement acknowledgment.
Both paths still use `applyCastingMovement`.

The contemplation context now includes optional previous-state context and
casting facts (including nuclear trigrams). These additions carry already-known
facts to the AI service without making the UI construct its own interpretation
context. Stored responses are reused before requesting generation again. AI
interpretation and the player's journal remain separate records.

Prototype question/casting mutations lock the same session and reject changes
while the responsive workflow owns an active encounter. A previously started
prototype cast must be finished in the prototype before initializing the new
workflow; it is not silently reset or given a fabricated animation pose.

## Persistence and interruption

| Transition | Authoritative saved data |
| --- | --- |
| Authentication | Existing user, session and bearer authentication records |
| Question editing | Workflow question after a 900ms pause; flushed before Begin |
| Begin Casting | Immutable question, originating/previous states, initial casting |
| Next engine operation | Exact Haskell casting snapshot and incremented revision |
| Animation step | Phase, stalk assignments and visual seed, before animation plays |
| Result | Six lines, raw casting, hexagram results, movement facts, question, event timestamp |
| Interpretation | Separate contemplation response associated with the event |
| Reflection editing | Journal after a 900ms pause, preserving whitespace and newlines |
| Save / Continue | Journal and movement stage in the same transaction |
| Acknowledge | Current/previous squares and reset workflow in the same transaction |

The server checks that visual metadata embeds its actual casting snapshot; visual
metadata never replaces engine state. If an engine operation commits but visual
saving is interrupted, recovery uses the already-accepted engine snapshot for
that visual step instead of advancing twice. If an animation is interrupted after
saving, reload displays its accepted end pose.

Network errors retain the draft in memory and show an unsaved state. Pending
writes trigger the browser unload warning. Browser-only drafts during the 900ms
autosave window are not guaranteed to survive a browser/process crash. Failed
saves must be retried before leaving. Session recovery reads the server projection;
local browser state is not authoritative for live games.

History exposes all recorded events with castings, interpretations, journals and
timestamps, including a pending encounter once its casting is recorded. The
current implementation returns full history; pagination is a future performance
improvement for very long journeys.

## Responsive and visual assets

Below 640px, progress is a vertical narrative with one possibility per row.
At 640px there are two columns; at 1024px, three. FROM → CURRENT → POSSIBLE NEXT
retains its reading order at every size. Desktop splash composition is two-column.
Results reflow from one hexagram per row to side-by-side cards. Interpretation
uses a readable, keyboard-focusable scroll region; the journal grows vertically.
Movement reflows between a vertical sequence and a horizontal sequence.

`assets.json` maps symbolic kinds and IDs to local SVG/image paths, for example:

```json
{"hexagrams":{"7":"./art/hexagram-7.svg"},"states":{"2":"./art/seeking.svg"}}
```

Hexagram artwork IDs are canonical binary values, never King Wen numbers.
The registry also reserves trigrams, animals, elements, families, directions,
colours, consequences and other symbols. Missing artwork uses a replaceable
placeholder. The splash board remains a decorative 72-cell representation;
traditional board artwork has not been supplied.

## Validation

Passed:

- `cabal test`, including new stage guards and all existing engine tests.
- `node scripts/journey-test.mjs`: nine deterministic complete journey scenarios,
  exact snapshot reload, stale-command rejection, immutable questions, separate
  journals and interpretation, and one-time movement acknowledgment.
- JavaScript syntax checks and `git diff --check`.
- `npm run build:journey --prefix web/yarrow-casting`.

The deterministic JavaScript tests exercise the preview adapter, not PostgreSQL.
Run `python3 scripts/journey-api-test.py http://127.0.0.1:8080` against a disposable
local database/API for real authentication, SQL migrations, casting recovery,
revision conflicts, prototype locking, journal recovery and movement acknowledgment.
It creates one test account and does not call AI. This test was not run here because
no PostgreSQL server or running container runtime was available.

Safari responsive spot checks used 320×568, 390×844, 430×932, 844×390, 768×1024,
1024×768, 1366×768 and 1440×900. Progress cards reflowed vertically on phones,
into two columns on tablet portrait, and three on desktop. The ordinary full
preview loop was exercised in Safari, including saved-pose reload, interpretation,
journal and acknowledgment. Laptop results displayed the complete hexagram labels.
These were manual spot checks, not an automated viewport test matrix.

The narrow-screen yarrow scene currently scales its existing SVG viewBox. Captions
and controls are readable, but individual stalk details are small in portrait.
This is a reported layout limitation, not a passed detailed-ceremony acceptance
check. Long-reading/long-journal fixtures pass data-flow tests; exhaustive visual
and keyboard testing across every screen and viewport remains outstanding.

## Remaining domain/content requirements

- The live engine has no ladder/snake topology or explicit Nirvana/terminal rule.
  The server reports `topologyAvailable: false` and no terminal outcome; the UI
  does not silently interpret square 72 as Nirvana. An authoritative source is
  required to complete these live behaviors.
- `accessibleStateIds` supplies fewer than six destinations near 72. Six movement
  slots remain visible, with missing destinations labeled instead of invented.
- Hexagram commentary is only partially seeded. Display names use existing seeds
  first, then a binary-keyed label registry sourced from the [Unicode Yijing
  names list](https://www.unicode.org/charts/nameslist/n_4DC0.html), generated by
  `scripts/journey-labels.py`. This supplies labels, not canonical commentary.
  The AI canonical corpus currently covers hexagrams 11 and 36, so
  unsupported casts show the service error and offer reflection without AI.
- Actual account/database acceptance and exhaustive viewport/keyboard testing remain pending as noted above.

## Rebuild preview fixtures

The cast traces and ordinary destination projections are generated by Haskell,
not calculated by the browser:

```sh
cabal exec -- runghc -isrc scripts/journey-fixtures.hs > app/public/journey/castings.json
web/yarrow-casting/node_modules/.bin/esbuild scripts/journey-preview.ts --bundle --platform=node --outfile=/tmp/tao-journey-preview.cjs
node /tmp/tao-journey-preview.cjs
npm run build:journey --prefix web/yarrow-casting
```

The second step uses the existing visual assignment functions to add the saved
interrupted-casting pose. Explicit ladder/snake/terminal fixture destinations
remain confined to `demo.js`.

## Movement rule revision

New castings use `sum(changingLines) mod 7`. `numberChanging` remains the actual
changing-line count; `lilaMoveSquares` remains the separately recorded movement.
The additive `movementRule` field identifies `changing-line-positions-mod7-v1`.
Older stored results without that field decode as `changing-line-count-v1` and
retain their recorded movement; neither history nor pending completed moves is
recomputed. Incomplete casts finishing under the new code use the new rule.
The yarrow operations, line values and hexagram transformations are unchanged.

### Statistical acceptance findings

The position-sum rule is exact for all 64 possible changing-line subsets. With
independent probability 1/4 of change per line, exhaustive weighted enumeration
gives 1054/4096 (25.732421875%) for zero and 507/4096 (12.3779296875%) for each
nonzero movement. These exact assertions and every requested example pass.

The new strict `movement-statistics` Cabal suite samples 100,000 **complete engine
casts**, using reproducible seeds 1 through 100,000. It checks oracle facts and
movement separately, with absolute tolerances of 0.4 percentage points for line
values, 0.6 for movement targets, and 0.6 for the spread between nonzero moves.
It exposes a pre-existing sampling discrepancy:

| Outcome | Measured | Traditional/ideal target |
| --- | ---: | ---: |
| Line 6 | 5.6255% | 6.25% |
| Line 7 | 29.9755% | 31.25% |
| Line 8 | 44.3588% | 43.75% |
| Line 9 | 20.0402% | 18.75% |
| Movement 0 | 24.9600% | 25.7324% |
| Movement 1 | 12.4200% | 12.3779% |
| Movement 2 | 12.4130% | 12.3779% |
| Movement 3 | 12.4950% | 12.3779% |
| Movement 4 | 12.4170% | 12.3779% |
| Movement 5 | 12.7020% | 12.3779% |
| Movement 6 | 12.5930% | 12.3779% |

The statistical suite intentionally reports FAIL rather than widening tolerances
or manipulating movement to hide the discrepancy. The existing oracle sampling
was explicitly out of scope for this change. A separately authorized sampler
investigation is required to make the traditional-probability acceptance pass.
`cabal test` therefore now fails this new acceptance suite, while
`tao-of-lila-test` and all ten Node preview journeys pass.

The `still-changing` preview uses actual engine-generated lines 2 and 5 changing
and movement zero. The `six` preview also remains in place (21 mod 7 = 0).
Demo snapshots were regenerated, and their browser cache key was changed so old
preview sessions cannot silently mix the two rules.

## Persona selection and provenance

Live login now opens Persona selection. Create a constructed identity with a name,
description, narrative context and optional avatar description. **Create Persona
and begin** saves and selects it, then opens its journey immediately. Existing
Personas use **Resume**. The Personas control is available before entering a
journey and returns to selection after flushing pending edits;
each Persona keeps its own workflow, position, questions, castings and journal.
Editing preserves the initial description/context; Archive retains all history.
The selection screen exposes initial context, evidence themes and saved audit
history. Structured attributes are also accepted by the Persona API.

At the question stage, the Player can choose a suggested question from the last
saved AI interpretation, then edit or replace it. The original suggestion and the
final casting question are stored separately, with timestamps and contextual basis.
There is no automatic model call or inference about the Player from these edits.
A dedicated next-question model is deferred; GET `/personas/:id/question-context`
is its provider-neutral input boundary. It includes Persona context, current Leela
state, journey/casting history, themes and unresolved questions. Interpretation
requests now carry constructed Persona context and an explicit privacy instruction.

`GET /personas/:id/history` returns the ownership-checked audit history.
`DELETE /personas/:id/themes/:theme` rejects an observed theme, retaining its prior
state in that history. Evidence ingestion is a trusted repository operation rather
than a client endpoint that could claim arbitrary text came from AI.

The development schema directly models User → Persona → Journey. Startup resets
obsolete account-owned workflow tables and their test data; it retains accounts
but clears auth sessions. It does not migrate legacy games or create synthetic
Personas. Current-schema startup retains saved records. Each Persona has one
resumable journey; many Personas per User are supported. Login selects a sole
active Persona and offers Continue Journey. Multiple Personas require selection;
only zero active Personas automatically opens Create Persona.

Validation: `cabal test` covers domain behavior. Run
`TAO_PERSONA_TEST_DB='<connection string>' cabal test persona-persistence
--test-show-details=direct` for schema idempotence, development reset, independent
histories, sibling edits and ownership. This test creates and removes a unique
schema. Without the variable it reports SKIP. Persona field and UI event tests
cover zero/one/many routing, explicit creation, and optional avatar generation,
regeneration, acceptance and provider failure. The HTTP test accepts
`--avatar-disabled` when the server has no image-provider key.

Human decisions remain for evidence weighting/calibration, retention and permanent
deletion policy, multiple historical journeys per Persona, and the future dedicated
question-generation provider. Current scores are support ratios, not calibrated
probabilities. No Persona relationships, symbolic proximity, awareness beyond
Independent, influence, or cross-player interaction are implemented.

The persona redesign passes core, movement-statistics and PostgreSQL acceptance
suites. Visual browser QA remains separate from the UI event tests.

## Balanced Leela sampler (2026-10-05)

The user-selected live rule supersedes the traditional-probability target above.
Each line has equal chances of values 6, 7, 8, and 9. The resulting 64 equally
likely changing-line patterns produce movement counts 10,9,9,9,9,9,9 under the
unchanged sum-of-positions modulo-seven rule: 15.625% stillness and 14.0625% per
forward move. New casts use `LeelaBalanced`; old snapshots lacking a rule use
`LegacyHeapSplit` and continue unchanged. Browser demo fixtures stay historical.
The earlier statistical failure table describes the legacy sampler only.

Validation: 100,000 full castings produced movement frequencies 15.639%, 14.028%,
14.041%, 14.135%, 14.039%, 14.079%, and 14.039% for 0–6 respectively. Line-value,
changing-pattern, and primary-hexagram distribution checks pass. Core regression
and JSON-resume compatibility tests pass. Database acceptance skips unless a
disposable PostgreSQL test connection is configured.
