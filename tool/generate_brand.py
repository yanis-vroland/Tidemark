"""Génère le logo Tidemark sous toutes ses formes depuis une seule géométrie (spec 007).

Sorties : les SVG de docs/maquettes/000-charte/logo/,
les icônes de l'app (iOS et Android, adaptative comprise) et les images de
l'écran de lancement. Aucune dépendance : les PNG sont rastérisés ici, par
distance signée, pour que le résultat soit identique sur tout poste.

Usage :
  python3 tool/generate_brand.py          écrit les fichiers
  python3 tool/generate_brand.py --check  n'écrit rien ; code 1 si un fichier
                                          du dépôt diffère de sa génération

Le logo est redessiné dans l'app par lib/ui/widgets/tidemark_logo.dart, avec
les mêmes coordonnées (MARK_* ci-dessous ; un test vérifie qu'elles concordent).
"""

from __future__ import annotations

import json
import math
import re
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOGO_DIR = ROOT / "docs/maquettes/000-charte/logo"
RES = ROOT / "android/app/src/main/res"
XCASSETS = ROOT / "ios/Runner/Assets.xcassets"
STORYBOARD = ROOT / "ios/Runner/Base.lproj/LaunchScreen.storyboard"

# Géométrie du logo C « T de marée », dans une boîte de 48 × 48 qui est la
# tuile : un T dont la barre est une vague, et un point au pied de la lettre,
# la laisse que dépose la marée. Trait à extrémités et joints arrondis.
MARK_TILE_RADIUS = 11
MARK_STROKE = 3.2
# Vague : départ x, y, largeur d'une demi-onde, creux (écart du point de
# contrôle de chaque courbe quadratique), nombre de demi-ondes. La première
# monte, les suivantes alternent (comme « q3.5 -3.2 7 0 t7 0… » en SVG).
MARK_WAVE = (10, 16, 7, 3.2, 4)
MARK_STEM = ((24, 22), (24, 37))
MARK_DOT = (31.5, 37, 2.6)

# Taille de l'écran de lancement, en points (maquette 007, « Lancement »).
LAUNCH_SIZE = 112

GENERATED_XML = "<!-- GÉNÉRÉ par tool/generate_brand.py (spec 007) : ne pas modifier à la main. -->\n"


def _tokens() -> dict:
    """Couleurs de la charte, par thème, lues dans tokens.json."""
    data = json.loads((ROOT / "docs/maquettes/000-charte/tokens.json").read_text(encoding="utf-8"))
    return {t["name"]: t["value"] for t in data["color"]["tokens"]}


_COLORS = _tokens()
BRAND = _COLORS["brand"]["light"]  # la marque est la même dans les deux thèmes
ON_BRAND = _COLORS["on-brand"]["light"]
ACCENT = _COLORS["brand-accent"]["light"]
INK = _COLORS["ink"]["light"]
SURFACE = _COLORS["surface"]["light"]
SURFACE_DARK = _COLORS["surface"]["dark"]


def rgb(hex_value: str) -> tuple[int, int, int]:
    value = hex_value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


# --- Géométrie -----------------------------------------------------------


def wave_curves() -> list[tuple[tuple, tuple, tuple]]:
    """Les demi-ondes de la vague, en courbes quadratiques (départ, contrôle, arrivée)."""
    x0, y, half, depth, count = MARK_WAVE
    curves = []
    for k in range(count):
        sign = -1 if k % 2 == 0 else 1
        start = (x0 + k * half, y)
        control = (x0 + k * half + half / 2, y + sign * depth)
        end = (x0 + (k + 1) * half, y)
        curves.append((start, control, end))
    return curves


def _quad(p0: tuple, p1: tuple, p2: tuple, t: float) -> tuple[float, float]:
    u = 1 - t
    return (
        u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
        u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1],
    )


SAMPLES = 12
WAVE_POLYLINES = [[_quad(*curve, i / SAMPLES) for i in range(SAMPLES + 1)] for curve in wave_curves()]


# --- SVG -----------------------------------------------------------------


def wave_path(unit: float = 1, ox: float = 0, oy: float = 0, sep: str = " ") -> str:
    def p(x: float, y: float) -> str:
        return f"{ox + x * unit:.3f}{sep}{oy + y * unit:.3f}" if unit != 1 or ox or oy else f"{x:g}{sep}{y:g}"

    curves = wave_curves()
    path = "M" + p(*curves[0][0])
    for start, control, end in curves:
        path += " Q" + p(*control) + " " + p(*end)
    return path


