// Reuses the isolated ceremony's renderer and choreography. The host owns IO.
import { assignForTransition } from './assign';
import { animatePoses } from './animator';
import { animationDuration, caption, continueLabel, continueNeedsAdvance, phaseAfterContinue, statusLine } from './ceremony';
import { layoutStalks, leatherPose } from './layout';
import { createStalks, snapshot } from './persist';
import { applyLeather, applyPoses, mountScene, renderHexagram } from './render';
import type { CeremonyState, EngineCastingState } from './types';

interface Host {
  svg: SVGSVGElement;
  engine: EngineCastingState;
  saved: CeremonyState | null;
  initial: EngineCastingState;
  advance: (previous: EngineCastingState) => Promise<EngineCastingState>;
  persist: (visual: CeremonyState) => Promise<void>;
  describe: (caption: string, status: string, action: string, complete: boolean) => void;
}
export function mountJourneyCeremony(host: Host) {
  let visual = host.saved ?? snapshot(host.initial, 'bound', createStalks(host.initial.seed), host.initial.seed);
  const scene = mountScene(host.svg, visual.stalks);
  let poses = layoutStalks(visual.stalks, visual.phase, visual.visualSeed);
  let disposed = false;
  let busy = false;
  const draw = () => {
    applyPoses(scene, poses); applyLeather(scene, visual.phase);
    renderHexagram(scene, visual.engine.completedLines, false);
    host.describe(caption(visual.phase, visual.engine), statusLine(visual.engine, visual.phase), continueLabel(visual.phase, visual.engine), visual.phase === 'hexagram-complete');
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
        const engine = continueNeedsAdvance(from) ? await host.advance(visual.engine) : visual.engine;
        const to = phaseAfterContinue(from, engine);
        const stalks = assignForTransition(visual.stalks, from, to, engine);
        const next = snapshot(engine, to, stalks, visual.visualSeed);
        // Save before animation: interruption resumes the accepted end pose.
        await host.persist(next);
        const target = layoutStalks(stalks, to, next.visualSeed);
        const timing = animationDuration(from, to);
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
