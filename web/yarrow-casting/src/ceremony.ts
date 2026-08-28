import type { CeremonyPhase, EngineCastingState } from "./types";

export const durations = {
  untying: 2000,
  cordFalls: 1000,
  pause: 1200,
  removeOne: 1500,
  pauseAfterRemove: 1000,
  divide: 2000,
  settle: 700,
  takeOne: 1000,
  count: 2600,
  revealRemainder: 1000,
  collect: 1200,
  gather: 1600,
  drawLine: 1400,
  default: 1100,
};

export function continueNeedsAdvance(phase: CeremonyPhase): boolean {
  return (
    phase === "full-set-50" ||
    phase === "working-set-49" ||
    phase === "divide" ||
    phase === "take-one" ||
    phase === "collect" ||
    phase === "operation-complete" ||
    phase === "next-line"
  );
}

export function phaseAfterContinue(phase: CeremonyPhase, engine: EngineCastingState): CeremonyPhase {
  switch (phase) {
    case "bound":
      return "untying";
    case "untying":
      return "full-set-50";
    case "full-set-50":
      return "remove-one";
    case "remove-one":
      return "working-set-49";
    case "working-set-49":
      return "divide";
    case "divide":
      return "take-one";
    case "take-one":
      return "count-left";
    case "count-left":
      return "count-right";
    case "count-right":
      return "collect";
    case "collect":
      return "operation-complete";
    case "operation-complete":
      return engine.event === "LineStarted" ? "working-set-49" : "line-complete";
    case "line-complete":
      return "draw-line";
    case "draw-line":
      return engine.event === "CastingComplete" ? "hexagram-complete" : "next-line";
    case "next-line":
      return "working-set-49";
    case "hexagram-complete":
      return "bound";
  }
}

export function animationDuration(from: CeremonyPhase, to: CeremonyPhase): { move: number; settle: number } {
  if (from === "bound" && to === "untying") return { move: durations.untying, settle: 0 };
  if (from === "untying" && to === "full-set-50") return { move: durations.cordFalls + durations.pause, settle: 0 };
  if (to === "remove-one") return { move: durations.removeOne, settle: durations.pauseAfterRemove };
  if (to === "working-set-49") return { move: durations.gather, settle: durations.settle };
  if (to === "divide") return { move: durations.divide, settle: durations.settle };
  if (to === "take-one") return { move: durations.takeOne, settle: durations.settle };
  if (to === "count-left" || to === "count-right") return { move: durations.count, settle: durations.revealRemainder };
  if (to === "collect") return { move: durations.collect, settle: durations.settle };
  if (to === "operation-complete") return { move: durations.gather, settle: durations.settle };
  if (to === "draw-line") return { move: durations.drawLine, settle: 200 };
  return { move: durations.default, settle: durations.settle };
}

export function caption(phase: CeremonyPhase, engine: EngineCastingState): string {
  switch (phase) {
    case "bound":
      return "Fifty yarrow stalks, bound as one.";
    case "untying":
      return "The cord loosens. The bundle is no longer held.";
    case "full-set-50":
      return "The full set rests, slightly relaxed.";
    case "remove-one":
      return "One stalk is withdrawn. It will witness the casting.";
    case "working-set-49":
      return engine.currentRound === 1 && engine.completedLines.length === engine.currentLine - 1
        ? "Forty-nine working stalks remain."
        : `${engine.workingStalks} stalks remain for this operation.`;
    case "divide":
      return snapshotCounts(engine, "The stalks are divided into two heaps.");
    case "take-one":
      return "One stalk is taken from the right heap.";
    case "count-left":
      return remainderLine(engine, "left", "The left heap is counted in groups of four.");
    case "count-right":
      return remainderLine(engine, "right", "The right heap is counted in groups of four.");
    case "collect":
      return "Remainders gather. They will not return to this operation.";
    case "operation-complete":
      return engine.currentRound < 3
        ? `Operation ${engine.currentRound} of 3 is complete.`
        : "Three operations have produced a line.";
    case "line-complete":
      return latestLine(engine);
    case "draw-line":
      return latestLine(engine);
    case "next-line":
      return "The working stalks return. The next line will be built above.";
    case "hexagram-complete":
      return completeCaption(engine);
  }
}

export function continueLabel(phase: CeremonyPhase, engine: EngineCastingState): string {
  switch (phase) {
    case "bound":
      return "Untie the cord";
    case "untying":
      return "Release the bundle";
    case "full-set-50":
      return "Withdraw one stalk";
    case "remove-one":
      return "Continue";
    case "working-set-49":
      return "Divide the stalks";
    case "divide":
      return "Take one from the right";
    case "take-one":
      return "Count the left by fours";
    case "count-left":
      return "Count the right by fours";
    case "count-right":
      return "Collect the remainders";
    case "collect":
      return "Complete this operation";
    case "operation-complete":
      return engine.currentRound < 3 ? "Begin the next operation" : "Complete this line";
    case "line-complete":
      return "Draw the line";
    case "draw-line":
      return engine.event === "CastingComplete" ? "See the hexagram" : "Prepare the next line";
    case "next-line":
      return "Continue";
    case "hexagram-complete":
      return "Begin again";
  }
}

export function statusLine(engine: EngineCastingState, phase: CeremonyPhase): string {
  if (phase === "bound" || phase === "untying" || phase === "full-set-50") {
    return "Line 1 of 6 · before the first operation";
  }
  if (phase === "hexagram-complete") {
    return "Hexagram complete";
  }
  const operation = Math.max(1, engine.currentRound);
  return `Line ${engine.currentLine} of 6 · Operation ${operation} of 3`;
}

function snapshotCounts(engine: EngineCastingState, fallback: string): string {
  const snapshot = engine.roundSnapshot;
  if (!snapshot?.leftHeap || !snapshot.rightHeap) return fallback;
  return `Left ${snapshot.leftHeap}, right ${snapshot.rightHeap}.`;
}

function remainderLine(engine: EngineCastingState, side: "left" | "right", fallback: string): string {
  const snapshot = engine.roundSnapshot;
  const remainder = side === "left" ? snapshot?.leftRemainder : snapshot?.rightRemainder;
  const groups = side === "left" ? snapshot?.leftGroupsOfFour : snapshot?.rightGroupsOfFour;
  if (remainder == null || groups == null) return fallback;
  return `${groups} group${groups === 1 ? "" : "s"} of four. Remainder ${remainder}.`;
}

function latestLine(engine: EngineCastingState): string {
  const line = engine.completedLines[engine.completedLines.length - 1];
  if (!line) return "A line has been completed.";
  return `Line ${line.lineNumber}: ${line.lineValue} — ${line.lineInterpretation}.`;
}

function completeCaption(engine: EngineCastingState): string {
  const result = engine.result;
  if (!result) return "The hexagram is complete.";
  const primary = result.primaryKingWenNumber ?? result.primaryBinaryValue;
  const transformed = result.transformedKingWenNumber ?? result.transformedBinaryValue;
  if (result.numberChanging === 0) {
    return `Hexagram ${primary}. No changing lines.`;
  }
  return `Hexagram ${primary} becomes ${transformed}. ${result.numberChanging} changing line${result.numberChanging === 1 ? "" : "s"}.`;
}
