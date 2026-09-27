export type EngineEvent =
  | "CastingNew"
  | "LineStarted"
  | "HeapsDivided"
  | "SingleStalkRemoved"
  | "RemaindersCounted"
  | "RoundComplete"
  | "LineComplete"
  | "CastingComplete";

export type CeremonyPhase =
  | "bound"
  | "untying"
  | "full-set-50"
  | "remove-one"
  | "working-set-49"
  | "divide"
  | "take-one"
  | "count-left"
  | "count-right"
  | "collect"
  | "operation-complete"
  | "line-complete"
  | "draw-line"
  | "next-line"
  | "hexagram-complete";

export type StalkGroup =
  | "bundle"
  | "witness"
  | "working"
  | "left"
  | "right"
  | "finger"
  | "left-counted"
  | "right-counted"
  | "left-remainder"
  | "right-remainder"
  | "remainder"
  | "discarded"
  | "discarded-1"
  | "discarded-2"
  | "discarded-3";

export interface RoundSnapshot {
  previousWorkingStalks: number;
  leftHeap: number | null;
  rightHeap: number | null;
  removedSide: string | null;
  leftAfterSingle: number | null;
  rightAfterSingle: number | null;
  singleRemoved: number;
  leftGroupsOfFour: number | null;
  rightGroupsOfFour: number | null;
  leftRemainder: number | null;
  rightRemainder: number | null;
  totalRemoved: number | null;
  stalksRemaining: number | null;
}

export interface LineResult {
  lineNumber: number;
  finalStalkCount: number;
  lineValue: number;
  lineInterpretation: string;
  isChanging: boolean;
}

export interface TrigramResult {
  trigramName: string;
  trigramSymbol: string;
  trigramBinaryValue: number;
}

export interface CastingResult {
  primaryBinaryValue: number;
  transformedBinaryValue: number;
  primaryKingWenNumber: number | null;
  transformedKingWenNumber: number | null;
  changingLines: number[];
  numberChanging: number;
  upperTrigramResult: TrigramResult;
  lowerTrigramResult: TrigramResult;
  nuclearUpperTrigramResult: TrigramResult;
  nuclearLowerTrigramResult: TrigramResult;
  movementRule?: string;
  lilaMoveSquares: number;
}

export interface CastingDebug {
  debugSeed: number;
  debugCastingId: string;
  debugStateId: number;
  debugEvent: string;
  debugDivisionPoint: number | null;
  debugRemovedSide: string | null;
  debugWorkingBefore: number;
  debugWorkingAfter: number;
}

export interface EngineCastingState {
  castingId: string;
  seed: number;
  stateId: number;
  event: EngineEvent | string;
  prompt: string;
  totalStalks: number;
  setAside: number;
  workingStalks: number;
  currentLine: number;
  currentRound: number;
  roundSnapshot: RoundSnapshot | null;
  completedLines: LineResult[];
  result: CastingResult | null;
  debug: CastingDebug;
}

export interface StalkNoise {
  dx: number;
  dy: number;
  rot: number;
  length: number;
  thick: number;
}

export interface Stalk {
  id: number;
  variant: number;
  group: StalkGroup;
  noise: StalkNoise;
}

export interface Pose {
  x: number;
  y: number;
  rotation: number;
  opacity: number;
  delay: number;
}

export interface CeremonyState {
  version: 1;
  engine: EngineCastingState;
  phase: CeremonyPhase;
  stalks: Stalk[];
  visualSeed: number;
}

export const WITNESS_ID = 50;
export const STALK_COUNT = 50;
export const VARIANT_COUNT = 15;
