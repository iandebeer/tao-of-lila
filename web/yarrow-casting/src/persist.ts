import type { CeremonyPhase, CeremonyState, Stalk } from "./types";
import { STALK_COUNT, VARIANT_COUNT } from "./types";
import { between, mulberry32 } from "./rng";

const STORAGE_KEY = "tao-of-lila-yarrow-ceremony";

export function createStalks(visualSeed: number): Stalk[] {
  const random = mulberry32(visualSeed ^ 0x51a11e);
  const stalks: Stalk[] = [];
  for (let id = 1; id <= STALK_COUNT; id += 1) {
    stalks.push({
      id,
      variant: Math.floor(random() * VARIANT_COUNT),
      group: "bundle",
      noise: {
        dx: between(random, -3, 3),
        dy: between(random, -2.4, 2.4),
        rot: between(random, -2, 2),
        length: between(random, 0.92, 1.08),
        thick: between(random, 0.88, 1.12),
      },
    });
  }
  return stalks;
}

export function loadCeremony(): CeremonyState | null {
  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as CeremonyState;
    if (parsed.version !== 1 || !parsed.engine || !parsed.phase || !Array.isArray(parsed.stalks)) {
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

export function saveCeremony(state: CeremonyState): void {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

export function clearCeremony(): void {
  window.localStorage.removeItem(STORAGE_KEY);
}

export function snapshot(engine: CeremonyState["engine"], phase: CeremonyPhase, stalks: Stalk[], visualSeed: number): CeremonyState {
  return {
    version: 1,
    engine,
    phase,
    stalks,
    visualSeed,
  };
}
