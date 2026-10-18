export function mulberry32(seed: number): () => number {
  let t = seed >>> 0;
  return () => {
    t += 0x6d2b79f5;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r ^= r + Math.imul(r ^ (r >>> 7), 61 | r);
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

export function seededShuffle<T>(items: T[], seed: number): T[] {
  const copy = items.slice();
  const random = mulberry32(seed);
  for (let index = copy.length - 1; index > 0; index -= 1) {
    const other = Math.floor(random() * (index + 1));
    const temp = copy[index];
    copy[index] = copy[other];
    copy[other] = temp;
  }
  return copy;
}

export function between(random: () => number, min: number, max: number): number {
  return min + (max - min) * random();
}
