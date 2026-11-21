#!/usr/bin/env python3
"""Install the app icon from the approved artwork.

Reads docs/branding/TabasaranKeyboard_AppIcon_1024.png (the artwork as
delivered, kept unmodified) and writes into Assets.xcassets:

    AppIcon.appiconset/AppIcon-1024.png   the same bytes: 1024 × 1024, opaque RGB, square
    AppLogo.imageset/AppLogo.png          512 × 512, the logo on the app's screen

Needs Pillow:

    python3 scripts/make_icon.py

The artwork is not changed. The script only checks what iOS requires of an
app icon and stops if a check fails: exactly 1024 × 1024, RGB without an
alpha channel, full bleed (the four corners carry the field colour of their
edge, so there are no pre-rounded corners or dark corner remnants), and no
stray pixels in the outer 8 px (each differs from the colour 24 px further
inside by less than the tolerance).
"""
import os
import shutil
import sys

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(REPO, "docs", "branding", "TabasaranKeyboard_AppIcon_1024.png")
ASSETS = os.path.join(REPO, "TabasaranKeyboard", "TabasaranKeyboard", "Assets.xcassets")
SIZE = 1024
BORDER = 8        # px from each edge that are checked for strays
REFERENCE = 24    # px inward from the edge where the field colour is sampled
TOLERANCE = 30    # summed RGB difference that counts as a stray pixel


def distance(a, b):
    return sum(abs(x - y) for x, y in zip(a, b))


def main():
    source = Image.open(SOURCE)
    if source.format != "PNG":
        sys.exit(f"error: the source is {source.format}, expected PNG")
    if source.size != (SIZE, SIZE):
        sys.exit(f"error: the source is {source.size}, expected {SIZE} × {SIZE}")
    if source.mode != "RGB":
        sys.exit(f"error: the source is {source.mode}; an app icon must be opaque RGB without an alpha channel")
    px = source.load()

    strays = 0
    for y in range(SIZE):
        for x in range(SIZE):
            if min(x, y, SIZE - 1 - x, SIZE - 1 - y) >= BORDER:
                continue
            # The field colour of this row or column, further inside
            if x < BORDER:
                field = px[REFERENCE, y]
            elif x >= SIZE - BORDER:
                field = px[SIZE - 1 - REFERENCE, y]
            elif y < BORDER:
                field = px[x, REFERENCE]
            else:
                field = px[x, SIZE - 1 - REFERENCE]
            strays += distance(px[x, y], field) > TOLERANCE
    if strays:
        sys.exit(f"error: {strays} pixels in the outer {BORDER} px differ from the field colour "
                 "(rounded corners or an outline?); the artwork must be a full-bleed square")

    shutil.copyfile(SOURCE, os.path.join(ASSETS, "AppIcon.appiconset", "AppIcon-1024.png"))
    source.resize((512, 512), Image.LANCZOS).save(os.path.join(ASSETS, "AppLogo.imageset", "AppLogo.png"),
                                                  "PNG", optimize=True)
    corner = px[0, 0]
    print(f"icon installed unchanged: {SIZE} × {SIZE} {source.mode} PNG, no alpha, full bleed, "
          f"corner colour #{corner[0]:02X}{corner[1]:02X}{corner[2]:02X}, 0 stray border pixels")


if __name__ == "__main__":
    main()
