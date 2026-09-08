"""Build the shared, colored coin glyph. Requires fonttools."""
from pathlib import Path
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.colorLib.builder import buildCOLR, buildCPAL
from fontTools.ttLib import TTFont
import math

ROOT = Path(__file__).resolve().parents[1]
for family in ("Sans", "Serif"):
    source = TTFont(ROOT / f"assets/fonts/Noto{family}.ttf")
    units = source["head"].unitsPerEm
    ascent, descent = source["hhea"].ascent, source["hhea"].descent
    center = (ascent + descent) / 2
    glyphs = {}
    names = [".notdef", "coin", "outer", "fill", "rim", "inner", "diamond"]
    for name in names:
        pen = TTGlyphPen(None)
        radius = {"outer": .47, "fill": .41, "rim": .34, "inner": .31}.get(name)
        if radius:
            points = [(units * (.5 + radius * math.cos(i * math.tau / 96)),
                       center + units * radius * math.sin(i * math.tau / 96)) for i in range(96)]
        elif name == "diamond":
            points = [(units*.5, center+units*.19), (units*.61, center),
                      (units*.5, center-units*.19), (units*.39, center)]
        else:
            points = []
        if points:
            pen.moveTo(points[0])
            for point in points[1:]: pen.lineTo(point)
            pen.closePath()
        glyphs[name] = pen.glyph()
    font = FontBuilder(units, isTTF=True)
    font.setupGlyphOrder(names)
    font.setupCharacterMap({0xE000: "coin"})
    font.setupGlyf(glyphs)
    font.setupHorizontalMetrics({name: (units, getattr(glyphs[name], "xMin", 0)) for name in names})
    font.setupHorizontalHeader(ascent=ascent, descent=descent)
    font.setupOS2(sTypoAscender=ascent, sTypoDescender=descent,
                 usWinAscent=ascent, usWinDescent=-descent)
    font.setupNameTable({"familyName": f"Vigil Coin {family}", "styleName": "Regular"})
    font.setupPost()
    font.font["COLR"] = buildCOLR({"coin": [("outer", 0), ("fill", 1), ("rim", 0), ("inner", 1), ("diamond", 0)]})
    font.font["CPAL"] = buildCPAL([[(0, 0, 0, 1), (224/255, 181/255, 104/255, 1)]])
    font.save(ROOT / f"assets/fonts/VigilCoin{family}.ttf")
