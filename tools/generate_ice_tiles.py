#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["Pillow"]
# ///
"""Generate ice cave tileset atlas and decoration sprites for the underwater level."""

from PIL import Image, ImageDraw
import random
import os

TILE_SIZE = 64
GRID = 4
ATLAS_SIZE = TILE_SIZE * GRID
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "levels", "tilesets")

# Ice color palette
PALETTE = {
    "deep":      (14, 22, 40),
    "dark":      (26, 42, 74),
    "mid":       (46, 74, 110),
    "surface":   (74, 122, 154),
    "light":     (122, 184, 208),
    "highlight": (176, 224, 240),
    "crystal":   (208, 240, 255),
}


import math


def det_rand(x, y, seed=42):
    """Deterministic random float [0,1) for a given pixel position and seed."""
    random.seed(hash((x, y, seed)) & 0x7FFFFFFF)
    return random.random()


def edge_profile(pos, seed):
    """Jagged edge offset at position `pos` along a tile side. Returns 5-11."""
    random.seed(hash((pos, seed)) & 0x7FFFFFFF)
    base = 7
    wave = math.sin(pos * 0.4 + seed * 0.1) * 2.5
    jitter = random.randint(-1, 1)
    return max(4, min(12, int(base + wave + jitter)))


def ice_color(x, y, dist_to_edge):
    """Pick ice color based on noise and distance to nearest exposed edge."""
    n = det_rand(x, y, seed=42)

    if dist_to_edge <= 2:
        if n < 0.4:
            return PALETTE["light"]
        elif n < 0.7:
            return PALETTE["highlight"]
        else:
            return PALETTE["crystal"]
    elif dist_to_edge <= 5:
        if n < 0.3:
            return PALETTE["mid"]
        elif n < 0.7:
            return PALETTE["surface"]
        else:
            return PALETTE["light"]
    else:
        if n < 0.35:
            return PALETTE["deep"]
        elif n < 0.7:
            return PALETTE["dark"]
        elif n < 0.9:
            return PALETTE["mid"]
        else:
            return PALETTE["surface"]


def generate_tile(index):
    """Generate a 64x64 tile for the given 4-bit neighbor mask.

    Bits: 0=top, 1=right, 2=bottom, 3=left.
    Bit set means that side connects to another wall tile (seamless).
    Bit unset means that side faces open water (decorated edge).
    """
    has_top = bool(index & 1)
    has_right = bool(index & 2)
    has_bottom = bool(index & 4)
    has_left = bool(index & 8)

    img = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
    pixels = img.load()

    top_profile = [edge_profile(x, seed=index * 100 + 0) for x in range(TILE_SIZE)]
    bottom_profile = [edge_profile(x, seed=index * 100 + 1) for x in range(TILE_SIZE)]
    left_profile = [edge_profile(y, seed=index * 100 + 2) for y in range(TILE_SIZE)]
    right_profile = [edge_profile(y, seed=index * 100 + 3) for y in range(TILE_SIZE)]

    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            in_water = False
            if not has_top and y < top_profile[x]:
                in_water = True
            if not has_bottom and y >= TILE_SIZE - bottom_profile[x]:
                in_water = True
            if not has_left and x < left_profile[y]:
                in_water = True
            if not has_right and x >= TILE_SIZE - right_profile[y]:
                in_water = True

            if in_water:
                continue

            distances = []
            if not has_top:
                distances.append(y - top_profile[x])
            if not has_bottom:
                distances.append((TILE_SIZE - 1 - bottom_profile[x]) - y)
            if not has_left:
                distances.append(x - left_profile[y])
            if not has_right:
                distances.append((TILE_SIZE - 1 - right_profile[y]) - x)

            dist_to_edge = min(distances) if distances else 999

            color = ice_color(x, y, dist_to_edge)
            pixels[x, y] = (*color, 255)

    return img


def generate_stalactite(width, height, seed, palette_bias="cold"):
    """Generate a pixel art stalactite/stalagmite sprite."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    pixels = img.load()
    center_x = width // 2

    for y in range(height):
        # Taper: wider at top (y=0), narrower at bottom
        progress = y / height
        half_width = max(1, int((1.0 - progress * progress) * center_x))

        # Add noise to the edge
        random.seed(hash((y, seed)) & 0x7FFFFFFF)
        noise = random.randint(-1, 1)
        half_width = max(1, half_width + noise)

        for x in range(center_x - half_width, center_x + half_width + 1):
            if 0 <= x < width:
                dx = abs(x - center_x)
                edge_dist = half_width - dx

                n = det_rand(x, y, seed=seed)
                if edge_dist <= 1:
                    color = PALETTE["highlight"] if n < 0.5 else PALETTE["light"]
                elif progress > 0.8:
                    color = PALETTE["crystal"] if n < 0.3 else PALETTE["highlight"]
                elif edge_dist <= 3:
                    color = PALETTE["surface"] if n < 0.5 else PALETTE["light"]
                else:
                    color = PALETTE["dark"] if n < 0.4 else PALETTE["mid"]

                pixels[x, y] = (*color, 230 if edge_dist <= 1 else 255)

    return img


def generate_crystal(size, seed):
    """Generate a small ice crystal cluster sprite."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    random.seed(seed)

    cx, cy = size // 2, size // 2

    # Draw 3-5 crystal shards
    num_shards = random.randint(3, 5)
    for i in range(num_shards):
        angle_deg = random.randint(0, 360)
        length = random.randint(size // 4, size // 2 - 2)
        width = random.randint(2, 4)

        import math
        rad = math.radians(angle_deg)
        ex = cx + int(math.cos(rad) * length)
        ey = cy + int(math.sin(rad) * length)

        color = random.choice([PALETTE["crystal"], PALETTE["highlight"], PALETTE["light"]])
        draw.line([(cx, cy), (ex, ey)], fill=(*color, 220), width=width)

        # Bright tip
        draw.point((ex, ey), fill=(*PALETTE["crystal"], 255))

    return img


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # --- Generate tile atlas ---
    atlas = Image.new("RGBA", (ATLAS_SIZE, ATLAS_SIZE), (0, 0, 0, 0))
    for index in range(16):
        col = index % GRID
        row = index // GRID
        tile = generate_tile(index)
        atlas.paste(tile, (col * TILE_SIZE, row * TILE_SIZE))

    atlas_path = os.path.join(OUTPUT_DIR, "ice_cave_tiles.png")
    atlas.save(atlas_path)
    print(f"Saved tile atlas: {atlas_path}")

    # --- Generate decoration sprites ---
    stalactite1 = generate_stalactite(24, 96, seed=101)
    stalactite1.save(os.path.join(OUTPUT_DIR, "stalactite_01.png"))

    stalactite2 = generate_stalactite(18, 72, seed=202)
    stalactite2.save(os.path.join(OUTPUT_DIR, "stalactite_02.png"))

    crystal1 = generate_crystal(32, seed=301)
    crystal1.save(os.path.join(OUTPUT_DIR, "crystal_01.png"))

    # --- Generate small particle dot for floating debris ---
    dot = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
    dot_px = dot.load()
    for dy in range(4):
        for dx in range(4):
            dist = ((dx - 1.5) ** 2 + (dy - 1.5) ** 2) ** 0.5
            if dist < 2.0:
                a = int(180 * (1.0 - dist / 2.0))
                dot_px[dx, dy] = (200, 220, 240, a)
    dot.save(os.path.join(OUTPUT_DIR, "debris_dot.png"))

    print("Saved decoration sprites")
    print("Done!")


if __name__ == "__main__":
    main()
