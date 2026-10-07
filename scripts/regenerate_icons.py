#!/usr/bin/env python3
"""Régénère toutes les icônes de l'app GOREX LUXURY CONCIERGE
depuis assets/icons/app_icon.png (1024x1024, G doré sur noir).

- Icônes Android legacy (mipmap-<density>/ic_launcher.png + _round)
- Icônes adaptatives (mipmap-anydpi-v26 + foreground par densité)
- Icônes web (Icon-192/512 + maskable)
- favicon
"""
import os
from PIL import Image

ROOT = "/home/user/flutter_app"
SRC = os.path.join(ROOT, "assets/icons/app_icon.png")
RES = os.path.join(ROOT, "android/app/src/main/res")
WEB = os.path.join(ROOT, "web")

BLACK = (10, 10, 11, 255)  # #0A0A0B — fond de marque

src = Image.open(SRC).convert("RGBA")

# ── 1. Icônes legacy par densité ──
LEGACY = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
for dens, size in LEGACY.items():
    d = os.path.join(RES, f"mipmap-{dens}")
    os.makedirs(d, exist_ok=True)
    img = src.resize((size, size), Image.LANCZOS)
    img.save(os.path.join(d, "ic_launcher.png"))
    # rond : même image (le carré doré est centré, un masque rond sera
    # appliqué par le launcher)
    img.save(os.path.join(d, "ic_launcher_round.png"))
    print(f"legacy {dens}: {size}x{size}")

# ── 2. Icônes adaptatives ──
# Foreground : logo centré, contenu dans la safe zone (66% du canevas).
# Canevas adaptatif = 108dp ; safe zone = 72dp (centre).
ADAPTIVE = {
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432,
}
for dens, canvas in ADAPTIVE.items():
    d = os.path.join(RES, f"mipmap-{dens}")
    os.makedirs(d, exist_ok=True)
    # Fond transparent, logo à ~62% centré
    fg = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    logo_size = int(canvas * 0.62)
    logo = src.resize((logo_size, logo_size), Image.LANCZOS)
    off = (canvas - logo_size) // 2
    # Rendre le fond noir du logo transparent (ne garder que le doré)
    px = logo.load()
    for y in range(logo_size):
        for x in range(logo_size):
            r, g, b, a = px[x, y]
            # Pixel très sombre => transparent (fond)
            if r < 40 and g < 40 and b < 40:
                px[x, y] = (0, 0, 0, 0)
    fg.paste(logo, (off, off), logo)
    fg.save(os.path.join(d, "ic_launcher_foreground.png"))
    print(f"adaptive fg {dens}: {canvas}x{canvas}")

# XML adaptatif
anydpi = os.path.join(RES, "mipmap-anydpi-v26")
os.makedirs(anydpi, exist_ok=True)
xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""
with open(os.path.join(anydpi, "ic_launcher.xml"), "w") as f:
    f.write(xml)
with open(os.path.join(anydpi, "ic_launcher_round.xml"), "w") as f:
    f.write(xml)
print("adaptive XML written")

# ── 3. Couleur de fond adaptatif ──
vals = os.path.join(RES, "values")
os.makedirs(vals, exist_ok=True)
colors_path = os.path.join(vals, "ic_launcher_background.xml")
with open(colors_path, "w") as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n'
            '<resources>\n'
            '    <color name="ic_launcher_background">#0A0A0B</color>\n'
            '</resources>\n')
print("background color written")

# ── 4. Icônes web ──
os.makedirs(os.path.join(WEB, "icons"), exist_ok=True)
src.resize((192, 192), Image.LANCZOS).save(os.path.join(WEB, "icons/Icon-192.png"))
src.resize((512, 512), Image.LANCZOS).save(os.path.join(WEB, "icons/Icon-512.png"))
# Maskable : logo à 80% sur fond plein (safe zone maskable ~80%)
def maskable(size):
    base = Image.new("RGBA", (size, size), BLACK)
    inner = int(size * 0.72)
    logo = src.resize((inner, inner), Image.LANCZOS)
    off = (size - inner) // 2
    base.paste(logo, (off, off), logo)
    return base
maskable(192).save(os.path.join(WEB, "icons/Icon-maskable-192.png"))
maskable(512).save(os.path.join(WEB, "icons/Icon-maskable-512.png"))
src.resize((32, 32), Image.LANCZOS).save(os.path.join(WEB, "favicon.png"))
print("web icons + favicon written")

print("DONE")
