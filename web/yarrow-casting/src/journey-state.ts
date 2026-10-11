import { createStalks, snapshot } from './persist';
import type { CeremonyPhase, CeremonyState, EngineCastingState, StalkGroup } from './types';

// The current server projection owns engine data, including fields added since
// an older visual snapshot was saved. Only the choreography is restored from it.
export function restoreJourneyVisual(engine: EngineCastingState, saved: CeremonyState | null): CeremonyState {
  if (saved && saved.engine.stateId <= engine.stateId) {
    if (saved.engine.stateId === engine.stateId && saved.engine.castingId === engine.castingId) {
      return { ...saved, engine };
    }
    if (saved.engine.stateId < engine.stateId) return saved;
  }
  const phases: Record<string, CeremonyPhase> = {
    CastingNew: 'bound', LineStarted: 'working-set-49', HeapsDivided: 'divide',
    SingleStalkRemoved: 'take-one', RemaindersCounted: 'count-left',
    RoundComplete: 'operation-complete', LineComplete: 'line-complete',
    CastingComplete: 'hexagram-complete',
  };
  const stalks = createStalks(engine.seed);
  if (engine.event !== 'CastingNew') {
    const round = engine.roundSnapshot;
    let groups: [StalkGroup, number][] = [['working', engine.workingStalks]];
    if (round && engine.event === 'HeapsDivided') {
      groups = [['left', round.leftHeap ?? 0], ['right', round.rightHeap ?? 0]];
    } else if (round && engine.event === 'SingleStalkRemoved') {
      groups = [['left', round.leftAfterSingle ?? 0], ['right', round.rightAfterSingle ?? 0], ['finger', round.singleRemoved]];
    } else if (round && engine.event === 'RemaindersCounted') {
      // count-left has already peeled the left remainder; right follows next.
      groups = [['left-counted', (round.leftGroupsOfFour ?? 0) * 4],
        ['left-remainder', round.leftRemainder ?? 0],
        ['right', round.rightAfterSingle ?? 0], ['finger', round.singleRemoved]];
    }
    const memberships = groups.flatMap(([group, count]) => Array<StalkGroup>(count).fill(group));
    for (const stalk of stalks) stalk.group = stalk.id === 50 ? 'witness' : memberships[stalk.id - 1] ?? 'discarded';
  }
  return snapshot(engine, phases[engine.event] ?? 'bound', stalks, engine.seed);
}
