"""
Crop Xiangqi sprite sheets into individual piece PNG files.
Output: assets/textures/xiangqi/<faction>_<piece>.png  (14 files)
"""
from PIL import Image
import os

OUT_DIR = r"c:\Users\h_u_n\.gemini\antigravity\scratch\banh-mi-exe\assets\textures\xiangqi"

RED_SHEET   = os.path.join(OUT_DIR, "pieces_red.png")
BLACK_SHEET = os.path.join(OUT_DIR, "pieces_black.png")

RED_NAMES   = ["general",  "advisor", "elephant", "horse", "chariot", "cannon", "soldier"]
BLACK_NAMES = ["general",  "advisor", "elephant", "horse", "chariot", "cannon", "soldier"]

def crop_sheet(sheet_path, faction, names):
    img = Image.open(sheet_path).convert("RGBA")
    w, h = img.size
    n = len(names)
    cell_w = w // n

    for i, name in enumerate(names):
        x0 = i * cell_w
        y0 = 0
        x1 = x0 + cell_w
        y1 = h
        piece = img.crop((x0, y0, x1, y1))
        out_path = os.path.join(OUT_DIR, f"{faction}_{name}.png")
        piece.save(out_path, "PNG")
        print(f"  Saved: {out_path}  ({piece.size})")

print("Cropping Red pieces...")
crop_sheet(RED_SHEET,   "red",   RED_NAMES)

print("Cropping Black pieces...")
crop_sheet(BLACK_SHEET, "black", BLACK_NAMES)

print(f"\nDone! 14 individual piece images saved to:\n  {OUT_DIR}")
