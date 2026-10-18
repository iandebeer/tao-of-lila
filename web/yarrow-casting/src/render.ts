import type { CeremonyPhase, LineResult, Pose, Stalk } from "./types";
import { STALK_COUNT } from "./types";
import { leatherPose } from "./layout";
import { variantMarkup, variants } from "./variants";

const SVG_NS = "http://www.w3.org/2000/svg";

export interface Scene {
  svg: SVGSVGElement;
  stalks: Map<number, SVGGElement>;
  leather: SVGGElement;
  hexagram: SVGGElement;
}

export function mountScene(host: SVGSVGElement, stalks: Stalk[]): Scene {
  host.innerHTML = `
    <defs>
      <radialGradient id="ground-glow" cx="50%" cy="70%" r="55%">
        <stop offset="0%" stop-color="#3a2a1c" stop-opacity="0.55"/>
        <stop offset="100%" stop-color="#15110d" stop-opacity="0"/>
      </radialGradient>
      ${variants.map(variantMarkup).join("")}
    </defs>
    <rect id="scene-ground" x="0" y="0" width="1200" height="620" fill="url(#ground-glow)"/>
    <ellipse id="bundle-shadow" cx="520" cy="470" rx="90" ry="22" fill="#000" opacity="0.22"/>
    <g id="leather">${leatherMarkup()}</g>
    <g id="stalks">
      ${stalks
        .map(
          (stalk) => {
            const alignedLength = 1 + (stalk.noise.length - 1) * 0.45;
            const restrainedThicknessVariation = 1 + (stalk.noise.thick - 1) * 0.65;
            return `
        <g id="stalk-${pad(stalk.id)}" class="stalk" data-id="${stalk.id}">
          <g transform="scale(${restrainedThicknessVariation.toFixed(3)}, ${alignedLength.toFixed(3)})">
            <use href="#stalk-variant-${pad(stalk.variant)}"></use>
          </g>
        </g>`;
          },
        )
        .join("")}
    </g>
    <g id="hexagram" transform="translate(1028, 86)"></g>
  `;

  const scene: Scene = {
    svg: host,
    stalks: new Map(),
    leather: host.querySelector("#leather") as SVGGElement,
    hexagram: host.querySelector("#hexagram") as SVGGElement,
  };

  for (let id = 1; id <= STALK_COUNT; id += 1) {
    const node = host.querySelector(`#stalk-${pad(id)}`) as SVGGElement;
    scene.stalks.set(id, node);
  }

  return scene;
}

export function applyPoses(scene: Scene, poses: Map<number, Pose>): void {
  const ordered = Array.from(poses.entries()).sort((a, b) => a[1].y - b[1].y || a[0] - b[0]);
  const root = scene.svg.querySelector("#stalks");
  for (const [id, pose] of ordered) {
    const node = scene.stalks.get(id);
    if (!node) continue;
    node.setAttribute("transform", `translate(${pose.x.toFixed(2)} ${pose.y.toFixed(2)}) rotate(${pose.rotation.toFixed(2)})`);
    node.setAttribute("opacity", pose.opacity.toFixed(3));
    root?.appendChild(node);
  }
}

export function applyLeather(scene: Scene, phase: CeremonyPhase, t = 1): void {
  const pose = leatherPose(phase);
  const loosen = 1 + pose.loosen * 0.28;
  scene.leather.setAttribute(
    "transform",
    `translate(${pose.x} ${pose.y}) rotate(${pose.rotation}) scale(${loosen}, ${1 + pose.loosen * 0.12})`,
  );
  scene.leather.setAttribute("opacity", String(pose.opacity * (phase === "untying" ? Math.max(0.35, t) : 1)));
}

export function renderHexagram(scene: Scene, lines: LineResult[], revealLatest: boolean): void {
  const slots = [1, 2, 3, 4, 5, 6];
  scene.hexagram.innerHTML = `
    <text x="42" y="-18" text-anchor="middle" fill="#c8b8a1" font-size="13" font-family="Georgia, serif">Hexagram</text>
    ${slots
      .map((lineNumber) => {
        const y = 300 - (lineNumber - 1) * 48;
        const line = lines.find((entry) => entry.lineNumber === lineNumber);
        const appear = line && (revealLatest ? lineNumber === lines[lines.length - 1]?.lineNumber : true);
        return `
          <g id="hex-line-${lineNumber}" transform="translate(0 ${y})" opacity="${line ? 1 : 0.18}">
            ${lineSlot(line?.lineValue ?? null, Boolean(appear))}
            <text x="96" y="6" fill="#c8b8a1" font-size="11" font-family="Georgia, serif">${line ? line.lineValue : lineNumber}</text>
          </g>`;
      })
      .join("")}
  `;
}

function lineSlot(value: number | null, drawn: boolean): string {
  const color = "#e2b66f";
  if (!drawn || value == null) {
    return `<rect x="0" y="-4" width="84" height="8" rx="1" fill="#2a2118"/>`;
  }
  if (value === 7 || value === 9) {
    const mark = value === 9 ? `<circle cx="42" cy="0" r="7" fill="none" stroke="${color}" stroke-width="1.6"/>` : "";
    return `<rect x="0" y="-4" width="84" height="8" rx="1.5" fill="${color}"/>${mark}`;
  }
  const mark =
    value === 6
      ? `<path d="M 36,-8 L 48,8 M 48,-8 L 36,8" stroke="${color}" stroke-width="1.8" fill="none"/>`
      : "";
  return `
    <rect x="0" y="-4" width="34" height="8" rx="1.5" fill="${color}"/>
    <rect x="50" y="-4" width="34" height="8" rx="1.5" fill="${color}"/>
    ${mark}
  `;
}

function leatherMarkup(): string {
  return `
    <path d="M -38,-6 C -30,-20 32,-22 40,-4 C 46,8 18,16 -2,14 C -24,12 -46,6 -38,-6" fill="none" stroke="#5c3317" stroke-width="5.2" stroke-linecap="round"/>
    <path d="M -34,-1 C -24,-12 26,-13 33,1 C 28,9 8,12 -4,11 C -20,9 -38,5 -34,-1" fill="none" stroke="#8a5a32" stroke-width="2.1" stroke-linecap="round" opacity="0.7"/>
    <path d="M 36,-2 C 52,4 58,18 49,28" fill="none" stroke="#4a2814" stroke-width="3.4" stroke-linecap="round"/>
  `;
}

function pad(value: number): string {
  return String(value).padStart(2, "0");
}

export { SVG_NS };
