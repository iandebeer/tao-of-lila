import type { CeremonyPhase, Pose, Stalk, StalkGroup } from "./types";
import { mulberry32 } from "./rng";

interface Region {
  x: number;
  y: number;
  spreadX: number;
  spreadY: number;
  rot: number;
}

const regions: Record<string, Region> = {
  bundle: { x: 520, y: 455, spreadX: 20, spreadY: 7, rot: 3 },
  bundleRelaxed: { x: 522, y: 458, spreadX: 34, spreadY: 11, rot: 5 },
  working: { x: 520, y: 450, spreadX: 48, spreadY: 15, rot: 6 },
  witness: { x: 118, y: 400, spreadX: 2, spreadY: 2, rot: 3 },
  left: { x: 260, y: 438, spreadX: 68, spreadY: 22, rot: 8 },
  right: { x: 780, y: 438, spreadX: 68, spreadY: 22, rot: 8 },
  finger: { x: 528, y: 215, spreadX: 1, spreadY: 1, rot: 7 },
  "left-remainder": { x: 270, y: 575, spreadX: 12, spreadY: 5, rot: 4 },
  "right-remainder": { x: 770, y: 575, spreadX: 12, spreadY: 5, rot: 4 },
  remainder: { x: 520, y: 585, spreadX: 32, spreadY: 8, rot: 7 },
  discarded: { x: 128, y: 590, spreadX: 44, spreadY: 12, rot: 9 },
  "discarded-1": { x: 110, y: 590, spreadX: 28, spreadY: 8, rot: 6 },
  "discarded-2": { x: 230, y: 590, spreadX: 28, spreadY: 8, rot: 6 },
  "discarded-3": { x: 350, y: 590, spreadX: 28, spreadY: 8, rot: 6 },
};

export function layoutStalks(stalks: Stalk[], phase: CeremonyPhase, visualSeed: number): Map<number, Pose> {
  const poses = new Map<number, Pose>();
  const byGroup = new Map<StalkGroup, Stalk[]>();
  for (const stalk of stalks) {
    const list = byGroup.get(stalk.group) ?? [];
    list.push(stalk);
    byGroup.set(stalk.group, list);
  }

  for (const [group, members] of byGroup) {
    if (group === "left-counted" || group === "right-counted") {
      layoutCounted(members, group, phase, visualSeed, poses);
      continue;
    }
    if (group === "discarded-1" || group === "discarded-2" || group === "discarded-3") {
      layoutDiscardedBundle(members, regions[group], visualSeed + groupKey(group), poses);
      continue;
    }
    const region = remainderRegion(group, byGroup) ?? regionFor(group, phase);
    layoutPile(members, region, visualSeed + groupKey(group), poses, staggerFor(group, phase));
  }

  return poses;
}

function layoutDiscardedBundle(members: Stalk[], region: Region, seed: number, poses: Map<number, Pose>): void {
  const random = mulberry32(seed);
  members.forEach((stalk, index) => {
    const offset = index - (members.length - 1) / 2;
    poses.set(stalk.id, {
      x: region.x + offset * 5.5 + stalk.noise.dx * 0.18,
      y: region.y + (random() - 0.5) * 4,
      rotation: offset * 0.65 + stalk.noise.rot * 0.3,
      opacity: 1,
      delay: index * 20,
    });
  });
}

function regionFor(group: StalkGroup, phase: CeremonyPhase): Region {
  if (group === "bundle") {
    return phase === "bound" ? regions.bundle : regions.bundleRelaxed;
  }
  if (group === "working" && (phase === "line-complete" || phase === "draw-line")) {
    return { x: 520, y: 430, spreadX: 42, spreadY: 12, rot: 5 };
  }
  if (group === "finger" && (phase === "count-left" || phase === "count-right")) {
    return { x: 620, y: 575, spreadX: 1, spreadY: 1, rot: 3 };
  }
  return regions[group] ?? regions.working;
}

function remainderRegion(group: StalkGroup, byGroup: Map<StalkGroup, Stalk[]>): Region | null {
  if (group !== "left-remainder" && group !== "right-remainder") return null;
  const countedGroup = group === "left-remainder" ? "left-counted" : "right-counted";
  const countedBundles = Math.ceil((byGroup.get(countedGroup)?.length ?? 0) / 4);
  const baseX = group === "left-remainder" ? 80 : 650;
  return { x: baseX + countedBundles * 52 + 10, y: 575, spreadX: 12, spreadY: 5, rot: 4 };
}

function layoutPile(members: Stalk[], region: Region, seed: number, poses: Map<number, Pose>, stagger: number): void {
  const random = mulberry32(seed);
  members.forEach((stalk, index) => {
    const x = region.x + (random() - 0.5) * region.spreadX + stalk.noise.dx;
    const y = region.y + (random() - 0.5) * region.spreadY + stalk.noise.dy;
    const rotation = (random() - 0.5) * region.rot + stalk.noise.rot * 0.45;
    poses.set(stalk.id, {
      x,
      y,
      rotation,
      opacity: 1,
      delay: index * stagger,
    });
  });
}

function layoutCounted(
  members: Stalk[],
  group: "left-counted" | "right-counted",
  phase: CeremonyPhase,
  visualSeed: number,
  poses: Map<number, Pose>,
): void {
  const baseX = group === "left-counted" ? 80 : 650;
  const baseY = 575;
  const stagger = phase === "count-left" || phase === "count-right" ? 90 : 0;
  for (let index = 0; index < members.length; index += 1) {
    const stalk = members[index];
    const bundle = Math.floor(index / 4);
    const within = index % 4;
    const random = mulberry32(visualSeed + stalk.id * 17);
    poses.set(stalk.id, {
      x: baseX + bundle * 52 + (within - 1.5) * 5.5 + stalk.noise.dx * 0.25,
      y: baseY + (random() - 0.5) * 5 + stalk.noise.dy * 0.25,
      rotation: (within - 1.5) * 2.2 + stalk.noise.rot * 0.4,
      opacity: 1,
      delay: bundle * stagger,
    });
  }
}

function staggerFor(group: StalkGroup, phase: CeremonyPhase): number {
  if (phase === "divide" && (group === "left" || group === "right")) return 18;
  if (phase === "remove-one" && group === "witness") return 0;
  if (phase === "collect" && group === "remainder") return 40;
  return 8;
}

function groupKey(group: StalkGroup): number {
  return Array.from(group).reduce((sum, char) => sum + char.charCodeAt(0), 0);
}

export function leatherPose(phase: CeremonyPhase): { loosen: number; x: number; y: number; rotation: number; opacity: number } {
  if (phase === "bound") return { loosen: 0, x: 520, y: 352, rotation: -4, opacity: 1 };
  if (phase === "untying") return { loosen: 1, x: 528, y: 358, rotation: 8, opacity: 1 };
  return { loosen: 1.4, x: 610, y: 620, rotation: 78, opacity: 0 };
}