def mark_svg_body(color: str, accent: str) -> str:
    (sx, sy), (ex, ey) = MARK_STEM
    cx, cy, r = MARK_DOT
    return (
        f'<g fill="none" stroke="{color}" stroke-width="{MARK_STROKE:g}" stroke-linecap="round" stroke-linejoin="round">'
        f'<path d="{wave_path()}"/><path d="M{sx:g} {sy:g} L{ex:g} {ey:g}"/></g>'
        f'<circle cx="{cx:g}" cy="{cy:g}" r="{r:g}" fill="{accent}"/>'
    )


def svg_files() -> dict[Path, bytes]:
    head = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" role="img" aria-label="Tidemark">'
    tile = f'<rect width="48" height="48" rx="{MARK_TILE_RADIUS:g}" fill="{BRAND}"/>'
    return {
        LOGO_DIR / "tidemark-logo.svg": (head + tile + mark_svg_body(ON_BRAND, ACCENT) + "</svg>\n").encode(),
        LOGO_DIR / "tidemark-mark.svg": (head + mark_svg_body(BRAND, ACCENT) + "</svg>\n").encode(),
        LOGO_DIR / "tidemark-mark-mono.svg": (head + mark_svg_body(INK, INK) + "</svg>\n").encode(),
    }


# --- Rastérisation -------------------------------------------------------


