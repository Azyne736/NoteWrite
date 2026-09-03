"""Generate the NoteWrite app icon (1024x1024, opaque PNG).

Usage: python gen_icon.py
Output: NoteWrite/Assets.xcassets/AppIcon.appiconset/AppIcon.png
"""
import os
from PIL import Image, ImageDraw, ImageFont

S = 1024

# 渐变背景：靛蓝 -> 紫 -> 粉
c1 = (67, 56, 202)
c2 = (147, 51, 234)
c3 = (236, 72, 153)

img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)
for y in range(S):
    t = y / (S - 1)
    if t < 0.55:
        u = t / 0.55
        a, b = c1, c2
    else:
        u = (t - 0.55) / 0.45
        a, b = c2, c3
    color = tuple(int(a[i] + (b[i] - a[i]) * u) for i in range(3))
    d.line([(0, y), (S, y)], fill=color)

# 柔光圆
overlay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)
od.ellipse([-260, -260, 420, 420], fill=(255, 255, 255, 42))
od.ellipse([640, 640, 1400, 1400], fill=(255, 255, 255, 30))
img = Image.alpha_composite(img.convert("RGBA"), overlay)
d = ImageDraw.Draw(img)

# 主字 “笔”
font_path = None
for p in [
    r"C:\Windows\Fonts\msyhbd.ttc",
    r"C:\Windows\Fonts\msyh.ttc",
    r"C:\Windows\Fonts\simhei.ttf",
    r"C:\Windows\Fonts\simsun.ttc",
]:
    if os.path.exists(p):
        font_path = p
        break

if font_path:
    font = ImageFont.truetype(font_path, 520)
    text = "笔"
else:
    font = ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", 620)
    text = "N"

bbox = d.textbbox((0, 0), text, font=font)
w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
x = (S - w) / 2 - bbox[0]
y = (S - h) / 2 - bbox[1] - 50
d.text((x, y), text, font=font, fill=(255, 255, 255, 255))

# 右下角对勾徽章
r = 140
cx, cy = 800, 800
d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(34, 197, 94))
d.line([(cx - 58, cy + 4), (cx - 14, cy + 48), (cx + 66, cy - 48)],
       fill=(255, 255, 255), width=30, joint="curve")

out = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "NoteWrite", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")
img.convert("RGB").save(out, "PNG")
print("icon saved:", out)
