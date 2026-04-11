#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["Pillow"]
# ///
"""Generate ice cave SmartShape2D edge and fill textures."""

from PIL import Image, ImageDraw, ImageFilter
import math
import os
import random

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "levels", "tilesets", "smartshape")

# Ice color palette (same as existing tiles)
PALETTE = {
    "deep":      (14, 22, 40),
    "dark":      (26, 42, 74),
    "mid":       (46, 74, 110),
    "surface":   (74, 122, 154),
    "light":     (122, 184, 208),
    "highlight": (176, 224, 240),
    "crystal":   (208, 240, 255),
}


def det_rand(x, y, seed=42):
    random.seed(hash((x, y, seed)) & 0x7FFFFFFF)
    return random.random()


def ice_color_by_depth(depth_ratio, x, y):
    """Pick ice color based on how deep into the wall (0=edge, 1=deep)."""
    n = det_rand(x, y)
    if depth_ratio < 0.15:
        return random.choice([PALETTE["crystal"], PALETTE["highlight"], PALETTE["light"]])
    elif depth_ratio < 0.35:
        return random.choice([PALETTE["light"], PALETTE["surface"], PALETTE["highlight"]])
    elif depth_ratio < 0.6:
        return random.choice([PALETTE["surface"], PALETTE["mid"], PALETTE["light"]])
    else:
        return random.choice([PALETTE["dark"], PALETTE["mid"], PALETTE["deep"]])


def jagged_edge(width, seed, amplitude=8, base_offset=12):
    """Generate a jagged edge profile across `width` pixels."""
    random.seed(seed)
    profile = []
    for x in range(width):
        wave = math.sin(x * 0.05 + seed) * amplitude * 0.5
        wave += math.sin(x * 0.13 + seed * 2.3) * amplitude * 0.3
        jitter = random.uniform(-1.5, 1.5)
        profile.append(max(3, int(base_offset + wave + jitter)))
    return profile


def generate_edge_texture(width, height, seed):
    """Generate an edge texture strip. Top is transparent (water), bottom is solid ice.

    The edge runs along the top of the texture: transparent above, ice below.
    SmartShape2D rotates these based on normal range.
    """
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    pixels = img.load()

    profile = jagged_edge(width, seed, amplitude=10, base_offset=16)

    for x in range(width):
        edge_y = profile[x]
        for y in range(height):
            if y < edge_y:
                # Water / transparent zone
                # Add a subtle glow near the edge
                dist_to_edge = edge_y - y
                if dist_to_edge <= 4:
                    glow_alpha = int(40 * (1.0 - dist_to_edge / 4.0))
                    c = PALETTE["light"]
                    pixels[x, y] = (c[0], c[1], c[2], glow_alpha)
            else:
                depth = (y - edge_y) / max(1, height - edge_y)
                random.seed(hash((x, y, seed)) & 0x7FFFFFFF)
                color = ice_color_by_depth(depth, x, y)

                # Soften alpha near the jagged edge
                dist_from_edge = y - edge_y
                if dist_from_edge < 3:
                    alpha = 160 + int(95 * (dist_from_edge / 3.0))
                else:
                    alpha = 255

                pixels[x, y] = (color[0], color[1], color[2], alpha)

    return img


def generate_corner_texture(size, seed, inner=True):
    """Generate a corner texture. For inner corners the ice fills the corner;
    for outer corners the ice wraps around the outside."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels = img.load()

    edge_offset = 16
    random.seed(seed)

    for y in range(size):
        for x in range(size):
            if inner:
                # Inner corner: ice in top-left quadrant area
                in_ice = x < (size - edge_offset + random.randint(-2, 2)) and \
                         y < (size - edge_offset + random.randint(-2, 2))
            else:
                # Outer corner: ice wraps around bottom-right
                in_ice = x >= (edge_offset + random.randint(-2, 2)) or \
                         y >= (edge_offset + random.randint(-2, 2))

            if in_ice:
                # Depth based on distance from corner
                dx = min(x, size - 1 - x) / size
                dy = min(y, size - 1 - y) / size
                depth = min(dx, dy) * 2
                random.seed(hash((x, y, seed)) & 0x7FFFFFFF)
                color = ice_color_by_depth(depth, x, y)
                pixels[x, y] = (color[0], color[1], color[2], 255)
            else:
                # Glow near ice boundary
                pass

    return img


def generate_fill_texture(size, seed):
    """Generate a tileable fill texture for the ice interior."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels = img.load()

    for y in range(size):
        for x in range(size):
            random.seed(hash((x, y, seed)) & 0x7FFFFFFF)
            n = random.random()

            # Deep ice interior - mostly dark and mid tones
            if n < 0.35:
                color = PALETTE["deep"]
            elif n < 0.65:
                color = PALETTE["dark"]
            elif n < 0.85:
                color = PALETTE["mid"]
            else:
                color = PALETTE["surface"]

            pixels[x, y] = (color[0], color[1], color[2], 255)

    return img


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Edge texture: 256x128 (same size as metal example)
    edge = generate_edge_texture(256, 128, seed=1001)
    edge.save(os.path.join(OUTPUT_DIR, "ice_edge.png"))
    print("Saved ice_edge.png")

    # Corner textures: 128x128
    corner_inner = generate_corner_texture(128, seed=2001, inner=True)
    corner_inner.save(os.path.join(OUTPUT_DIR, "ice_corner_inner.png"))
    print("Saved ice_corner_inner.png")

    corner_outer = generate_corner_texture(128, seed=2002, inner=False)
    corner_outer.save(os.path.join(OUTPUT_DIR, "ice_corner_outer.png"))
    print("Saved ice_corner_outer.png")

    # Fill texture: 256x256
    fill = generate_fill_texture(256, seed=3001)
    fill.save(os.path.join(OUTPUT_DIR, "ice_fill.png"))
    print("Saved ice_fill.png")

    print("Done! Textures saved to:", OUTPUT_DIR)


if __name__ == "__main__":
    main()
