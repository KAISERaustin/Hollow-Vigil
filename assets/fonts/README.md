# UI fonts

Hollow Vigil bundles unmodified variable Grenze and Cinzel fonts from Google's font repository. UI roles select regular 400, semibold 600, and bold 700 weights at runtime. Grenze supplies medieval body text, controls and numbers; Cinzel supplies major titles. Both are bundled locally for offline mobile use.

- Grenze: https://github.com/google/fonts/tree/main/ofl/grenze
- Cinzel: https://github.com/google/fonts/tree/main/ofl/cinzel
- Retrieved September 16, 2026.

Noto Sans and Noto Serif remain glyph-coverage fallbacks and sources for the generated VigilCoin fonts. The coin fallback is tried before Noto; shared text keeps tabular figures enabled.

- Noto Sans: https://github.com/google/fonts/tree/main/ofl/notosans
- Noto Serif: https://github.com/google/fonts/tree/main/ofl/notoserif
- Retrieved September 5, 2026.

Each font is distributed under the SIL Open Font License included beside it. Export presets include `assets/fonts/*-OFL.txt` so license notices accompany the font resources in shipped packages.
