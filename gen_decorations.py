import os
from PIL import Image, ImageDraw

def create_isometric_table(filename, color=(200, 40, 40)):
    # 64x64 image
    img = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Table top (isometric diamond)
    # Center at (32, 24)
    # W=40, H=20
    top_poly = [
        (32, 14), (52, 24), (32, 34), (12, 24)
    ]
    draw.polygon(top_poly, fill=color)
    
    # Table thickness
    thickness_poly_left = [
        (12, 24), (32, 34), (32, 36), (12, 26)
    ]
    thickness_poly_right = [
        (32, 34), (52, 24), (52, 26), (32, 36)
    ]
    shade1 = (int(color[0]*0.8), int(color[1]*0.8), int(color[2]*0.8))
    shade2 = (int(color[0]*0.6), int(color[1]*0.6), int(color[2]*0.6))
    draw.polygon(thickness_poly_left, fill=shade1)
    draw.polygon(thickness_poly_right, fill=shade2)
    
    # Table legs
    leg_color = (int(color[0]*0.5), int(color[1]*0.5), int(color[2]*0.5))
    # Left leg
    draw.rectangle([16, 26, 18, 46], fill=leg_color)
    # Right leg
    draw.rectangle([44, 26, 46, 46], fill=leg_color)
    # Bottom leg (front)
    draw.rectangle([31, 36, 33, 52], fill=leg_color)
    
    img.save(filename)
    print(f"Saved {filename}")

def create_isometric_chair(filename, color=(40, 40, 200)):
    # 32x32 image
    img = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Chair seat
    seat_poly = [
        (16, 16), (24, 20), (16, 24), (8, 20)
    ]
    draw.polygon(seat_poly, fill=color)
    
    # Chair thickness
    shade1 = (int(color[0]*0.8), int(color[1]*0.8), int(color[2]*0.8))
    shade2 = (int(color[0]*0.6), int(color[1]*0.6), int(color[2]*0.6))
    draw.polygon([(8, 20), (16, 24), (16, 25), (8, 21)], fill=shade1)
    draw.polygon([(16, 24), (24, 20), (24, 21), (16, 25)], fill=shade2)
    
    # Chair backrest
    back_poly = [
        (8, 20), (16, 16), (16, 6), (8, 10)
    ]
    draw.polygon(back_poly, fill=shade1)
    
    # Legs
    leg_color = (int(color[0]*0.5), int(color[1]*0.5), int(color[2]*0.5))
    draw.rectangle([10, 21, 11, 29], fill=leg_color) # left
    draw.rectangle([21, 21, 22, 29], fill=leg_color) # right
    draw.rectangle([15, 25, 16, 31], fill=leg_color) # front
    
    img.save(filename)
    print(f"Saved {filename}")

def create_party_lights(filename):
    # 128x64 image
    img = Image.new('RGBA', (128, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw string
    import math
    # curve from (10, 20) to (118, 20) hanging down
    points = []
    for x in range(10, 119):
        # Parabola: y = a(x-h)^2 + k
        # Vertex at (64, 40)
        # 20 = a*(10-64)^2 + 40 => 20 = a*2916 + 40 => -20 = a*2916 => a = -20/2916 = -0.0068... wait, if vertex is at 40 (lower y is higher visually since y goes down)
        y = (x - 64)**2 * 0.0068 + 20
        points.append((x, int(y)))
    
    draw.line(points, fill=(50, 50, 50), width=1)
    
    # Draw lights
    colors = [(255, 50, 50), (50, 255, 50), (50, 50, 255), (255, 255, 50)]
    for i, x in enumerate(range(15, 115, 15)):
        y = int((x - 64)**2 * 0.0068 + 20)
        c = colors[i % len(colors)]
        # draw light bulb
        draw.ellipse([x-3, y, x+3, y+8], fill=c)
        # glow
        draw.ellipse([x-6, y-3, x+6, y+11], fill=(c[0], c[1], c[2], 100))
        
    img.save(filename)
    print(f"Saved {filename}")

if __name__ == "__main__":
    out_dir = r"c:\Users\h_u_n\.gemini\antigravity\scratch\banh-mi-exe\assets\sprites\props"
    os.makedirs(out_dir, exist_ok=True)
    
    create_isometric_table(os.path.join(out_dir, "plastic_table.png"), color=(220, 50, 50))
    create_isometric_chair(os.path.join(out_dir, "plastic_chair.png"), color=(50, 50, 220))
    create_party_lights(os.path.join(out_dir, "party_lights.png"))
