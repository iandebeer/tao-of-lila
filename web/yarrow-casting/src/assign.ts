import type { CeremonyPhase, EngineCastingState, Stalk } from "./types";
import { WITNESS_ID } from "./types";
import { seededShuffle } from "./rng";

export function assignForTransition(
  stalks: Stalk[],
  from: CeremonyPhase,
  to: CeremonyPhase,
  engine: EngineCastingState,
): Stalk[] {
  const next = stalks.map((stalk) => ({ ...stalk, noise: { ...stalk.noise } }));

  if (to === "bound" || to === "untying" || to === "full-set-50") {
    for (const stalk of next) stalk.group = "bundle";
    return next;
  }

  if (to === "remove-one") {
    for (const stalk of next) {
      stalk.group = stalk.id === WITNESS_ID ? "witness" : "bundle";
    }
    return next;
  }

  if (from === "remove-one" && to === "working-set-49") {
    for (const stalk of next) {
      stalk.group = stalk.id === WITNESS_ID ? "witness" : "working";
    }
    return next;
  }

  if (from === "working-set-49" && to === "divide") {
    splitHeaps(next, engine);
    return next;
  }

  if (from === "divide" && to === "take-one") {
    const right = next.filter((stalk) => stalk.group === "right");
    const chosen = right[right.length - 1];
    if (chosen) chosen.group = "finger";
    return next;
  }

  if (from === "take-one" && to === "count-left") {
    peelRemainder(next, "left", engine.roundSnapshot?.leftRemainder ?? 0);
    return next;
  }

  if (from === "count-left" && to === "count-right") {
    peelRemainder(next, "right", engine.roundSnapshot?.rightRemainder ?? 0);
    return next;
  }

  if (from === "count-right" && to === "collect") {
    for (const stalk of next) {
      if (stalk.group === "left-remainder" || stalk.group === "right-remainder" || stalk.group === "finger") {
        stalk.group = "remainder";
      }
    }
    return next;
  }

  if (from === "collect" && to === "operation-complete") {
    const completedOperation = Math.max(1, Math.min(3, engine.currentRound));
    for (const stalk of next) {
      if (stalk.group === "left-counted" || stalk.group === "right-counted") stalk.group = "working";
      if (stalk.group === "remainder") stalk.group = `discarded-${completedOperation}` as Stalk["group"];
    }
    return next;
  }

  if (from === "draw-line" && to === "next-line") {
    for (const stalk of next) {
      stalk.group = stalk.id === WITNESS_ID ? "witness" : "working";
    }
    return next;
  }

  if (from === "next-line" && to === "working-set-49") {
    return next;
  }

  return next;
}

function splitHeaps(stalks: Stalk[], engine: EngineCastingState): void {
  const leftCount = engine.roundSnapshot?.leftHeap;
  if (leftCount == null) return;
  const working = stalks.filter((stalk) => stalk.group === "working");
  const shuffled = seededShuffle(working, engine.seed);
  shuffled.forEach((stalk, index) => {
    stalk.group = index < leftCount ? "left" : "right";
  });
}

function peelRemainder(stalks: Stalk[], side: "left" | "right", remainder: number): void {
  const heap = stalks.filter((stalk) => stalk.group === side);
  const countedGroup = side === "left" ? "left-counted" : "right-counted";
  const remainderGroup = side === "left" ? "left-remainder" : "right-remainder";
  const splitAt = Math.max(0, heap.length - remainder);
  heap.forEach((stalk, index) => {
    stalk.group = index < splitAt ? countedGroup : remainderGroup;
  });
}
