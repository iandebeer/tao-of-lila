# Agent Guidance

Use this file as persistent guidance when working in this repository.

## Agent Roles

- Master Architect: Coordinates all agents.
- Geometry Agent: Owns SVG geometry.
- SVG Artist: Owns visual appearance.
- I Ching Scholar: Owns Bagua, trigrams, and hexagrams.
- Leela Scholar: Owns Leela states and transitions.
- Engine Agent: Owns Haskell.
- Category Theory Architect: Owns categorical abstractions, transformation laws,
  and composition boundaries.
- Animation Agent: Owns TypeScript ceremony and movement, including the isolated
  yarrow casting page.
- Integration Agent: Owns merging.
- Testing Agent: Owns validation.
- Curator: Owns philosophical consistency.

## Project Shape

- This is a Haskell/Cabal project for a contemplative Leela and I Ching engine.
- Keep domain logic independent of HTTP, persistence, deployment, and browser UI.
- The yarrow ceremony in `web/yarrow-casting/` may animate engine state but must
  not calculate casting results.
- Prefer small pure functions and explicit data structures over hidden runtime
  behavior.
- Preserve the functional-core, imperative-shell architecture described in
  `ARCHITECTURE.md`.

## Build And Test

- Use `cabal test` as the primary verification command.
- Use `cabal run tao-of-lila-api` to run the local API.
- Do not convert the project to Stack unless explicitly asked.
- If Cabal is unavailable, report that clearly instead of inventing a different
  build path.

## Domain Rules

- Treat the hexagram binary value `0..63` as the canonical internal key.
- Encode broken Yin lines as `0` and solid Yang lines as `1`.
- The bottom hexagram line is bit `0`; the top line is bit `5`.
- Use lookup tables for King Wen ordering. Do not derive King Wen numbers
  algorithmically.
- Keep future lookup tables keyed by binary value unless there is a clear public
  API reason to expose another identifier.
- Treat Leela movement, I Ching change, Taoist cosmology, and player reflection
  as composable transformations. Use `docs/category-theory.md` as the conceptual
  guide, but only introduce formal abstractions when they simplify real engine
  code.

## Editing Guidelines

- Keep changes scoped to the requested behavior.
- Preserve existing seed data and docs unless the task asks to replace them.
- Update tests when changing domain logic or lookup tables.
- Update root docs when changing architecture, build commands, or public API
  behavior.
- Avoid committing secrets, local editor state, or generated build artifacts.
