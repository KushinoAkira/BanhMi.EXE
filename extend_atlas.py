from PIL import Image, ImageDraw
import os

base_dir = "c:/Users/h_u_n/.gemini/antigravity/scratch/banh-mi-exe"
atlas_path = os.path.join(base_dir, "assets/tiles/iso_tiles_atlas.png")

# Load existing atlas
try:
    old_atlas = Image.open(atlas_path).convert("RGBA")
except Exception as e:
    print(f"Error opening atlas: {e}")
    exit(1)

# The old atlas has 3 tiles: 0, 1, 2. Size should be 384x64 or similar.
# A single tile is 128x64.
TW = 128
TH = 64
ROAD_TILE_IDX = 1

# Extract the base road tile
road_tile = old_atlas.crop((ROAD_TILE_IDX*TW, 0, (ROAD_TILE_IDX+1)*TW, TH))

# We will create 3 new road tiles.
# 3: Road along COL (down-right) -> lane line from TL to BR
# 4: Road along ROW (down-left) -> lane line from TR to BL
# 5: Intersection -> crosswalk lines

def draw_dashed_line(draw, x0, y0, x1, y1, fill, width=2, dash_len=8, gap_len=8):
    # simple bresenham or just linear interpolation
    import math
    dist = math.hypot(x1-x0, y1-y0)
    steps = int(dist / (dash_len + gap_len))
    if steps == 0: steps = 1
    
    for i in range(steps + 1):
        # start of dash
        t0 = max(0.0, min(1.0, (i * (dash_len + gap_len)) / dist))
        # end of dash
        t1 = max(0.0, min(1.0, (i * (dash_len + gap_len) + dash_len) / dist))
        
        px0 = x0 + (x1-x0)*t0
        py0 = y0 + (y1-y0)*t0
        px1 = x0 + (x1-x0)*t1
        py1 = y0 + (y1-y0)*t1
        draw.line([px0, py0, px1, py1], fill=fill, width=width)

# Col road: lane from TL to BR
img_col = road_tile.copy()
draw_col = ImageDraw.Draw(img_col)
# TL edge midpoint: (32, 16). BR edge midpoint: (96, 48).
draw_dashed_line(draw_col, 32, 16, 96, 48, fill=(255, 255, 255, 200), width=3, dash_len=12, gap_len=8)

# Row road: lane from TR to BL
img_row = road_tile.copy()
draw_row = ImageDraw.Draw(img_row)
# TR edge midpoint: (96, 16). BL edge midpoint: (32, 48).
draw_dashed_line(draw_row, 96, 16, 32, 48, fill=(255, 255, 255, 200), width=3, dash_len=12, gap_len=8)

# Intersection: crosswalk
img_int = road_tile.copy()
draw_int = ImageDraw.Draw(img_int)
# Draw lines offset from center to form a square
# Center is (64, 32)
# Vectors for isometric axes: U=(32, 16), V=(32, -16)
# Crosswalk box corners approximately:
pts = [
    (64, 16),
    (96, 32),
    (64, 48),
    (32, 32)
]
draw_int.polygon(pts, outline=(255, 255, 255, 200), width=2)
# inner box
pts2 = [
    (64, 20),
    (88, 32),
    (64, 44),
    (40, 32)
]
draw_int.polygon(pts2, outline=(255, 255, 255, 200), width=1)

# New atlas with 6 tiles
new_w = 6 * TW
new_atlas = Image.new("RGBA", (new_w, TH))
new_atlas.paste(old_atlas, (0, 0))
new_atlas.paste(img_col, (3*TW, 0))
new_atlas.paste(img_row, (4*TW, 0))
new_atlas.paste(img_int, (5*TW, 0))

# Save
new_atlas.save(atlas_path)
print(f"Successfully updated {atlas_path} with 6 tiles.")
