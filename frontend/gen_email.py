from PIL import Image, ImageDraw, ImageFont
import os

text = "info@exportos.online"
try:
    font = ImageFont.truetype("arial.ttf", 20)
except Exception:
    font = ImageFont.load_default()

try:
    bbox = font.getbbox(text)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
except AttributeError:
    w, h = font.getsize(text)

w += 4
h += 8

img = Image.new('RGBA', (w, h), (0,0,0,0))
draw = ImageDraw.Draw(img)
color = (0, 229, 255, 255)  # Cyan matching TradeOS
draw.text((2, 2), text, font=font, fill=color)

out_path = os.path.join("public", "email_contact.png")
img.save(out_path)
print(f"Saved {out_path}")
