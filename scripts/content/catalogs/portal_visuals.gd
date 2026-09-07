extends RefCounted

# Presentation assignments only. Shapes are reusable motifs, never enemy models.
const ORNAMENTS := {
	"basic": {"motif": "leaf", "color": "95aa83"},
	"fast": {"motif": "thorns", "color": "93c9bc"},
	"heavy": {"motif": "roots", "color": "95aa83"},
	"cinder_imp": {"motif": "ember", "color": "db8d73"},
	"lantern": {"motif": "lantern", "color": "e0b568"},
	"slag_golem": {"motif": "anvil", "color": "bb8c76"},
	"drowned_thrall": {"motif": "reeds", "color": "93c9bc"},
	"mire_wraith": {"motif": "shell", "color": "e8ddbd"},
	"bell_hulk": {"motif": "bell", "color": "96966f"},
	"blood_acolyte": {"motif": "crescent", "color": "ae879b"},
	"crescent_wisp": {"motif": "ribbons", "color": "c4b6b1"},
	"ruin_knight": {"motif": "sword", "color": "b49dcc"},
	"shade": {"motif": "shroud", "color": "9182ad"},
	"sentinel": {"motif": "shield", "color": "74798c"},
	"sepulcher": {"motif": "battlement", "color": "99948c"},
	"briarling": {"motif": "thorns", "color": "d8cead"},
	"veil_widow": {"motif": "veil", "color": "c4b6b1"},
	"coffinbound": {"motif": "coffin", "color": "a5aa73"}
}

const RATE_PARTS := ["foundation", "feet", "buttresses", "pillars", "lintel", "finials"]
const MOUNTS := [Vector2(0, -43), Vector2(-32, -13), Vector2(32, -13)]
const PIT_MOUNTS := [Vector2(0, -25), Vector2(-34, 0), Vector2(34, 0)]
