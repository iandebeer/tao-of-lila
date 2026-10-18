// Casting arithmetic stays in Haskell; the browser only reveals its result.
import { restoreJourneyVisual } from './journey-state';
import type { CeremonyState, EngineCastingState } from './types';

export async function generateLine(
  initial: CeremonyState,
  advance: (previous: EngineCastingState) => Promise<EngineCastingState>,
  accept: (state: CeremonyState) => Promise<void>,
  cancelled: () => boolean = () => false,
): Promise<CeremonyState> {
  if (initial.phase === 'hexagram-complete' || cancelled()) return initial;
  // Finish an interrupted reveal without casting another line.
  const engine = initial.phase === 'line-complete' ? initial.engine : await advance(initial.engine);
  if (cancelled()) return initial;
  if (!engine.result && engine.event !== 'LineComplete') {
    throw new Error('The casting did not complete a line. Please retry.');
  }
  const state = restoreJourneyVisual(engine, null);
  state.phase = engine.result ? 'hexagram-complete' : 'draw-line';
  await accept(state);
  return state;
}

export function lineAction(state: CeremonyState): string {
  return state.phase === 'hexagram-complete' ? 'Begin again' :
    `Generate line ${Math.min(6, state.engine.completedLines.length + (state.phase === 'line-complete' ? 0 : 1))} of 6`;
}
