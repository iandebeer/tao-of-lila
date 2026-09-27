# Category Theory Model

This document describes the conceptual model of transformation for The Tao of
Lila. It is not an implementation mandate for every Haskell type today. It is a
mathematical north star: use it to preserve clear composition, avoid duplicated
logic, and keep game mechanics distinct from interpretation.

## Purpose

The Tao of Lila is not only a board with tokens. It is a system of
transformations:

```text
State -> Change -> Meaning -> Reflection -> State
```

Category theory is appropriate here because the project is built from objects,
morphisms, composition, context, and interpretation. Haskell gives these ideas
practical form through pure functions, functors, applicatives, monads, arrows,
and profunctors.

## Consciousness Category

Define a category `L`, the Leela category.

- Objects are the 72 Leela states.
- Morphisms are valid movements or transformations between states.
- Composition represents successive movement through consciousness.

Example:

```text
Faith --reflection--> Compassion
Compassion --shadow--> Envy
Envy --discernment--> Illusion
Illusion --return--> Liberation
```

Each board square is an object. Snakes, ladders, ordinary movement, and
intentional transitions become morphisms. These morphisms belong in domain data
and engine logic, not in SVG geometry.

## I Ching Category

Define a category `I`, the I Ching category.

- Objects are the 64 hexagrams.
- Morphisms are changing-line transformations.
- Composition represents successive changes of lines.

Every changing line is a morphism from one hexagram object to another:

```text
Hexagram 1 --line 2 changes--> Hexagram 44
```

The canonical internal key remains the six-bit binary hexagram value. A
changing line flips exactly one bit. King Wen numbers are lookup metadata, not
the internal identity of the object.

## Tao Category

Define a category `T`, the Tao cosmology category.

- Objects include Yin, Yang, Qi, Wu Ji, Tai Ji, the Eight Trigrams, and the Five
  Elements.
- Morphisms include generation, control, balance, return, differentiation, and
  reintegration.

This category should remain symbolic and carefully curated. It informs Bagua,
trigram, and cosmological metadata without collapsing them into game mechanics.

## Persona and the observing Player

The Player guides one or more constructed Personas. Journey history, intention,
current Leela state, hexagrams and reflections belong to each Persona's journey,
not to a psychological model of the real Player. A Persona's identity need not
be an immutable essence: it can be understood through transformations, history,
encounters, relationships, and arrows into and out of it. A future relationship
`Persona A → Persona B` may become as meaningful as either object.

This is philosophical guidance, not a requirement for literal categorical classes.
The Player observes and chooses; interpretation remains the Player's prerogative.

## Functors

The oracle can be modeled as a functor:

```text
F : I -> L
```

It maps I Ching change into Leela movement.

Example:

```text
Hexagram 24
  -> Return
  -> move from Illusion to Faith
```

Another functor maps Tao cosmology into I Ching structure:

```text
G : T -> I
```

Composition then expresses the full symbolic pathway:

```text
Tao cosmology -> Hexagram change -> Leela transition

F . G : T -> L
```

In implementation terms, this means the engine should prefer composable
transformations over one-off case logic.

## Natural Transformations

Different interpretation systems can be treated as functors from I Ching
structure into Leela meaning.

For example:

```text
Wilhelm : I -> L
TaoOfLila : I -> L
```

A natural transformation:

```text
eta : Wilhelm => TaoOfLila
```

models the correspondence between interpretive traditions. This is useful for
future commentary layers: translations can differ without changing the underlying
hexagram or movement model.

## Monoidal Structure

Persona transformation rarely comes from one input alone. Reflection, meditation,
coin toss, yarrow stalks, dice, hexagram change, and board movement can combine.

This suggests a monoidal structure:

```text
(L, tensor)

Meditation tensor Reflection tensor Hexagram -> Transformation
```

The practical design principle is to keep effects composable. Inputs should be
represented as values that can combine into a transition, not as scattered
conditionals.

## Endofunctors

Some practices transform Leela states without leaving the Leela category.

Example:

```text
Meditation : L -> L
```

Meditation can be modeled as an endofunctor that transforms every state in a
consistent way while preserving the category.

## Monad

The Persona carries journey context. A monad is the right conceptual model for
context-aware transformation:

```text
Persona a -> Reflection -> Transformation -> Persona b
```

The project should not force a monad abstraction before it is needed, but future
engine work should recognize that readings, history, intention, and accumulated
reflection are contextual computations.

## Bicategory

The complete system may be better understood as a bicategory rather than a
single category.

One layer represents objective game transitions:

```text
Persona moves from Faith to Compassion
```

Another layer represents subjective interpretation:

```text
Understanding moves toward Forgiveness
```

These layers interact but are not identical. A bicategorical model leaves room
for both the concrete mechanics of the board and the evolving meaning of the
Persona's journey.

## Whole System

The intended conceptual stack is:

```text
Tao
  -> Bagua category
  -> Hexagram category
  -> Tao of Lila functor
  -> Consciousness category
  -> Persona context
  -> Reflection monad
```

This should guide architecture:

- SVG remains geometry.
- JSON remains metadata and relationships.
- Haskell models objects, morphisms, and composition.
- Interpretation remains a layer over domain events, not a replacement for them.
- UI presents transformations without owning their rules.

## Implementation Guidance

Near-term Haskell work should express these ideas conservatively:

- Use newtypes for stable identities such as `SquareId`, `HexagramBinary`, and
  `PlayerId`.
- Represent transitions as explicit values.
- Keep composition pure and testable.
- Avoid encoding symbolic meaning in SVG ids or UI state.
- Add categorical abstractions only when repeated transition logic makes them
  useful.

The goal is not to decorate the code with category theory vocabulary. The goal
is to let the ontology of transformation shape clean, composable software.
