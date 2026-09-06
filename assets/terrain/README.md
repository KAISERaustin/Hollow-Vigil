# Unknown territory clouds

`unknown-clouds.png` was generated with the built-in imagegen tool. It is an
opaque fog texture; `scripts/rendering/terrain_clouds.gd` mirrors it across
world-aligned cells below owned terrain and the existing black grid. Only
visible cells are drawn. Expansion reveals terrain through the existing chunk
system, without new save state. Mipmaps keep the artwork readable when zoomed out.
The renderer applies a dark slate tint. `terrain_cloud_edges.gd` adds a roughly
7–21 world-pixel scalloped fringe with a crisp dark closing outline into explored boundary
cells; edges between two explored cells remain clear.

## Generation prompt

Use case: stylized-concept. Create a production square opaque fog-of-war cloud texture for the unknown map tiles in Hollow Vigil, a minimalist 2D dark-fantasy boardlike tower defense game. Art direction: flat filled shapes, strong clean near-black outlines, restrained muted pastel palette, simple graphic silhouettes like paper cutout cartoon ghosts and angular pastel towers. Full-bleed square overhead dense cloud bank filling EVERY pixel, no visible ground, no background gaps, no transparency. Layer 6-9 broad overlapping rounded cloud billows with a few elegant curled contour lines and flat two-tone cel shadows. Palette: dusky desaturated blue slate #687989 shadows, muted blue-lilac #909eae body, pale mist #bac5cb restrained highlights, outline #222a30. Keep contrast lower than black-outlined game characters. Mysterious hidden territory, soft inviting shapes, no faces or objects. Large readable forms at 300px gameplay tile size. Seamless repeatable texture with matching opposite edges; billows cut through all four boundaries. Avoid border, tile frame, grid, text, symbols, stars, scenery, gradients, photorealism, 3D, grain, fine detail, white fluffy bright sky clouds. Output one square texture image.
