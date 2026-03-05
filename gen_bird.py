from PIL import Image, ImageDraw

def create_bird():
    # A simple 16x16 pixel bird (like a V or a seagull shape)
    img = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    
    # Draw simple "V" shape bird in light grey/white
    color = (255, 255, 255, 255)
    
    # Left wing
    d.line([(2, 4), (7, 8)], fill=color, width=2)
    # Right wing
    d.line([(14, 4), (9, 8)], fill=color, width=2)
    # Body
    d.rectangle([(7, 7), (9, 9)], fill=color)
    
    img.save('c:\\Users\\h_u_n\\.gemini\\antigravity\\scratch\\banh-mi-exe\\assets\\sprites\\sky\\bird.png')
    print("Bird sprite created.")

if __name__ == "__main__":
    create_bird()
