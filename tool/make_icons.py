"""Android launcher icons from the renders of tool/render_brand.dart.

    flutter test tool/render_brand.dart && python tool/make_icons.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "build" / "brand"
RES = ROOT / "android" / "app" / "src" / "main" / "res"

# density -> (legacy icon px, adaptive foreground px)
DENSITIES = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}


def main() -> None:
    legacy = Image.open(SRC / "icon_rounded.png").convert("RGBA")
    foreground = Image.open(SRC / "icon_foreground.png").convert("RGBA")
    for density, (icon, fg) in DENSITIES.items():
        folder = RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        legacy.resize((icon, icon), Image.LANCZOS).save(folder / "ic_launcher.png")
        foreground.resize((fg, fg), Image.LANCZOS).save(
            folder / "ic_launcher_foreground.png"
        )
        print(f"mipmap-{density}: {icon}px icon, {fg}px foreground")


if __name__ == "__main__":
    main()
