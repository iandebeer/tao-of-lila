import type { Pose } from "./types";

function easeInOutCubic(t: number): number {
  return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
}

function prefersReducedMotion(): boolean {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

export function lerp(from: number, to: number, t: number): number {
  return from + (to - from) * t;
}

export async function animatePoses(
  current: Map<number, Pose>,
  target: Map<number, Pose>,
  moveMs: number,
  settleMs: number,
  onFrame: (poses: Map<number, Pose>, t: number) => void,
): Promise<Map<number, Pose>> {
  if (prefersReducedMotion() || moveMs <= 0) {
    onFrame(clonePoses(target), 1);
    return clonePoses(target);
  }

  const start = clonePoses(current);
  const maxDelay = Math.max(0, ...Array.from(target.values()).map((pose) => pose.delay));
  const total = moveMs + maxDelay;

  await runTween(total, (progress) => {
    const poses = new Map<number, Pose>();
    for (const [id, to] of target) {
      const from = start.get(id) ?? to;
      const local = localProgress(progress, total, to.delay, moveMs);
      const t = easeInOutCubic(local);
      poses.set(id, {
        x: lerp(from.x, to.x, t),
        y: lerp(from.y, to.y, t),
        rotation: lerp(from.rotation, to.rotation, t),
        opacity: lerp(from.opacity, to.opacity, t),
        delay: 0,
      });
    }
    onFrame(poses, progress);
  });

  if (settleMs > 0) {
    await runTween(settleMs, (progress) => {
      const poses = new Map<number, Pose>();
      const damp = Math.sin(progress * Math.PI * 3) * (1 - progress) * 1.6;
      for (const [id, to] of target) {
        poses.set(id, {
          x: to.x,
          y: to.y + damp * 0.4,
          rotation: to.rotation + damp,
          opacity: to.opacity,
          delay: 0,
        });
      }
      onFrame(poses, 1);
    });
  }

  const finalPoses = clonePoses(target);
  onFrame(finalPoses, 1);
  return finalPoses;
}

export function clonePoses(poses: Map<number, Pose>): Map<number, Pose> {
  return new Map(Array.from(poses.entries()).map(([id, pose]) => [id, { ...pose }]));
}

function localProgress(globalProgress: number, total: number, delay: number, moveMs: number): number {
  const elapsed = globalProgress * total;
  if (elapsed <= delay) return 0;
  return Math.min(1, (elapsed - delay) / Math.max(1, moveMs));
}

function runTween(duration: number, draw: (progress: number) => void): Promise<void> {
  return new Promise((resolve) => {
    const start = performance.now();
    const tick = (now: number) => {
      const progress = Math.min(1, (now - start) / duration);
      draw(progress);
      if (progress < 1) requestAnimationFrame(tick);
      else resolve();
    };
    requestAnimationFrame(tick);
  });
}
