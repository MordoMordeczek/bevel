#!/usr/bin/env python3
"""Builds the built-in .bevel themes in themes/. Previews of animated themes are rendered by
tools/render_live.qml (needs PySide6 + a GL display); pass --previews DIR to reuse renders."""
import base64, io, json, os, sys
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CLASSIC = {"style.rounding": 0, "style.bevel": 2, "style.opacity": 1.0, "style.dither": True, "bar.floating": False,
           "windows.gapsIn": 3, "windows.gapsOut": 6, "windows.border": 2, "windows.blur": False, "windows.shadow": False}
SOFT = {"style.rounding": 0, "style.bevel": 2, "style.opacity": 0.96, "style.dither": False, "bar.floating": True,
        "windows.gapsIn": 4, "windows.gapsOut": 8, "windows.border": 2, "windows.blur": False, "windows.shadow": False}
W = lambda *l: [{"id": i, "size": s} for i, s in l]  # noqa: E731
THEMES = [
    ("Windows 95", "teal", "#000080", dict(CLASSIC, **{"colors.source": "custom", "colors.custom": "#000080",
        "colors.darkPanels": False, "colors.mono": "never", "bar.layout": "taskbar", "launcher.style": "start",
        "power.style": "dialog", "style.preset": "classic", "style.font": "Pixelify Sans",
        "widgets.enabled": True, "widgets.style": "panel", "widgets.corner": "top-left", "widgets.arrange": "column",
        "widgets.cell": 90, "widgets.list": W(("computer", "1x1"), ("documents", "1x1"), ("trash", "1x1"), ("terminalicon", "1x1"))})),
    ("Vaporwave", "live", ("synthwave", "#c03070", "neon"), dict(SOFT, **{"colors.source": "wallpaper",
        "colors.darkPanels": True, "colors.vibrance": 0.9, "bar.layout": "island", "launcher.style": "grid",
        "power.style": "tiles", "widgets.enabled": True, "widgets.style": "glass", "widgets.corner": "bottom",
        "widgets.arrange": "row", "widgets.list": W(("clock", "2x1"), ("visualizer", "3x1"), ("media", "2x1"))})),
    ("Terminal", "live", ("matrix", "#3f9a4a", "night"), dict(CLASSIC, **{"colors.source": "wallpaper",
        "colors.darkPanels": True, "colors.darkTerminal": True, "style.font": "VT323", "style.lcdClock": True,
        "bar.layout": "bevel", "launcher.style": "run", "widgets.enabled": True, "widgets.style": "panel",
        "widgets.corner": "left", "widgets.arrange": "column",
        "widgets.list": W(("fetch", "3x2"), ("cpu", "2x1"), ("ram", "1x1"), ("disk", "1x1"), ("ascii", "3x1")),
        "widgets.asciiText": "HACK", "widgets.asciiStyle": "hash"})),
    ("Ocean", "wallpapers/bevel-ocean.png", None, dict(SOFT, **{"colors.source": "wallpaper", "colors.darkPanels": False,
        "bar.layout": "bevel", "widgets.enabled": True, "widgets.style": "tiles", "widgets.corner": "top-right",
        "widgets.arrange": "grid", "widgets.cols": 4,
        "widgets.list": W(("clock", "2x1"), ("calendar", "2x2"), ("weather", "2x1"), ("btw", "2x1"))})),
    ("Ember", "wallpapers/bevel-ember.png", None, dict(SOFT, **{"colors.source": "wallpaper", "colors.darkPanels": True,
        "bar.layout": "dock", "widgets.enabled": True, "widgets.style": "tiles", "widgets.corner": "bottom-right",
        "widgets.list": W(("clock", "2x2"), ("pomodoro", "2x1"), ("notes", "2x1"))})),
    ("Moss", "wallpapers/bevel-moss.png", None, dict(CLASSIC, **{"colors.source": "wallpaper", "colors.darkPanels": False,
        "bar.layout": "taskbar", "launcher.style": "start", "widgets.enabled": True, "widgets.style": "window",
        "widgets.corner": "top-right", "widgets.list": W(("clock", "2x1"), ("minesweeper", "2x2"), ("trash", "1x1"), ("computer", "1x1"))})),
    ("Black & White", "live", ("starfield", "#808080", "mono"), dict(SOFT, **{"colors.source": "wallpaper",
        "colors.mono": "always", "colors.darkPanels": True, "bar.layout": "bevel", "widgets.enabled": True,
        "widgets.style": "glass", "widgets.corner": "center", "widgets.arrange": "grid", "widgets.cols": 4,
        "widgets.list": W(("clock", "2x2"), ("calendar", "2x2"), ("ascii", "4x1")), "widgets.asciiText": "BEVEL"})),
    ("Sunset Sea", "live", ("ocean", "#d8662a", "dusk"), dict(SOFT, **{"colors.source": "wallpaper", "colors.darkPanels": True,
        "bar.layout": "dock", "launcher.style": "grid", "widgets.enabled": True, "widgets.style": "tiles",
        "widgets.corner": "top-left", "widgets.list": W(("worldclock", "2x2"), ("rss", "4x1"), ("btw", "2x1"))})),
]


def png_b64(img):
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return base64.b64encode(buf.getvalue()).decode()


def main():
    prev_dir = sys.argv[sys.argv.index("--previews") + 1] if "--previews" in sys.argv else None
    out_dir = os.path.join(ROOT, "themes")
    os.makedirs(out_dir, exist_ok=True)
    for name, kind, extra, settings in THEMES:
        th = {"bevelTheme": 1, "name": name, "author": "Bevel", "created": "2026-10-19", "settings": dict(settings)}
        slug = name.replace(" ", "-").replace("&", "and")
        if kind == "live":
            k, col, pal = extra
            th["settings"].update({"wallpaper.mode": "live", "wallpaper.live.kind": k, "wallpaper.live.color": col,
                                   "wallpaper.live.palette": pal, "wallpaper.live.pixel": 3})
            pv = os.path.join(prev_dir, slug + ".png") if prev_dir else None
            if pv and os.path.exists(pv):
                th["preview"] = png_b64(Image.open(pv).convert("RGB"))
        else:
            th["settings"]["wallpaper.mode"] = "image"
            if kind == "teal":
                img = Image.new("RGB", (1920, 1080), (0, 128, 128))
                fname = "teal.png"
            else:
                img = Image.open(os.path.join(ROOT, kind)).convert("RGB")
                fname = os.path.basename(kind)
            buf = io.BytesIO()
            img.save(buf, "PNG", optimize=True)
            th["wallpaper"] = {"filename": fname, "data": base64.b64encode(buf.getvalue()).decode()}
            t = img.copy()
            t.thumbnail((320, 180))
            th["preview"] = png_b64(t)
        with open(os.path.join(out_dir, slug + ".bevel"), "w") as f:
            json.dump(th, f)
        print("wrote", slug)


if __name__ == "__main__":
    main()
