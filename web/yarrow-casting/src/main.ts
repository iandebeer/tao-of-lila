import { generateLine, lineAction } from './line';
import { animatePoses } from "./animator";
import { caption, statusLine } from "./ceremony";
import { fetchInitialCasting, fetchNextCasting } from "./engine-client";
import { layoutStalks, leatherPose } from "./layout";
import { clearCeremony, createStalks, loadCeremony, saveCeremony, snapshot } from "./persist";
import { applyLeather, applyPoses, mountScene, renderHexagram } from "./render";
import type { CeremonyPhase, CeremonyState, Pose } from "./types";

const svg = document.querySelector("#scene") as SVGSVGElement;
const captionNode = document.querySelector("#caption") as HTMLParagraphElement;
const statusNode = document.querySelector("#status") as HTMLParagraphElement;
const continueButton = document.querySelector("#continue") as HTMLButtonElement;
const errorNode = document.querySelector("#error") as HTMLParagraphElement;

let ceremony: CeremonyState | null = null;
let scene: ReturnType<typeof mountScene> | null = null;
let poses = new Map<number, Pose>();
let animating = false;

boot().catch((error: unknown) => {
  showError(error instanceof Error ? error.message : "The ceremony could not begin.");
});

async function boot(): Promise<void> {
  const saved = loadCeremony();
  ceremony = saved ?? (await beginCasting());
  scene = mountScene(svg, ceremony.stalks);
  poses = layoutStalks(ceremony.stalks, ceremony.phase, ceremony.visualSeed);
  applyPoses(scene, poses);
  applyLeather(scene, ceremony.phase);
  renderHexagram(scene, ceremony.engine.completedLines, false);
  updateDock(ceremony);
  continueButton.addEventListener("click", () => {
    void onContinue();
  });
}

async function beginCasting(): Promise<CeremonyState> {
  const engine = await fetchInitialCasting();
  const stalks = createStalks(engine.seed);
  const state = snapshot(engine, "bound", stalks, engine.seed);
  saveCeremony(state);
  return state;
}

async function onContinue(): Promise<void> {
  if (!ceremony || !scene || animating) return;
  errorNode.textContent = "";

  if (ceremony.phase === "hexagram-complete") {
    clearCeremony();
    ceremony = await beginCasting();
    scene = mountScene(svg, ceremony.stalks);
    poses = layoutStalks(ceremony.stalks, ceremony.phase, ceremony.visualSeed);
    applyPoses(scene, poses);
    applyLeather(scene, ceremony.phase);
    renderHexagram(scene, [], false);
    updateDock(ceremony);
    return;
  }

  animating = true;
  continueButton.disabled = true;

  try {
    const from = ceremony.phase;
    captionNode.textContent = 'Generating a line…';
    const next = await generateLine(ceremony, fetchNextCasting, async state => {
      saveCeremony(state);
      ceremony = state;
    });
    const to = next.phase;
    const target = layoutStalks(next.stalks, to, next.visualSeed);
    const timing = { move: 650, settle: 100 };
    const leatherMotion =
      to === "untying" || to === "full-set-50" ? animateLeather(from, to, timing.move) : Promise.resolve();
    const stalkMotion = animatePoses(poses, target, timing.move, timing.settle, (frame) => {
      if (scene) applyPoses(scene, frame);
    });
    const [, nextPoses] = await Promise.all([leatherMotion, stalkMotion]);
    poses = nextPoses;

    ceremony = next;
    saveCeremony(ceremony);
    renderHexagram(scene, ceremony.engine.completedLines, false);
    applyLeather(scene, ceremony.phase);
    updateDock(ceremony);
  } catch (error: unknown) {
    showError(error instanceof Error ? error.message : "The casting engine could not advance.");
  } finally {
    animating = false;
    continueButton.disabled = false;
  }
}

function updateDock(state: CeremonyState): void {
  captionNode.textContent = caption(state.phase, state.engine);
  statusNode.textContent = statusLine(state.engine, state.phase);
  continueButton.textContent = lineAction(state);
}

function showError(message: string): void {
  errorNode.textContent = message;
}

async function animateLeather(from: CeremonyPhase, to: CeremonyPhase, duration: number): Promise<void> {
  if (!scene) return;
  const start = leatherPose(from);
  const end = leatherPose(to);
  const origin = performance.now();
  await new Promise<void>((resolve) => {
    const tick = (now: number) => {
      const t = Math.min(1, (now - origin) / duration);
      const loosen = start.loosen + (end.loosen - start.loosen) * t;
      const x = start.x + (end.x - start.x) * t;
      const y = start.y + (end.y - start.y) * t;
      const rotation = start.rotation + (end.rotation - start.rotation) * t;
      const opacity = start.opacity + (end.opacity - start.opacity) * t;
      scene?.leather.setAttribute("transform", `translate(${x} ${y}) rotate(${rotation}) scale(${1 + loosen * 0.28}, ${1 + loosen * 0.12})`);
      scene?.leather.setAttribute("opacity", String(opacity));
      if (t < 1) requestAnimationFrame(tick);
      else resolve();
    };
    requestAnimationFrame(tick);
  });
}
