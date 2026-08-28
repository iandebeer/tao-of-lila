export interface StalkVariant {
  id: number;
  length: number;
  stroke: number;
  shaft: string;
  curve: number;
  nodes: Array<{ t: number; color: string; rx: number; ry: number }>;
  stripped?: { t0: number; t1: number; color: string; stroke: number };
  tip: string;
}

export const variants: StalkVariant[] = [
  { id: 0, length: 206, stroke: 3.4, shaft: "#8f9a6c", curve: -11, nodes: [{ t: 0.22, color: "#7a4e2a", rx: 2.3, ry: 3.1 }, { t: 0.58, color: "#5c3a21", rx: 2.1, ry: 2.8 }], stripped: { t0: 0.7, t1: 0.92, color: "#d9cbb0", stroke: 2.6 }, tip: "#4a3b28" },
  { id: 1, length: 188, stroke: 3.8, shaft: "#c4a56a", curve: 8, nodes: [{ t: 0.18, color: "#8b5a2b", rx: 2.6, ry: 3.4 }, { t: 0.47, color: "#6b4423", rx: 2.2, ry: 2.7 }], stripped: { t0: 0.62, t1: 0.86, color: "#e4d6b8", stroke: 2.8 }, tip: "#5a4330" },
  { id: 2, length: 198, stroke: 3.1, shaft: "#9aa578", curve: -4, nodes: [{ t: 0.16, color: "#6b4a2c", rx: 1.8, ry: 2.4 }, { t: 0.38, color: "#8a5b32", rx: 2.0, ry: 2.6 }, { t: 0.66, color: "#5c3a21", rx: 1.7, ry: 2.3 }], tip: "#3f3326" },
  { id: 3, length: 212, stroke: 2.8, shaft: "#a3ab7a", curve: 14, nodes: [{ t: 0.3, color: "#7b4f28", rx: 2.0, ry: 2.8 }], stripped: { t0: 0.48, t1: 0.7, color: "#d6c7a6", stroke: 2.3 }, tip: "#6a5138" },
  { id: 4, length: 176, stroke: 4.2, shaft: "#b8956a", curve: -16, nodes: [{ t: 0.24, color: "#5a371c", rx: 2.8, ry: 3.6 }, { t: 0.52, color: "#8b5a2b", rx: 2.4, ry: 3.1 }], tip: "#4c3726" },
  { id: 5, length: 202, stroke: 2.6, shaft: "#7f8d62", curve: 6, nodes: [{ t: 0.44, color: "#4a2f1a", rx: 1.9, ry: 2.5 }], stripped: { t0: 0.12, t1: 0.28, color: "#cfc0a0", stroke: 2.2 }, tip: "#556044" },
  { id: 6, length: 190, stroke: 3.5, shaft: "#cbb07a", curve: -7, nodes: [{ t: 0.2, color: "#6b4423", rx: 2.2, ry: 3.0 }, { t: 0.71, color: "#8a6234", rx: 2.0, ry: 2.6 }], stripped: { t0: 0.78, t1: 0.96, color: "#eee4cc", stroke: 2.7 }, tip: "#5c4630" },
  { id: 7, length: 208, stroke: 3.0, shaft: "#93a07a", curve: 11, nodes: [{ t: 0.36, color: "#7a4e2a", rx: 2.1, ry: 2.7 }], stripped: { t0: 0.55, t1: 0.74, color: "#d8cbb0", stroke: 2.4 }, tip: "#3d3428" },
  { id: 8, length: 184, stroke: 3.6, shaft: "#d1ae72", curve: -9, nodes: [{ t: 0.14, color: "#8b5a2b", rx: 2.5, ry: 3.2 }, { t: 0.28, color: "#6b4423", rx: 2.2, ry: 2.8 }, { t: 0.41, color: "#5c3a21", rx: 1.8, ry: 2.4 }], tip: "#4a3828" },
  { id: 9, length: 200, stroke: 3.2, shaft: "#b8c090", curve: 3, nodes: [{ t: 0.5, color: "#6e4a28", rx: 2.3, ry: 3.0 }], stripped: { t0: 0.22, t1: 0.46, color: "#e8dcc4", stroke: 2.6 }, tip: "#5a4a34" },
  { id: 10, length: 194, stroke: 3.7, shaft: "#6f7d55", curve: 13, nodes: [{ t: 0.27, color: "#4a2f1a", rx: 2.4, ry: 3.1 }, { t: 0.63, color: "#7a4e2a", rx: 2.0, ry: 2.6 }], tip: "#2f2a20" },
  { id: 11, length: 186, stroke: 3.3, shaft: "#9aa578", curve: -13, nodes: [{ t: 0.33, color: "#8b5a2b", rx: 2.2, ry: 2.9 }], stripped: { t0: 0.68, t1: 0.9, color: "#d4c4a8", stroke: 2.5 }, tip: "#6b5136" },
  { id: 12, length: 210, stroke: 2.9, shaft: "#a38b5c", curve: 5, nodes: [{ t: 0.19, color: "#5c3a21", rx: 1.7, ry: 2.2 }, { t: 0.4, color: "#7a4e2a", rx: 1.9, ry: 2.4 }, { t: 0.61, color: "#6b4423", rx: 1.8, ry: 2.3 }, { t: 0.79, color: "#8a6234", rx: 1.6, ry: 2.1 }], tip: "#433424" },
  { id: 13, length: 216, stroke: 2.5, shaft: "#8a9a6a", curve: -6, nodes: [{ t: 0.48, color: "#6b4423", rx: 1.8, ry: 2.4 }], stripped: { t0: 0.08, t1: 0.22, color: "#ddd0b4", stroke: 2.0 }, tip: "#4f5a3c" },
  { id: 14, length: 172, stroke: 4.4, shaft: "#c4a36a", curve: 9, nodes: [{ t: 0.26, color: "#7a3f1e", rx: 2.9, ry: 3.7 }, { t: 0.57, color: "#5c3a21", rx: 2.6, ry: 3.3 }], tip: "#5a4030" },
];

