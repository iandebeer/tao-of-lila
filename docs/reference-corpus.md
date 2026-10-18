# Reference corpus

The deployment bundles and installs a versioned corpus into PostgreSQL. Reading a
tile or contemplating a casting never downloads a reference website. The model
receives the recorded casting facts, current tile description, the primary and
resulting hexagram passages, selected changing lines and one bounded background
excerpt. It does not receive the entire document library.

## Coverage and provenance

- **72 Leela tiles:** a consistent traditional 72-square naming scheme with
  original Tao of Leela commentary. This replaces the initial ten custom states.
  Tile/Sanskrit label associations were cross-checked against the published board
  map at https://en.quantumgame.love/guide/leela-board-72-squares.html. Its modern
  prose is not copied. English naming varies between editions; this application's
  editorial choices are recorded in `data/references/leela-editorial.json`.
- **64 I Ching hexagrams:** received Chinese Judgment, Great Image and six lines;
  James Legge's 1882 translation, including the special all-changing passages for
  hexagrams 1 and 2. The internal key is binary 0–63, bottom line at bit zero.
  Existing lookup tables, never a derived ordering, supply King Wen numbers.
- **18 Bhagavad Gita chapters:** Edwin Arnold's *The Song Celestial* (1885).
  These are thematic background for reflection, not a Leela board manual. Each
  tile has an explicit editorial chapter association. At most 2,400 characters
  from that chapter's opening are supplied to the model; the full text stays in
  the database. These broad excerpts are not verse-level commentary.

The original Chinese comes from Project Gutenberg ebook 25501:
https://www.gutenberg.org/ebooks/25501. Arnold comes from ebook 2388:
https://www.gutenberg.org/ebooks/2388. Both source downloads retain their Gutenberg
notices. Historical works are public domain; modern Johari or Wilhelm/Baynes
commentary has **not** been ingested.

Legge judgments and lines are transcribed at Sacred Texts
(https://archive.sacred-texts.com/ich/index.htm). The bulk transcription was
obtained from https://scarletbeast.com/lab/oracle/codex/iching.json, which identifies
its source and public-domain status. Entries 1–6 were spot-checked against Sacred
Texts; all entries were structurally validated. The Great Images were extracted
from the two Appendix II sections at
https://archive.sacred-texts.com/ich/icap2-1.htm and
https://archive.sacred-texts.com/ich/icap2-2.htm. Only historical text and factual
metadata are packaged, not site code or modern commentary. Historical spelling
and language are retained. This is a sourced transcription, not a new critical
edition or a claim of a line-by-line scholarly audit.

## Storage and interpretation

`Domain.Reference` validates coverage, binary/King Wen agreement, paired source
fields, attribution, chapter links and source-document SHA-256 digests.
`Persistence.Reference` writes the validated edition transactionally into:

- `reference_documents`: full attributed source documents and their digests;
- `reference_hexagrams`: bilingual text, keyed by edition and binary value;
- `reference_leela`: descriptions, original commentary and chapter associations;
- `reference_chapters`: complete chapters and bounded attributed excerpts;
- `reference_active`: the currently installed edition.

The content-derived version retains old editions. Installation is idempotent and
runs at application startup after migrations, before the HTTP listener starts.
An invalid or absent bundled corpus prevents startup rather than silently
restoring generic descriptions. No credentials or network access are needed to
install the bundled data. Runtime queries read one edition consistently.

New contemplations save `source_context` alongside their response, including the
corpus version and exact passages sent to the model. Existing saved interpretations
are retained rather than silently regenerated or billed again. Start a new
encounter to test richer AI interpretations; previously saved readings remain as
written. The database-free diagnostic tool reads the same corpus from disk.

The model is instructed to distinguish historical quotation, project commentary
and its own reflection, to pair Chinese quotations with their supplied English,
and never to present Gita chapters as rules for numbered Leela tiles. Casting,
movement and dice probabilities are unchanged by the text update. The information
catalogue now includes all ten snake and ten ladder pairs from the referenced
board, with original commentary and links in both directions. These references
are now applied by the engine on landing; opening their information links is read-only.

## Updating the edition

Source files are committed under `data/references/sources/`. Updates are an
explicit maintenance operation, never a runtime scrape. After editing the source
or tile commentary:

```sh
python3 scripts/build-reference-corpus.py
node scripts/build-state-catalog.mjs
node scripts/version-web-assets.mjs
cabal test
node scripts/state-viewer-test.mjs
```

The Python packager requires only the standard library and makes no network
requests. Commit the generated corpus and domain/viewer projections together.
Docker copies the corpus and regenerates the public catalogue and cache versions.
The next deployment installs the new edition automatically. PostgreSQL acceptance
tests use `TAO_PERSONA_TEST_DB` and an isolated schema, testing repeat installation
and passage retrieval alongside the existing journey acceptance tests.

## Live snake and ladder movement

The engine now follows all ten snakes and ten ladders after a nonzero move lands
on an origin. The movement screen distinguishes landing from final destination;
acknowledgment saves the endpoint. Zero movement remains still. See
[movement behavior](responsive-journey.md#live-snake-and-ladder-movement-2026-10-13).
