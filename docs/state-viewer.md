# Tao of Lila State Viewer

The journey's current/reachable states, movement cards, result figures
and historical casting links open one reusable, read-only native dialog. It
retains the underlying form and journey stage. Escape or Close dismisses it;
focus returns to the original control. Phones use a vertical bottom sheet;
larger screens place the two trigram fields beside the hexagram.

## Canonical records and provenance

`data/references/leela-editorial.json` contains a consistent 72-square naming
scheme and original project commentary. The obsolete ten-state prototype has
been replaced with the user's approval. `data/leela.json` is its domain projection.
The complete source library in `data/references/library.json` supplies the same
identities to the viewer and the interpretation database.

No modern Johari commentary is reproduced. Bhagavad Gita excerpts are clearly
labelled thematic background, not a historical commentary on numbered squares.
The existing 55 → 3 and 37 → 66 reference transitions remain informational;
this content change does not alter casting, movement or board topology.

Trigram names, Chinese, natural images, lines, and both directional arrangements
are migrated from `assets/bagua.json`. Animal and family associations follow
Shuo Gua (Discussion of the Trigrams), sections 8 and 10:
https://www.themathesontrust.org/papers/fareasternreligions/Yijing-Shuo_Gua-Wilhelm-Lynn.pdf
These are symbolic associations, not attributes of the Player. Hues are a
Tao of Lila editorial palette, not asserted universal traditional colours.
Element and artwork fields are nullable pending curation; natural image is
not silently relabelled as a Five Phases element.

All 64 hexagrams include Chinese names and paired Chinese/Legge Judgments,
Images and all six line texts. Primary changing lines are also shown separately.
Readers can expand all six lines and the special all-changing passages for
hexagrams 1 and 2. Text is escaped before rendering. The Haskell lookup table
validates the binary-to-King-Wen mapping; bit zero is the bottom line.

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

The local progress field and tile dialog now show both endpoints of all ten snakes
and ten ladders in the reference board. An in-scope destination links back to its
origin; an in-scope origin links forward to its destination. Endpoint links can
open out-of-scope tile details without adding reachable cards or moving the Persona.
The screen and dialog share one catalogue request per page.
