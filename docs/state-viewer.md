# Tao of Lila State Viewer

The journey's current/reachable states, movement cards, result figures
and historical casting links open one reusable, read-only native dialog. It
retains the underlying form and journey stage. Escape or Close dismisses it;
focus returns to the original control. Phones use a vertical bottom sheet;
larger screens place the two trigram fields beside the hexagram.

## Canonical records and provenance

`data/leela.json` remains authoritative for the ten existing game identities.
The other 62 tile identities retain the engine's explicit unseeded wording.
`data/state-view-metadata.json` supplements them with optional interpretation,
visual identity, traditional reference records, eight trigram records and
64 binary-keyed hexagram records. Empty content is explicitly uncurated, never
invented by the browser or LLM. Ten game states and four traditional reference
states have original, concise editorial descriptions; four hexagrams have
original editorial summaries. No Johari commentary is reproduced.

The traditional examples supplied in the implementation brief conflict with
prototype identities: tile 3 is currently Discipline, not Krodha / Anger.
Consequently `traditionalReference` is a **separate partial board edition**,
not an overwrite. It contains the brief's 55 → 3 snake and 37 → 66 arrow,
including semantic descriptions and destination identities from the same
reference edition. The viewer explicitly explains that those immediate
transitions apply to the reference board, and are not active game rules.
No probabilities, positions, persistence, or movement mechanics are changed.
A full traditional-board migration needs an explicit edition/content decision.

Trigram names, Chinese, natural images, lines, and both directional arrangements
are migrated from `assets/bagua.json`. Animal and family associations follow
Shuo Gua (Discussion of the Trigrams), sections 8 and 10:
https://www.themathesontrust.org/papers/fareasternreligions/Yijing-Shuo_Gua-Wilhelm-Lynn.pdf
These are symbolic associations, not attributes of the Player. Hues are a
Tao of Lila editorial palette, not asserted universal traditional colours.
Element and artwork fields are nullable pending curation; natural image is
not silently relabelled as a Five Phases element.

All 64 English hexagram names are migrated from the existing binary-keyed
`hexagram-labels.json`. Chinese names and editorial summaries are initially
curated for 1, 2, 11 and 36. No unpaired translated classical quotations were
added. Glyphs follow Unicode's King Wen order; the canonical binary-to-King-Wen
mapping is validated against the existing Haskell lookup table.

## Build and API

Run `node scripts/build-state-catalog.mjs` after seed or metadata edits. The
checked-in JSON catalogue snapshots are deployment data, shared by the API
and database-free browser demo. `--check` detects stale snapshots without
writing. Docker regenerates them from sources on every build.

`Domain.StateView` provides typed records (including `Snake | Ladder`), pure
lookup functions and catalogue validation. Startup loads the catalogue and
rejects incomplete ID ranges, duplicate keys, inconsistent hexagram/trigram
structure, invalid reference destinations, unsafe asset paths and invalid hues.
`GET /state-views` exposes the validated, versioned catalogue without login.
Existing `/states` and `/hexagrams` responses retain their compatibility.

Future contextual interpretation can use `lookupStateView`,
`lookupHexagramView`, `lookupTrigramView` and `transitionDestination` to compose
canonical facts with existing `ContemplationContext`, Persona, question and
history. The reference edition must stay labelled and must never be inserted
as an actual movement event. The current LLM prompt is unchanged. Browser
selection uses the engine's stored primary/resulting values and changing-line
positions; it does not derive an oracle result or movement.

## Original artwork

Public assets live under:

- `app/public/assets/leela/states/`
- `app/public/assets/iching/animals/`
- `app/public/assets/iching/trigrams/`

Add original PNGs there and set `visualIdentity.imageAsset`,
`trigramVisual.imageAsset`, or `animalImageAsset` to the root-relative URL,
for example `/assets/iching/animals/horse.png`. Images preserve aspect ratio
and constrain their size; null assets render nothing, and failed image loads
hide the image without hiding any identity, association or interpretation.
Do not put asset paths, colour meanings, or destinations in UI templates.

## Validation

- `cabal test`: typed retrieval, all 64 King Wen mappings, both reference
  transitions, absent artwork, duplicate IDs and invalid destinations.
- `node scripts/build-state-catalog.mjs --check`: packaged snapshots match sources.
- `node scripts/state-viewer-test.mjs`: preserved seeds/trigrams, all slots,
  independent primary/resulting navigation, same-hexagram casts, safe PNGs,
  missing/broken artwork, retry, late responses after close and focus return.
- Existing journey and Persona UI regression scripts still apply.

The known movement-statistics failure is documented in responsive-journey.md;
it is unrelated to this display layer. Native Cabal currently needs the Mac's
Xcode licence accepted; the same tests can run in the existing Linux build image.

## Local field constraint

The complete 72-state catalogue stays in the data model. Neither the welcome
screen nor normal gameplay renders a full board. The progress screen shows only
the occupied state and the engine-provided reachable destinations; there is no
padding to six cards and no wider viewport expansion of the state set. Phone
cards are vertical; tablet/desktop can use two columns for the same records.

Clicking or tapping a card’s text, artwork, or padding opens its expanded
description in the state dialog. The Explore button provides keyboard access;
Close, Escape, or a click outside the dialog dismisses it and restores focus. Opening a destination
or its transition preview does not call any movement endpoint or modify current
position. Active transition markers come only from the game projection, never
from the separate traditional-reference edition. The existing live engine has
no active topology; demo fixtures exercise preview markers and expanded views.
`node scripts/local-field-test.mjs` covers visibility at ordinary and final
positions, selectable current/future states, and non-mutating transition previews.
