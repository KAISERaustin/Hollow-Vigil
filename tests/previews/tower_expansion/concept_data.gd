extends RefCounted

## Proposed identities and presentation only; deliberately outside live content.
const FAMILIES := [
	{"id": "ironspike", "name": "Ironspike", "role": "PIERCING LANES", "accent": "ede4c9", "summary": "A ballista that rewards lining up enemies.", "tradeoff": "Strong on straights; awkward at bends.", "l2": "Braced bow / pierces 4", "l3": "Siege frame / pierces 5", "branches": [
		{"id": "siegebreaker", "name": "Siegebreaker", "caption": "Heavy bolts / boss hunter"},
		{"id": "needle_battery", "name": "Needle Battery", "caption": "Three lanes / crowd coverage"}]},
	{"id": "moonwheel", "name": "Moonwheel", "role": "RETURNING BLADES", "accent": "93c9bc", "summary": "A crescent blade cuts out and back.", "tradeoff": "Needs two passes to earn its damage.", "l2": "Twin fork / quicker return", "l3": "Blade cradle / wider cut", "branches": [
		{"id": "reaper_wheel", "name": "Reaper Wheel", "caption": "Giant disc / long corridor"},
		{"id": "orbit_crown", "name": "Orbit Crown", "caption": "Orbiting blades / close defense"}]},
	{"id": "hex_lantern", "name": "Hex Lantern", "role": "TEAM DAMAGE SUPPORT", "accent": "c28cab", "summary": "Marks enemies so every tower hits harder.", "tradeoff": "Low damage alone; strongest in a cluster.", "l2": "Rune collar / stronger mark", "l3": "Hanging charms / two marks", "branches": [
		{"id": "oathbrand", "name": "Oathbrand", "caption": "One strong mark / focus fire"},
		{"id": "witchlight", "name": "Witchlight", "caption": "Spreading marks / wave support"}]},
	{"id": "caltrop_keep", "name": "Caltrop Keep", "role": "STORED ROAD TRAPS", "accent": "db8d73", "summary": "Banks caltrops before enemies arrive.", "tradeoff": "Needs preparation; traps expire unused.", "l2": "Iron braces / four traps", "l3": "Side magazines / five traps", "branches": [
		{"id": "dreadjaw", "name": "Dreadjaw", "caption": "Heavy jaw traps / burst ambush"},
		{"id": "scatterworks", "name": "Scatterworks", "caption": "Three-trap volleys / road coverage"}]}
]