def segment_distance(px: float, py: float, a: tuple, b: tuple) -> float:
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def stroke_distance(x: float, y: float) -> float:
    """Distance signée à la vague et au jambage, en unités de la boîte de 48."""
    x0, _, half, _, count = MARK_WAVE
    k = int((x - x0) // half)
    best = math.inf
    for i in range(max(0, k - 1), min(count, k + 2)):
        line = WAVE_POLYLINES[i]
        for j in range(SAMPLES):
            best = min(best, segment_distance(x, y, line[j], line[j + 1]))
    if best == math.inf:  # loin de la vague, à gauche ou à droite
        ends = (WAVE_POLYLINES[0][0], WAVE_POLYLINES[-1][-1])
        best = min(math.hypot(x - ex, y - ey) for ex, ey in ends)
    best = min(best, segment_distance(x, y, *MARK_STEM))
    return best - MARK_STROKE / 2


def dot_distance(x: float, y: float) -> float:
    cx, cy, r = MARK_DOT
    return math.hypot(x - cx, y - cy) - r


def rounded_rect_distance(x: float, y: float, x0: float, y0: float, size: float, radius: float) -> float:
    half = size / 2
    qx = abs(x - (x0 + half)) - (half - radius)
    qy = abs(y - (y0 + half)) - (half - radius)
    outside = math.hypot(max(qx, 0), max(qy, 0))
    return outside + min(max(qx, qy), 0) - radius


def coverage(distance_px: float) -> float:
    return max(0.0, min(1.0, 0.5 - distance_px))


def mix(a: tuple, b: tuple, t: float) -> list[float]:
    return [u + (v - u) * t for u, v in zip(a, b)]


# Boîte englobante du symbole (avec une marge) : hors d'elle, aucune distance à calculer.
_MARK_BOX = (MARK_WAVE[0] - 3, MARK_WAVE[1] - 4, MARK_WAVE[0] + MARK_WAVE[2] * MARK_WAVE[4] + 3, MARK_DOT[1] + 4)


def render_tile(size: int, *, inset: float = 0, rounded: bool = True, background: str | None = None) -> list[bytes]:
    """Lignes RGB(A) d'une tuile `brand` avec le symbole.

    rounded : coins de la charte, sinon carré plein (iOS arrondit lui-même).
    background : couleur opaque sous la tuile (RGB), sinon transparent (RGBA).
    """
    tile = size - 2 * inset
    unit = tile / 48  # pixels par unité de la boîte
    radius = MARK_TILE_RADIUS * unit if rounded else 0
    brand, white, accent = rgb(BRAND), rgb(ON_BRAND), rgb(ACCENT)
    under = rgb(background) if background else None
    bx0, by0, bx1, by1 = _MARK_BOX
    rows = []
    for j in range(size):
        row = bytearray()
        for i in range(size):
            x, y = i + 0.5, j + 0.5
            tile_alpha = coverage(rounded_rect_distance(x, y, inset, inset, tile, radius)) if radius else 1.0
            color = list(brand)
            if tile_alpha > 0:
                mx, my = (x - inset) / unit, (y - inset) / unit
                if bx0 <= mx <= bx1 and by0 <= my <= by1:
                    color = mix(color, white, min(coverage(stroke_distance(mx, my) * unit), tile_alpha))
                    color = mix(color, accent, min(coverage(dot_distance(mx, my) * unit), tile_alpha))
            if under is not None:
                row += bytes(round(c) for c in mix(under, color, tile_alpha))
            else:
                row += bytes(round(c) for c in color) + bytes([round(255 * tile_alpha)])
        rows.append(bytes(row))
    return rows


def png(width: int, height: int, rows: list[bytes], *, alpha: bool) -> bytes:
    raw = b"".join(b"\x00" + row for row in rows)
    color_type = 6 if alpha else 2

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


# --- iOS -----------------------------------------------------------------


def ios_files() -> dict[Path, bytes]:
    files: dict[Path, bytes] = {}
    icons = XCASSETS / "AppIcon.appiconset"
    contents = json.loads((icons / "Contents.json").read_text(encoding="utf-8"))
    rendered: dict[int, bytes] = {}
    for image in contents["images"]:
        points = float(image["size"].split("x")[0])
        pixels = round(points * int(image["scale"].rstrip("x")))
        if pixels not in rendered:
            # Carré plein et opaque : l'App Store refuse la transparence, et iOS
            # applique lui-même ses coins arrondis.
            rendered[pixels] = png(pixels, pixels, render_tile(pixels, rounded=False, background=BRAND), alpha=False)
        files[icons / image["filename"]] = rendered[pixels]
    # Écran de lancement : tuile arrondie au centre ; le fond reste la couleur
    # nommée LaunchBackground (surface claire ou sombre, spec 001, CA29).
    launch = XCASSETS / "LaunchImage.imageset"
    for scale, name in ((1, "LaunchImage.png"), (2, "LaunchImage@2x.png"), (3, "LaunchImage@3x.png")):
        pixels = LAUNCH_SIZE * scale
        files[launch / name] = png(pixels, pixels, render_tile(pixels), alpha=True)
    text = re.sub(
        r'<image name="LaunchImage" width="\d+" height="\d+"/>',
        f'<image name="LaunchImage" width="{LAUNCH_SIZE}" height="{LAUNCH_SIZE}"/>',
        STORYBOARD.read_text(encoding="utf-8"),
    )
    files[STORYBOARD] = text.encode()
    return files


# --- Android -------------------------------------------------------------


def vector_mark(unit: float, ox: float, oy: float, color: str, accent: str) -> str:
    (sx, sy), (ex, ey) = MARK_STEM
    cx, cy, r = MARK_DOT
    x, y, rr = ox + cx * unit, oy + cy * unit, r * unit
    dot = f"M{x - rr:.3f},{y:.3f} a{rr:.3f},{rr:.3f} 0 1,0 {2 * rr:.3f},0 a{rr:.3f},{rr:.3f} 0 1,0 {-2 * rr:.3f},0 Z"
    stem = f"M{ox + sx * unit:.3f},{oy + sy * unit:.3f} L{ox + ex * unit:.3f},{oy + ey * unit:.3f}"
    width = f"{MARK_STROKE * unit:.3f}"
    stroke = (
        f'android:strokeColor="{color}" android:strokeWidth="{width}"\n'
        '        android:strokeLineJoin="round" android:strokeLineCap="round" android:fillColor="#00000000"'
    )
    return (
        f'    <path android:pathData="{wave_path(unit, ox, oy, ",")}" {stroke} />\n'
        f'    <path android:pathData="{stem}" {stroke} />\n'
        f'    <path android:pathData="{dot}" android:fillColor="{accent}" />\n'
    )


def vector(size: int, body: str) -> bytes:
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n' + GENERATED_XML
        + '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        f'    android:width="{size}dp" android:height="{size}dp"\n'
        f'    android:viewportWidth="{size}" android:viewportHeight="{size}">\n'
        + body + "</vector>\n"
    ).encode()


def styles(parent: str, splash: bool) -> bytes:
    splash_items = (
        "        <!-- Android 12 et plus : écran de lancement du système, fond surface (spec 001, CA29), logo au centre (spec 007, CA3). -->\n"
        '        <item name="android:windowSplashScreenBackground">@color/tidemark_surface</item>\n'
        '        <item name="android:windowSplashScreenAnimatedIcon">@drawable/ic_launcher_foreground</item>\n'
        '        <item name="android:windowSplashScreenIconBackgroundColor">@color/ic_launcher_background</item>\n'
        if splash else ""
    )
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n' + GENERATED_XML
        + "<resources>\n"
        "    <!-- Fenêtre pendant le démarrage du processus, jusqu'au premier rendu de Flutter. -->\n"
        f'    <style name="LaunchTheme" parent="@android:style/{parent}">\n'
        '        <item name="android:windowBackground">@drawable/launch_background</item>\n'
        + splash_items
        + "    </style>\n"
        "    <!-- Fenêtre derrière l'interface de Flutter. -->\n"
        f'    <style name="NormalTheme" parent="@android:style/{parent}">\n'
        '        <item name="android:windowBackground">@color/tidemark_surface</item>\n'
        "    </style>\n"
        "</resources>\n"
    ).encode()


