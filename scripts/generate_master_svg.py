#!/usr/bin/env python3
"""Generate the initial Master SVG board for The Tao of Lila."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import html
import json
import math


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
SVG_PATH = ASSETS / "master.svg"
GEOMETRY_PATH = ASSETS / "geometry.json"
BOARD_PATH = ASSETS / "board.json"
SQUARES_PATH = ASSETS / "squares.json"
SNAKES_PATH = ASSETS / "snakes.json"
BAGUA_PATH = ASSETS / "bagua.json"

VIEWBOX_SIZE = 4000
CANVAS_CENTER = 2000
SQUARE_COUNT = 72
SQUARE_SIZE = 160
SQUARE_GAP = 8
BOARD_GRID_ORIGIN_X = 1280
BOARD_GRID_ORIGIN_Y = 1540
TRIGRAM_WIDTH = 180
TRIGRAM_HEIGHT = 98

PALETTE = {
    "parchment": "#f4ead4",
    "parchment_dark": "#ead8b5",
    "umber": "#4b2f1b",
    "charcoal": "#25211c",
    "gold": "#b79a55",
    "ink_light": "#6c5a42",
}


@dataclass(frozen=True)
class Trigram:
    id: str
    chinese: str
    pinyin: str
    english: str
    lines: tuple[int, int, int]


TRIGRAMS: dict[str, Trigram] = {
    "qian": Trigram("qian", "乾", "Qian", "Heaven", (1, 1, 1)),
    "dui": Trigram("dui", "兌", "Dui", "Lake", (1, 1, 0)),
    "li": Trigram("li", "離", "Li", "Fire", (1, 0, 1)),
    "zhen": Trigram("zhen", "震", "Zhen", "Thunder", (1, 0, 0)),
    "xun": Trigram("xun", "巽", "Xun", "Wind/Wood", (0, 1, 1)),
    "kan": Trigram("kan", "坎", "Kan", "Water", (0, 1, 0)),
    "gen": Trigram("gen", "艮", "Gen", "Mountain", (0, 0, 1)),
    "kun": Trigram("kun", "坤", "Kun", "Earth", (0, 0, 0)),
}

EARLIER_HEAVEN = [
    ("south", "qian", 90),
    ("southeast", "dui", 45),
    ("east", "li", 0),
    ("northeast", "zhen", -45),
    ("north", "kun", -90),
    ("northwest", "gen", -135),
    ("west", "kan", 180),
    ("southwest", "xun", 135),
]

LATER_HEAVEN = [
    ("north", "kan", -90),
    ("northeast", "gen", -45),
    ("east", "zhen", 0),
    ("southeast", "xun", 45),
    ("south", "li", 90),
    ("southwest", "kun", 135),
    ("west", "dui", 180),
    ("northwest", "qian", -135),
]


def esc(value: object) -> str:
    return html.escape(str(value), quote=True)


def tag(name: str, attrs: dict[str, object] | None = None, content: str = "") -> str:
    attrs = attrs or {}
    rendered_attrs = " ".join(f'{key}="{esc(value)}"' for key, value in attrs.items())
    if rendered_attrs:
        return f"<{name} {rendered_attrs}>{content}</{name}>"
    return f"<{name}>{content}</{name}>"


def empty_tag(name: str, attrs: dict[str, object]) -> str:
    rendered_attrs = " ".join(f'{key}="{esc(value)}"' for key, value in attrs.items())
    return f"<{name} {rendered_attrs}/>"


def trigram_use_attrs(use_id: str, trigram_id: str, x: float, y: float) -> dict[str, object]:
    return {
        "id": use_id,
        "href": f"#trigram_{trigram_id}",
        "xlink:href": f"#trigram_{trigram_id}",
        "x": round(x, 2),
        "y": round(y, 2),
        "width": TRIGRAM_WIDTH,
        "height": TRIGRAM_HEIGHT,
        "class": "trigram-use",
    }


def point_on_circle(cx: float, cy: float, radius: float, angle_degrees: float) -> tuple[float, float]:
    radians = math.radians(angle_degrees)
    return (cx + math.cos(radians) * radius, cy + math.sin(radians) * radius)


def spiral_cells(count: int) -> list[tuple[int, int, str]]:
    """Return grid cells from bottom-left inward, moving clockwise."""
    min_col, max_col = 0, 8
    min_row, max_row = 0, 8
    col, row = min_col, max_row
    direction = "E"
    cells: list[tuple[int, int, str]] = []

    while len(cells) < count:
        cells.append((col, row, direction))
        if direction == "E":
            if col < max_col:
                col += 1
            else:
                direction = "N"
                max_row -= 1
                row -= 1
        elif direction == "N":
            if row > min_row:
                row -= 1
            else:
                direction = "W"
                max_col -= 1
                col -= 1
        elif direction == "W":
            if col > min_col:
                col -= 1
            else:
                direction = "S"
                min_row += 1
                row += 1
        elif direction == "S":
            if row < max_row:
                row += 1
            else:
                direction = "E"
                min_col += 1
                col += 1

    return cells


def square_records() -> list[dict[str, object]]:
    records: list[dict[str, object]] = []
    for number, (col, row, direction) in enumerate(spiral_cells(SQUARE_COUNT), start=1):
        x = BOARD_GRID_ORIGIN_X + col * SQUARE_SIZE
        y = BOARD_GRID_ORIGIN_Y + row * SQUARE_SIZE
        square_id = f"square_{number:02d}"
        records.append(
            {
                "id": square_id,
                "number": number,
                "dataNumber": f"{number:02d}",
                "name": "",
                "category": "",
                "snake": "",
                "ladder": "",
                "hexagram": "",
                "grid": {"col": col, "row": row},
                "direction": direction,
                "rect": {
                    "x": x + SQUARE_GAP / 2,
                    "y": y + SQUARE_GAP / 2,
                    "width": SQUARE_SIZE - SQUARE_GAP,
                    "height": SQUARE_SIZE - SQUARE_GAP,
                },
                "center": {
                    "x": x + SQUARE_SIZE / 2,
                    "y": y + SQUARE_SIZE / 2,
                },
                "svg": {
                    "groupId": square_id,
                    "rectId": f"{square_id}_rect",
                    "textId": f"{square_id}_number",
                },
            }
        )
    return records


def trigram_symbol(trigram: Trigram) -> str:
    line_width = 180
    broken_gap = 36
    line_height = 14
    spacing = 42
    x = 0
    y_top = 0
    parts = [f'<g id="trigram_{trigram.id}_geometry">']
    # SVG displays top-to-bottom, while metadata stores bottom-to-top.
    for visual_index, line in enumerate(reversed(trigram.lines)):
        y = y_top + visual_index * spacing
        if line:
            parts.append(
                empty_tag(
                    "rect",
                    {
                        "id": f"trigram_{trigram.id}_line_{3 - visual_index}",
                        "x": x,
                        "y": y,
                        "width": line_width,
                        "height": line_height,
                        "rx": 4,
                    },
                )
            )
        else:
            segment = (line_width - broken_gap) / 2
            line_number = 3 - visual_index
            parts.append(
                empty_tag(
                    "rect",
                    {
                        "id": f"trigram_{trigram.id}_line_{line_number}_left",
                        "x": x,
                        "y": y,
                        "width": segment,
                        "height": line_height,
                        "rx": 4,
                    },
                )
            )
            parts.append(
                empty_tag(
                    "rect",
                    {
                        "id": f"trigram_{trigram.id}_line_{line_number}_right",
                        "x": x + segment + broken_gap,
                        "y": y,
                        "width": segment,
                        "height": line_height,
                        "rx": 4,
                    },
                )
            )
    parts.append("</g>")
    return tag(
        "symbol",
        {"id": f"trigram_{trigram.id}", "viewBox": "0 0 180 98"},
        "\n".join(parts),
    )


def defs() -> str:
    symbols = "\n".join(trigram_symbol(trigram) for trigram in TRIGRAMS.values())
    styles = """
      :root {
        --parchment: #f4ead4;
        --parchment-dark: #ead8b5;
        --umber: #4b2f1b;
        --charcoal: #25211c;
        --muted-gold: #b79a55;
        --ink-light: #6c5a42;
      }
      text {
        font-family: "Noto Serif", "Noto Serif SC", serif;
        fill: var(--charcoal);
      }
      .fine-stroke {
        fill: none;
        stroke: var(--umber);
        stroke-width: 6;
        vector-effect: non-scaling-stroke;
      }
      .hairline {
        fill: none;
        stroke: var(--ink-light);
        stroke-width: 2;
        vector-effect: non-scaling-stroke;
      }
      .square-rect {
        fill: rgba(244, 234, 212, 0.72);
        stroke: var(--umber);
        stroke-width: 3;
      }
      .trigram-use {
        fill: var(--charcoal);
      }
    """
    return tag(
        "defs",
        {"id": "defs"},
        tag("style", {"id": "style_master_svg_1"}, styles) + "\n" + symbols,
    )


def background_layer() -> str:
    return tag(
        "g",
        {"id": "background"},
        empty_tag(
            "rect",
            {
                "id": "background_parchment",
                "x": 0,
                "y": 0,
                "width": VIEWBOX_SIZE,
                "height": VIEWBOX_SIZE,
                "fill": PALETTE["parchment"],
            },
        ),
    )


def border_layer() -> str:
    parts = [
        empty_tag(
            "rect",
            {
                "id": "border_outer",
                "x": 140,
                "y": 140,
                "width": 3720,
                "height": 3720,
                "rx": 18,
                "class": "fine-stroke",
            },
        ),
        empty_tag(
            "rect",
            {
                "id": "border_inner",
                "x": 220,
                "y": 220,
                "width": 3560,
                "height": 3560,
                "rx": 10,
                "class": "hairline",
            },
        ),
    ]
    ornament_points = [(300, 300), (3700, 300), (3700, 3700), (300, 3700)]
    for index, (x, y) in enumerate(ornament_points, start=1):
        parts.append(
            empty_tag(
                "circle",
                {
                    "id": f"border_corner_mark_{index:02d}",
                    "cx": x,
                    "cy": y,
                    "r": 32,
                    "fill": "none",
                    "stroke": PALETTE["gold"],
                    "stroke-width": 4,
                },
            )
        )
    return tag("g", {"id": "border"}, "\n".join(parts))


def guides_layer() -> str:
    parts = [
        empty_tag("line", {"id": "guide_vertical_center", "x1": 2000, "y1": 220, "x2": 2000, "y2": 3780, "class": "hairline", "opacity": 0.16}),
        empty_tag("line", {"id": "guide_horizontal_center", "x1": 220, "y1": 2000, "x2": 3780, "y2": 2000, "class": "hairline", "opacity": 0.16}),
    ]
    return tag("g", {"id": "guides"}, "\n".join(parts))


def taijitu_layer() -> str:
    cx, cy, r = 2000, 560, 160
    parts = [
        empty_tag("circle", {"id": "taijitu_construction_ring_outer", "cx": cx, "cy": cy, "r": r + 66, "class": "hairline", "opacity": 0.22}),
        empty_tag("circle", {"id": "taijitu_construction_ring_inner", "cx": cx, "cy": cy, "r": r + 28, "class": "hairline", "opacity": 0.18}),
        empty_tag("circle", {"id": "taijitu_disc", "cx": cx, "cy": cy, "r": r, "fill": PALETTE["parchment_dark"], "stroke": PALETTE["umber"], "stroke-width": 5}),
        tag("clipPath", {"id": "taijitu_clip"}, empty_tag("circle", {"id": "taijitu_clip_circle", "cx": cx, "cy": cy, "r": r})),
        tag(
            "g",
            {"id": "taijitu_fields", "clip-path": "url(#taijitu_clip)"},
            "\n".join(
                [
                    empty_tag("rect", {"id": "taijitu_dark_half", "x": cx, "y": cy - r, "width": r, "height": r * 2, "fill": PALETTE["charcoal"]}),
                    empty_tag("circle", {"id": "taijitu_light_lobe", "cx": cx, "cy": cy - r / 2, "r": r / 2, "fill": PALETTE["parchment_dark"]}),
                    empty_tag("circle", {"id": "taijitu_dark_lobe", "cx": cx, "cy": cy + r / 2, "r": r / 2, "fill": PALETTE["charcoal"]}),
                ]
            ),
        ),
        empty_tag("circle", {"id": "taijitu_yang_seed", "cx": cx, "cy": cy - r / 2, "r": 24, "fill": PALETTE["charcoal"]}),
        empty_tag("circle", {"id": "taijitu_yin_seed", "cx": cx, "cy": cy + r / 2, "r": 24, "fill": PALETTE["parchment_dark"]}),
        empty_tag("circle", {"id": "taijitu_boundary", "cx": cx, "cy": cy, "r": r, "fill": "none", "stroke": PALETTE["umber"], "stroke-width": 5}),
    ]
    return tag("g", {"id": "taijitu"}, "\n".join(parts))


def bagua_ring_layer() -> str:
    cx, cy, radius = 2000, 560, 300
    parts = []
    for position, trigram_id, angle in EARLIER_HEAVEN:
        x, y = point_on_circle(cx, cy, radius, angle)
        trigram = TRIGRAMS[trigram_id]
        parts.append(
            tag(
                "g",
                {"id": f"earlier_heaven_{position}_{trigram_id}", "data-trigram": trigram_id, "data-position": position},
                "\n".join(
                    [
                        empty_tag("use", trigram_use_attrs(f"earlier_heaven_{trigram_id}_use", trigram_id, x - TRIGRAM_WIDTH / 2, y - TRIGRAM_HEIGHT / 2)),
                        tag("text", {"id": f"earlier_heaven_{trigram_id}_label_chinese", "x": round(x, 2), "y": round(y + 78, 2), "font-size": 30, "text-anchor": "middle"}, trigram.chinese),
                        tag("text", {"id": f"earlier_heaven_{trigram_id}_label_pinyin", "x": round(x, 2), "y": round(y + 110, 2), "font-size": 22, "text-anchor": "middle"}, trigram.pinyin),
                        tag("text", {"id": f"earlier_heaven_{trigram_id}_label_english", "x": round(x, 2), "y": round(y + 138, 2), "font-size": 18, "text-anchor": "middle"}, trigram.english),
                    ]
                ),
            )
        )
    return tag("g", {"id": "earlier_heaven_ring"}, "\n".join(parts))


def arrow_anchor_layer(group_id: str, x: int) -> str:
    return tag(
        "g",
        {"id": group_id},
        empty_tag(
            "rect",
            {
                "id": f"{group_id}_anchor_bounds",
                "x": x,
                "y": 360,
                "width": 520,
                "height": 420,
                "fill": "none",
                "opacity": 0,
                "pointer-events": "none",
            },
        ),
    )


def spiral_board_layer() -> str:
    parts = []
    for record in square_records():
        square_id = str(record["id"])
        rect_data = record["rect"]
        center = record["center"]
        grid = record["grid"]
        rect = empty_tag(
            "rect",
            {
                "id": f"{square_id}_rect",
                "x": rect_data["x"],
                "y": rect_data["y"],
                "width": rect_data["width"],
                "height": rect_data["height"],
                "rx": 8,
                "class": "square-rect",
            },
        )
        label = tag(
            "text",
            {
                "id": f"{square_id}_number",
                "x": center["x"],
                "y": center["y"] + 14,
                "font-size": 42,
                "text-anchor": "middle",
            },
            f"{record['number']}",
        )
        parts.append(
            tag(
                "g",
                {
                    "id": square_id,
                    "data-number": record["dataNumber"],
                    "data-name": record["name"],
                    "data-category": record["category"],
                    "data-snake": record["snake"],
                    "data-ladder": record["ladder"],
                    "data-hexagram": record["hexagram"],
                    "data-grid-col": grid["col"],
                    "data-grid-row": grid["row"],
                    "data-direction": record["direction"],
                },
                rect + "\n" + label,
            )
        )
    return tag("g", {"id": "spiral_board"}, "\n".join(parts))


def empty_layer(layer_id: str) -> str:
    return tag("g", {"id": layer_id}, "")


def centre_layer() -> str:
    cx, cy = 2000, 2260
    lotus_petals = []
    for index in range(12):
        angle = index * 30
        lotus_petals.append(
            empty_tag(
                "ellipse",
                {
                    "id": f"lotus_petal_{index + 1:02d}",
                    "cx": cx,
                    "cy": cy - 145,
                    "rx": 30,
                    "ry": 88,
                    "fill": "none",
                    "stroke": PALETTE["gold"],
                    "stroke-width": 3,
                    "transform": f"rotate({angle} {cx} {cy})",
                },
            )
        )
    frame_lines = []
    for line in range(6):
        y = cy - 42 + line * 22
        frame_lines.append(
            empty_tag(
                "rect",
                {
                    "id": f"centre_hexagram_line_{line + 1}",
                    "x": cx - 92,
                    "y": y,
                    "width": 184,
                    "height": 10,
                    "rx": 3,
                    "fill": "none",
                    "stroke": PALETTE["umber"],
                    "stroke-width": 2,
                    "opacity": 0.55,
                },
            )
        )
    parts = [
        empty_tag("circle", {"id": "centre_circle", "cx": cx, "cy": cy, "r": 235, "fill": "none", "stroke": PALETTE["umber"], "stroke-width": 5}),
        tag("g", {"id": "lotus"}, "\n".join(lotus_petals)),
        tag("g", {"id": "empty_hexagram_frame"}, "\n".join(frame_lines)),
        tag("text", {"id": "centre_title", "x": cx, "y": cy + 150, "font-size": 46, "text-anchor": "middle"}, "The Tao of Lila"),
    ]
    return tag("g", {"id": "centre"}, "\n".join(parts))


def octagon_layer(layer_id: str, arrangement: list[tuple[str, str, int]], cx: int, cy: int, title: str) -> str:
    radius = 255
    points = [point_on_circle(cx, cy, radius, angle) for _, _, angle in arrangement]
    polygon_points = " ".join(f"{round(x, 2)},{round(y, 2)}" for x, y in points)
    parts = [
        empty_tag("polygon", {"id": f"{layer_id}_outline", "points": polygon_points, "fill": "none", "stroke": PALETTE["umber"], "stroke-width": 4}),
        tag("text", {"id": f"{layer_id}_title", "x": cx, "y": cy - radius - 52, "font-size": 32, "text-anchor": "middle"}, title),
    ]
    for position, trigram_id, angle in arrangement:
        x, y = point_on_circle(cx, cy, radius, angle)
        trigram = TRIGRAMS[trigram_id]
        parts.append(
            tag(
                "g",
                {"id": f"{layer_id}_{position}_{trigram_id}", "data-trigram": trigram_id, "data-position": position},
                "\n".join(
                    [
                        empty_tag("use", trigram_use_attrs(f"{layer_id}_{trigram_id}_use", trigram_id, x - TRIGRAM_WIDTH / 2, y - TRIGRAM_HEIGHT / 2)),
                        tag("text", {"id": f"{layer_id}_{trigram_id}_label_chinese", "x": round(x, 2), "y": round(y + 76, 2), "font-size": 26, "text-anchor": "middle"}, trigram.chinese),
                        tag("text", {"id": f"{layer_id}_{trigram_id}_label_pinyin", "x": round(x, 2), "y": round(y + 104, 2), "font-size": 18, "text-anchor": "middle"}, trigram.pinyin),
                        tag("text", {"id": f"{layer_id}_{trigram_id}_label_english", "x": round(x, 2), "y": round(y + 128, 2), "font-size": 16, "text-anchor": "middle"}, trigram.english),
                    ]
                ),
            )
        )
    return tag("g", {"id": layer_id}, "\n".join(parts))


def labels_layer() -> str:
    return tag(
        "g",
        {"id": "labels"},
        "\n".join(
            [
                tag("text", {"id": "label_master_title", "x": 2000, "y": 260, "font-size": 82, "text-anchor": "middle"}, "The Tao of Lila"),
                tag("text", {"id": "label_master_subtitle", "x": 2000, "y": 340, "font-size": 32, "text-anchor": "middle"}, "Master SVG 1.0 - Interactive Contemplative Instrument"),
            ]
        ),
    )


def metadata_layer() -> str:
    return tag(
        "g",
        {"id": "metadata"},
        "\n".join(
            [
                tag("metadata", {"id": "metadata_master_svg"}, "Master SVG 1.0 initial generated vector board."),
                empty_tag("rect", {"id": "metadata_anchor", "x": 0, "y": 0, "width": 0, "height": 0, "fill": "none"}),
            ]
        ),
    )


def animation_layer() -> str:
    anchors = [
        "player_marker",
        "arrow_animation",
        "hexagram_animation",
        "changing_lines",
        "dice",
        "highlight",
    ]
    return tag("g", {"id": "animation"}, "\n".join(tag("g", {"id": anchor}, "") for anchor in anchors))


def svg_document() -> str:
    layers = [
        defs(),
        background_layer(),
        border_layer(),
        guides_layer(),
        taijitu_layer(),
        bagua_ring_layer(),
        arrow_anchor_layer("arrow_casting_left", 420),
        arrow_anchor_layer("arrow_casting_right", 3060),
        spiral_board_layer(),
        empty_layer("snakes"),
        empty_layer("ladders"),
        centre_layer(),
        octagon_layer("fu_xi_octagon", EARLIER_HEAVEN, 610, 3280, "Fu Xi - Earlier Heaven"),
        octagon_layer("king_wen_octagon", LATER_HEAVEN, 3390, 3280, "King Wen - Later Heaven"),
        labels_layer(),
        metadata_layer(),
        animation_layer(),
    ]
    title = tag("title", {"id": "svg_title"}, "The Tao of Lila Master Board")
    desc = tag(
        "desc",
        {"id": "svg_description"},
        "Initial vector-only, layered, addressable Master SVG board for The Tao of Lila.",
    )
    return "\n".join(
        [
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<svg id="tao_of_lila_master_svg" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="2.0" viewBox="0 0 4000 4000" role="img" aria-labelledby="svg_title svg_description">',
            title,
            desc,
            *layers,
            "</svg>",
            "",
        ]
    )


def arrangement_records(arrangement: list[tuple[str, str, int]]) -> list[dict[str, object]]:
    return [
        {
            "position": position,
            "trigramId": trigram_id,
            "angleDegrees": angle,
        }
        for position, trigram_id, angle in arrangement
    ]


def trigram_records() -> list[dict[str, object]]:
    return [
        {
            "id": trigram.id,
            "symbolId": f"trigram_{trigram.id}",
            "binaryValue": sum(line << index for index, line in enumerate(trigram.lines)),
            "linesBottomToTop": list(trigram.lines),
            "chinese": trigram.chinese,
            "pinyin": trigram.pinyin,
            "english": trigram.english,
        }
        for trigram in TRIGRAMS.values()
    ]


def geometry_json() -> dict[str, object]:
    return {
        "version": "1.0-initial",
        "svg": "master.svg",
        "viewBox": [0, 0, VIEWBOX_SIZE, VIEWBOX_SIZE],
        "palette": PALETTE,
        "layers": [
            "defs",
            "background",
            "border",
            "guides",
            "taijitu",
            "earlier_heaven_ring",
            "arrow_casting_left",
            "arrow_casting_right",
            "spiral_board",
            "snakes",
            "ladders",
            "centre",
            "fu_xi_octagon",
            "king_wen_octagon",
            "labels",
            "metadata",
            "animation",
        ],
        "anchors": {
            "animation": [
                "player_marker",
                "arrow_animation",
                "hexagram_animation",
                "changing_lines",
                "dice",
                "highlight",
            ],
            "casting": ["arrow_casting_left", "arrow_casting_right"],
        },
        "regions": {
            "taijitu": {"center": {"x": 2000, "y": 560}, "radius": 160},
            "earlierHeavenRing": {"center": {"x": 2000, "y": 560}, "radius": 300},
            "centre": {"center": {"x": 2000, "y": 2260}, "radius": 235},
            "fuXiOctagon": {"center": {"x": 610, "y": 3280}, "radius": 255},
            "kingWenOctagon": {"center": {"x": 3390, "y": 3280}, "radius": 255},
        },
    }


def board_json() -> dict[str, object]:
    return {
        "version": "1.0-initial",
        "type": "square-spiral",
        "squareCount": SQUARE_COUNT,
        "start": "bottom-left",
        "movement": "inward-clockwise",
        "numbering": "spiral",
        "serpentine": False,
        "squareSize": SQUARE_SIZE,
        "squareGap": SQUARE_GAP,
        "gridOrigin": {"x": BOARD_GRID_ORIGIN_X, "y": BOARD_GRID_ORIGIN_Y},
        "centre": {"type": "circle", "svgId": "centre"},
    }


def squares_json() -> list[dict[str, object]]:
    return square_records()


def snakes_json() -> dict[str, object]:
    return {
        "version": "1.0-initial",
        "snakes": [],
        "ladders": [],
    }


def bagua_json() -> dict[str, object]:
    return {
        "version": "1.0-initial",
        "lineEncoding": {
            "yin": 0,
            "yang": 1,
            "bitOrder": "bottom-to-top",
        },
        "trigrams": trigram_records(),
        "arrangements": {
            "earlierHeaven": arrangement_records(EARLIER_HEAVEN),
            "fuXiOctagon": arrangement_records(EARLIER_HEAVEN),
            "kingWenOctagon": arrangement_records(LATER_HEAVEN),
        },
    }


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    ASSETS.mkdir(exist_ok=True)
    SVG_PATH.write_text(svg_document(), encoding="utf-8")
    write_json(GEOMETRY_PATH, geometry_json())
    write_json(BOARD_PATH, board_json())
    write_json(SQUARES_PATH, squares_json())
    write_json(SNAKES_PATH, snakes_json())
    write_json(BAGUA_PATH, bagua_json())
    print(SVG_PATH.relative_to(ROOT))


if __name__ == "__main__":
    main()
