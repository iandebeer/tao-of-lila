# The Tao of Leela

## A question opens a path

*A contemplative game of life, consciousness and change.*

Life brings moments of clarity and confusion, attachment and release, movement
and stillness. How do we meet them? What do we notice, and what remains outside
our awareness?

Tao of Leela offers a space to explore these questions through symbolic play.
Here, consciousness means our awareness of experience: how we perceive a
situation, respond to it, and come to see it differently.

The game brings together an Indian tradition of spiritual board games, the
Chinese Book of Changes, and contemplation of the Dao, the Way. No prior
knowledge of these traditions is needed. Begin with curiosity about life.

## Leela: life as a journey

Leela belongs to the Indian spiritual-board tradition associated with **Gyan
Chaupar**, the game of knowledge. Historical boards taught paths toward spiritual
liberation: ladders aided progress; snakes marked hindrances. These varied games
gave rise to the familiar Snakes and Ladders.

Here, the **72-state Leela board** is a map of life and consciousness. Each
position offers a perspective for reflection, not a measure of personal worth.

Background: [Impart Encyclopedia of Art, Gyan Chaupar](https://imp-art.org/articles/gyan-chaupar/).

## I Ching: the Book of Changes

The **I Ching**, or **Yijing**, is an ancient Chinese classic used for divination
and philosophical reflection. Its **64 hexagrams** are patterns of six solid or
broken lines, representing Yang and Yin. Changing lines turn one pattern into another.

Traditionally, coins or counted yarrow stalks yield a pattern to consult about a
question. This game uses a digital yarrow ceremony. Its images and words invite
reflection on what is changing and how one might respond.

Background: [Columbia University Press, The Classic of Changes](https://cup.columbia.edu/book/the-classic-of-changes/9780231082952/).

## Dao: the Way

**Dao**, also written **Tao**, means the Way. Daoist thought invites attention
to ways of living in relation to the natural unfolding of things.

Here, contemplating the Way means noticing circumstances and considering a more
aware response. This meeting of traditions is the game's creative interpretation.

Background: [Stanford Encyclopedia of Philosophy, Daoism](https://plato.stanford.edu/entries/daoism/).

## Whose journey will you imagine?

From this broad contemplation of life, the game invites you to explore a
particular point of view. Perhaps an elderly scholar is learning to relinquish
certainty. Perhaps a young traveller is wondering what belonging means.

You are the **Player**: the person who observes, imagines and chooses. You create
and guide one or more **Personas**, constructed identities through which to
contemplate the Way. A Persona enters the Leela Field, asks questions and encounters
change. Its **Journey** preserves those experiences.

This separation creates room to explore. A Persona's age, circumstances and
beliefs need not be your own. You can consider how life might appear from another
position without making an autobiographical disclosure.

Each Persona has an independent history. You remain free to recognise personal
parallels, reject a reading, or simply observe. What the experience means to you
is yours to decide.

## One encounter, at your own pace

1. **Create or resume a Persona.** Give it a name and a situation to explore.
2. **Bring a question.** Ask from that Persona's point of view.
3. **Follow the yarrow ceremony.** Generate one complete line per click, six lines in all.
4. **Consider the pattern.** Observe the hexagram and its changing lines.
5. **Reflect and continue.** Record what stays with you and acknowledge movement.

For the scholar, you might ask:

> What might become possible if certainty gave way to curiosity?

## The journey at a glance

![Illustrated user interface flow with a Leela board on the splash screen, yarrow stalks, primary and relating hexagrams, and a reflection journal: sign in, choose or create a Persona, resume its saved stage, then progress through question, casting, result, optional interpretation, reflection and acknowledged movement.](diagrams/user-interface-flow.svg)

The diagram shows the live `/journey/` interface, with schematic board, yarrow,
hexagram and journal illustrations. Resume restores the selected
Persona's saved stage; it does not restart an unfinished encounter. AI assistance
is optional. The board position updates only when movement is acknowledged.
Pause, History and switching Personas preserve the accepted journey state.

## AI proposes; the Player chooses

Optional AI assistance offers possible readings and questions where source
material is available. You can use a suggested question, edit it or replace it
before casting. You can also reflect without AI.

The system is an interpretive companion, not an authority on the Way. It does
not seek to diagnose its Player or equate a Persona's characteristics with the
person guiding it.

## Begin a journey

On a running installation, open **`/journey/`**, sign up or log in, and choose
**Create Persona and begin**. A name, a situation and a little curiosity are enough to begin.

For a browser-only introduction, open
**`/journey/?demo&scenario=ordinary#splash`**. The labelled development preview
uses example data and does not create an account or save a live journey.

**About this edition.** Tao of Leela is a working prototype. Interpretation texts
cover only a small part of the I Ching; Personas currently journey independently.
The casting implementation is reproducible and still undergoing statistical
validation. Evolving avatars, Persona encounters and live snake-and-ladder
transitions remain future work. The historical board description explains the
inspiration, not a claim that all traditional rules are already implemented.

Read the [User Manual](user-manual.md) for a first encounter, saving and resuming,
and the current prototype limits. The [Developer Manual](developer-manual.md)
explains how the symbolic model becomes working software.