def android_files() -> dict[Path, bytes]:
    files: dict[Path, bytes] = {}
    # Icônes historiques (avant Android 8) : tuile arrondie sur fond transparent.
    for folder, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        files[RES / f"mipmap-{folder}/ic_launcher.png"] = png(size, size, render_tile(size, inset=size / 24), alpha=True)

    # Premier plan de l'icône adaptative (108 dp, zone sûre de 66 dp) : la boîte
    # de 48 occupe la zone sûre ; sert aussi de version monochrome (icônes à
    # thème), où le système ne garde que la forme.
    unit = 66 / 48
    origin = (108 - 66) / 2
    files[RES / "drawable/ic_launcher_foreground.xml"] = vector(108, vector_mark(unit, origin, origin, ON_BRAND, ACCENT))

    # Logo de l'écran de lancement : tuile arrondie de LAUNCH_SIZE dp.
    s = LAUNCH_SIZE
    unit = s / 48
    r = MARK_TILE_RADIUS * unit
    tile = (
        f"M{r:.3f},0 H{s - r:.3f} A{r:.3f},{r:.3f} 0 0,1 {s},{r:.3f} "
        f"V{s - r:.3f} A{r:.3f},{r:.3f} 0 0,1 {s - r:.3f},{s} "
        f"H{r:.3f} A{r:.3f},{r:.3f} 0 0,1 0,{s - r:.3f} "
        f"V{r:.3f} A{r:.3f},{r:.3f} 0 0,1 {r:.3f},0 Z"
    )
    files[RES / "drawable/launch_logo.xml"] = vector(
        s, f'    <path android:pathData="{tile}" android:fillColor="{BRAND}" />\n' + vector_mark(unit, 0, 0, ON_BRAND, ACCENT)
    )
    launch = (
        '<?xml version="1.0" encoding="utf-8"?>\n' + GENERATED_XML
        + "<!-- Écran de lancement : fond surface de la charte (spec 001, CA29), logo au centre (spec 007, CA3). -->\n"
        '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <item android:drawable="@color/tidemark_surface" />\n'
        f'    <item android:width="{s}dp" android:height="{s}dp" android:gravity="center"\n'
        '        android:drawable="@drawable/launch_logo" />\n'
        "</layer-list>\n"
    ).encode()
    files[RES / "drawable/launch_background.xml"] = launch
    files[RES / "drawable-v21/launch_background.xml"] = launch

    files[RES / "mipmap-anydpi-v26/ic_launcher.xml"] = (
        '<?xml version="1.0" encoding="utf-8"?>\n' + GENERATED_XML
        + '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@drawable/ic_launcher_foreground" />\n'
        "</adaptive-icon>\n"
    ).encode()
    for folder, surface in (("values", SURFACE), ("values-night", SURFACE_DARK)):
        files[RES / folder / "colors.xml"] = (
            '<?xml version="1.0" encoding="utf-8"?>\n' + GENERATED_XML
            + "<!-- Couleurs de la charte utilisées hors de Flutter (écran de lancement, icône). -->\n"
            "<resources>\n"
            f'    <color name="tidemark_surface">{surface.upper()}</color>\n'
            f'    <color name="ic_launcher_background">{BRAND.upper()}</color>\n'
            "</resources>\n"
        ).encode()
    for folder, parent, splash in (
        ("values", "Theme.Light.NoTitleBar", False),
        ("values-night", "Theme.Black.NoTitleBar", False),
        ("values-v31", "Theme.Light.NoTitleBar", True),
        ("values-night-v31", "Theme.Black.NoTitleBar", True),
    ):
        files[RES / folder / "styles.xml"] = styles(parent, splash)
    return files


def all_files() -> dict[Path, bytes]:
    files = svg_files()
    files.update(ios_files())
    files.update(android_files())
    return files


def main(argv: list[str]) -> int:
    files = all_files()
    if "--check" in argv:
        stale = [p for p, data in files.items() if not p.exists() or p.read_bytes() != data]
        for path in stale:
            print(f"différent de sa génération : {path.relative_to(ROOT)}", file=sys.stderr)
        if stale:
            print("Relancer : python3 tool/generate_brand.py", file=sys.stderr)
        return 1 if stale else 0
    for path, data in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
