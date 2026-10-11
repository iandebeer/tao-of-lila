import { generateLine, lineAction } from './line';
// Reuses the isolated ceremony's renderer and choreography. The host owns IO.
import { animatePoses } from './animator';
import { caption, statusLine } from './ceremony';
import { layoutStalks, leatherPose } from './layout';
import { restoreJourneyVisual } from './journey-state';
import { applyLeather, applyPoses, mountScene, renderHexagram } from './render';
import type { CeremonyState, EngineCastingState } from './types';

interface Host {
  svg: SVGSVGElement;
  engine: EngineCastingState;
  saved: CeremonyState | null;
  advance: (previous: EngineCastingState) => Promise<EngineCastingState>;
  persist: (visual: CeremonyState) => Promise<void>;
  describe: (caption: string, status: string, action: string, complete: boolean) => void;
}
export function mountJourneyCeremony(host: Host) {
  let engine = host.engine;
  let visual = restoreJourneyVisual(engine, host.saved);
  const scene = mountScene(host.svg, visual.stalks);
  let poses = layoutStalks(visual.stalks, visual.phase, visual.visualSeed);
  let disposed = false;
  let busy = false;
  const draw = () => {
    applyPoses(scene, poses); applyLeather(scene, visual.phase);
    renderHexagram(scene, visual.engine.completedLines, false);
    host.describe(caption(visual.phase, visual.engine), statusLine(visual.engine, visual.phase), lineAction(visual), visual.phase === 'hexagram-complete');
  };
  draw();
  return {
    dispose() { disposed = true; },
    async next() {
      if (busy || disposed) return;
      busy = true;
      try {
        if (visual.phase === 'hexagram-complete') return;
        const from = visual.phase;
        host.describe('Generating a line…', statusLine(visual.engine, visual.phase), 'Generating…', false);
        const next = await generateLine(visual, async previous => {
          engine = await host.advance(previous);
          return engine;
        }, async state => {
          // A saved visual may lag an engine step accepted before interruption.
          // Catch up its choreography before submitting another snapshot.
          if (state.engine.stateId < engine.stateId) return;
          await host.persist(state);
          visual = state;
        }, () => disposed);
        if (disposed) return;
        const to = next.phase;
        const target = layoutStalks(next.stalks, to, next.visualSeed);
        const timing = { move: 650, settle: 100 };
        const start = leatherPose(from), end = leatherPose(to);
        poses = await animatePoses(poses, target, timing.move, timing.settle, (frame, t) => {
          if (disposed) return;
          applyPoses(scene, frame);
          const mix = (a: number, b: number) => a + (b - a) * t;
          const loosen = mix(start.loosen, end.loosen);
          scene.leather.setAttribute('transform', `translate(${mix(start.x,end.x)} ${mix(start.y,end.y)}) rotate(${mix(start.rotation,end.rotation)}) scale(${1+loosen*.28}, ${1+loosen*.12})`);
          scene.leather.setAttribute('opacity', String(mix(start.opacity,end.opacity)));
        });
        visual = next;
        if (!disposed) draw();
      } finally { busy = false; }
    }
  };
}
