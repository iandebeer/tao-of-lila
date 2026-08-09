# Yarrow Casting Engine

This document defines the numerical yarrow-stalk casting procedure used by the
I Ching casting state engine and its test client.

## Purpose

The casting engine is the source of truth for every numerical transition. The
browser test client must display engine state and send advance commands; it must
not calculate yarrow values independently.

## Ritual Structure

Each line starts from the traditional fifty stalks:

1. One stalk is set aside.
2. Forty-nine stalks remain as the working stalks.
3. The working stalks are divided into left and right heaps.
4. One stalk is removed from the right-hand heap and placed aside.
5. Left and right heaps are counted in groups of four.
6. Each heap's remainder is removed.
7. Remaining stalks proceed to the next round.
8. Three rounds determine one line.

The randomness belongs only in the heap division. The single removed stalk is
always taken from the right-hand heap.

```text
49 stalks
  -> divide
  -> left heap + right heap
  -> remove 1 from right heap
  -> count left remainder
  -> count right remainder
  -> remove remainders
  -> next round
```

## Line Values

After three rounds, divide the final stalk count by four:

```text
24 / 4 = 6 -> Changing Yin
28 / 4 = 7 -> Stable Yang
32 / 4 = 8 -> Stable Yin
36 / 4 = 9 -> Changing Yang
```

Lines are stored bottom-to-top. The bottom line is line `1` and bit `0` in the
canonical binary hexagram value.

## Engine Contract

- The engine exposes every meaningful transition as state.
- The engine performs all division, removal, grouping, remainder, and line-value
  calculations.
- The client may display state and request the next state.
- The client must not duplicate the yarrow algorithm.
- The seed must be visible for reproducibility.
- Future animation clients must bind to the same state transitions rather than
  reimplementing casting behavior.