function quadPoint(curve: number, length: number, t: number): { x: number; y: number } {
  const p0 = { x: 0, y: 0 };
  const p1 = { x: curve, y: -length * 0.48 };
  const p2 = { x: curve * 0.32, y: -length };
  const u = 1 - t;
  return {
    x: u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
    y: u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y,
  };
}

export function variantMarkup(variant: StalkVariant): string {
  const thicknessScale = 1.1;
  const shaft = `M 0,0 Q ${variant.curve},${(-variant.length * 0.48).toFixed(1)} ${(variant.curve * 0.32).toFixed(1)},${-variant.length}`;
  const nodes = variant.nodes
    .map((node) => {
      const point = quadPoint(variant.curve, variant.length, node.t);
      return `<ellipse cx="${point.x.toFixed(1)}" cy="${point.y.toFixed(1)}" rx="${node.rx}" ry="${node.ry}" fill="${node.color}" opacity="0.92"/>`;
    })
    .join("");
  let stripped = "";
  if (variant.stripped) {
    const a = quadPoint(variant.curve, variant.length, variant.stripped.t0);
    const b = quadPoint(variant.curve, variant.length, (variant.stripped.t0 + variant.stripped.t1) / 2);
    const c = quadPoint(variant.curve, variant.length, variant.stripped.t1);
    stripped = `<path d="M ${a.x.toFixed(1)},${a.y.toFixed(1)} Q ${b.x.toFixed(1)},${b.y.toFixed(1)} ${c.x.toFixed(1)},${c.y.toFixed(1)}" fill="none" stroke="${variant.stripped.color}" stroke-width="${(variant.stripped.stroke * thicknessScale).toFixed(2)}" stroke-linecap="round"/>`;
  }
  const tip = quadPoint(variant.curve, variant.length, 0.97);
  return `
    <g id="stalk-variant-${String(variant.id).padStart(2, "0")}">
      <path d="${shaft}" fill="none" stroke="${variant.shaft}" stroke-width="${(variant.stroke * thicknessScale).toFixed(2)}" stroke-linecap="round"/>
      ${stripped}
      ${nodes}
      <circle cx="${tip.x.toFixed(1)}" cy="${tip.y.toFixed(1)}" r="${Math.max(1.1, variant.stroke * 0.38 * thicknessScale).toFixed(2)}" fill="${variant.tip}"/>
    </g>
  `;
}
