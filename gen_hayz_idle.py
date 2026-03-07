from PIL import Image
import math
import os

base_path = r"c:\Users\WIN11\Documents\FPT\PRU213\BanhMi.EXE\assets\sprites\npc"
img_path = os.path.join(base_path, "hayz_full.png")

if not os.path.exists(img_path):
    print("Error: hayz_full.png not found!")
    exit(1)

img = Image.open(img_path).convert("RGBA")
width, height = img.size

for i in range(8):
    angle = (i / 8.0) * 2 * math.pi
    factor = (1 - math.cos(angle)) / 2.0  # 0.0 to 1.0
    
    # Breathe in: height +3%, width -1.5%
    scale_y = 1.0 + (0.03 * factor)
    scale_x = 1.0 - (0.015 * factor)
    
    new_w = int(width * scale_x)
    new_h = int(height * scale_y)
    
    resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    canvas = Image.new("RGBA", (width, height), (0,0,0,0))
    x_offset = (width - new_w) // 2
    y_offset = height - new_h
    
    canvas.paste(resized, (x_offset, y_offset))
    
    out_path = os.path.join(base_path, f"hayz_idle_{i+1}.png")
    canvas.save(out_path)
    print(f"Saved {out_path}")
