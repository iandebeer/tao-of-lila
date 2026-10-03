// Advance engine-owned steps automatically, stopping only at a revealed line.
import { assignForTransition } from './assign';
import { continueNeedsAdvance, phaseAfterContinue } from './ceremony';
import { snapshot } from './persist';
import type { CeremonyState, EngineCastingState } from './types';

export async function generateLine(
  initial: CeremonyState,
  advance: (previous: EngineCastingState) => Promise<EngineCastingState>,
  accept: (state: CeremonyState) => Promise<void>,
  cancelled: () => boolean = () => false,
): Promise<CeremonyState> {
  let state = initial;
  if (state.phase === 'hexagram-complete') return state;
  // An interrupted reveal finishes the existing line before starting another.
  const target = state.engine.completedLines.length +
    (state.phase === 'line-complete' ? 0 : 1);
  for (let steps = 0; steps < 100 && !cancelled(); steps++) {
    const from = state.phase;
    const engine = continueNeedsAdvance(from) ? await advance(state.engine) : state.engine;
    let to = phaseAfterContinue(from, engine);
    if (to === 'draw-line' && engine.result) to = 'hexagram-complete';
    state = snapshot(engine, to, assignForTransition(state.stalks, from, to, engine), state.visualSeed);
    await accept(state);
    if (to === 'hexagram-complete' || (to === 'draw-line' && engine.completedLines.length >= target)) return state;
  }
  if (!cancelled()) throw new Error('The casting did not complete a line. Please retry.');
  return state;
}

export function lineAction(state: CeremonyState): string {
  return state.phase === 'hexagram-complete' ? 'Begin again' :
    `Generate line ${Math.min(6, state.engine.completedLines.length + (state.phase === 'line-complete' ? 0 : 1))} of 6`;
}
