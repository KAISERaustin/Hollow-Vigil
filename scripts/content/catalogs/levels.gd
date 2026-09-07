extends RefCounted

const STARTING_GOLD := 280.0 # First property and an opening defense.
const SESSION := {"name": "Starting resources", "starting_gold": STARTING_GOLD}
const CONFIGURATION_FIELDS := {
	"gold": {"label": "Starting gold", "min": 0.0, "max": 1000000000000.0, "step": 1.0},
	"flame": {"label": "Core integrity", "min": 1.0, "max": 10000.0, "step": 1.0, "integer": true},
	"reward": {"label": "Gold per cleared wave", "min": 0.0, "max": 1000000.0, "step": 1.0}
}
const GROUP_FIELDS := {
	1: {"label": "Enemy count", "min": 1, "max": 1000, "step": 1, "integer": true},
	2: {"label": "Entrance lane (0 = A)", "min": 0, "max": 31, "step": 1, "integer": true},
	3: {"label": "Spawn delay (seconds)", "min": 0, "max": 3600, "step": 0.1},
	4: {"label": "Spawn interval (seconds)", "min": 0.05, "max": 120, "step": 0.05}
}
const LEGACY_COUNT := 20
const LEVELS_PER_CHAPTER := 5
const MAX_HEALTH := 3
const BOARD := Rect2(-310, -660, 620, 800)
const CORE := Vector2(0, 80)
const CHAPTERS := [
	{"name": "The Overgrown Road", "map_art": preload("res://assets/campaign/overgrown-road.svg"), "gate_art": preload("res://assets/campaign/overgrown-road-gate.svg"), "style": "forest", "story": "The last sanctuary has gone dark. Carry its ember beyond the forest."},
	{"name": "The Ashen Fortress", "map_art": preload("res://assets/campaign/ashen-fortress.svg"), "gate_art": preload("res://assets/campaign/ashen-fortress-gate.svg"), "style": "ashen_forge", "story": "The old watchfires still burn, but something else tends them now."},
	{"name": "The Drowned Crypts", "map_art": preload("res://assets/campaign/drowned-crypts.svg"), "gate_art": preload("res://assets/campaign/drowned-crypts-gate.svg"), "style": "drowned_crypt", "story": "Beneath the flood, a bell calls the dead back to their posts."},
	{"name": "The Eclipsed Capital", "map_art": preload("res://assets/campaign/eclipsed-capital.svg"), "gate_art": preload("res://assets/campaign/eclipsed-capital-gate.svg"), "style": "bloodmoon_sanctuary", "story": "One core stands between the kingdom and a night without end."},
	{"name": "Castle Ruin", "style": "castle_ruin", "story": "Beyond the capital, the fallen king still guards a crown of broken stone."},
	{"name": "Mourning Orchard", "style": "mourning_orchard", "story": "Carry the rekindled ember beneath the funeral boughs. The last procession waits among the roots."}
]
# CHAPTERS contains preloaded textures, so its size cannot be constant-folded.
const COUNT := 6 * LEVELS_PER_CHAPTER

# Each road is authored from its entrance to the same sanctuary. Wave groups are
# [enemy, count, lane, delay, interval]; there is no random map or wave selection.
const MISSIONS := [
	{"name": "A Single Ember", "brief": "Build beside the bend. Two towers can cover the same stretch of road.", "gold": 240, "pads": [5, 6, 9, 10, 13, 14],
	 "roads": [[[0,-610],[0,-450],[150,-450],[150,-150],[0,-150],[0,80]]],
	 "waves": [[["basic",8,0,0,1.8]], [["basic",12,0,0,1.4]], [["basic",10,0,0,1.1],["fast",4,0,14,1.8]]]},
	{"name": "Briar Bend", "brief": "", "gold": 260, "pads": [1,2,5,6,9,10,13,14],
	 "roads": [[[-270,-600],[150,-600],[150,-300],[-150,-300],[-150,0],[0,0],[0,80]]],
	 "waves": [[["basic",12,0,0,1.3]], [["fast",10,0,0,1.5]], [["basic",18,0,0,0.7]], [["lantern",5,0,0,2.4],["fast",8,0,5,1.2]]]},
	{"name": "Pilgrim's Fork", "brief": "Two entrances meet halfway down. Defend the junction or divide your gold.", "gold": 300, "pads": [0,3,5,6,9,10,13,14],
	 "roads": [[[-150,-610],[-150,-300],[0,-300],[0,80]],[[150,-610],[150,-300],[0,-300],[0,80]]],
	 "waves": [[["basic",10,0,0,1.3]], [["fast",8,1,0,1.6]], [["basic",12,0,0,1],["basic",12,1,0,1]], [["lantern",6,0,0,2.5],["fast",10,1,2,1.1]]]},
	{"name": "The Old Watch", "brief": "Armored revenants lead the procession. Use an Obelisk for concentrated damage.", "gold": 400, "pads": [0,1,2,3,5,6,9,10,13,14],
	 "roads": [[[270,-600],[-150,-600],[-150,-450],[150,-450],[150,-150],[0,-150],[0,80]]],
	 "waves": [[["basic",16,0,0,0.9]], [["heavy",3,0,0,4],["basic",12,0,3,0.8]], [["fast",16,0,0,1]], [["heavy",5,0,0,3.5],["lantern",6,0,4,2]]]},
	{"name": "Rootbound Gate", "brief": "Break the Warden before it reaches the core. Cinderfield burns through its root shield.", "gold": 1000, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[-270,-600],[150,-600],[150,-450],[-150,-450],[-150,-150],[150,-150],[150,0],[0,0],[0,80]]],
	 "waves": [[["basic",20,0,0,0.7]], [["heavy",5,0,0,3],["fast",12,0,5,1]], [["lantern",12,0,0,1.8]], [["warden",1,0,0,1],["basic",20,0,6,0.9]]]},
	{"name": "Cinder Causeway", "brief": "Forged enemies have 25% more health. Upgrade a strong firing position early.", "gold": 450, "pads": [0,1,2,3,5,6,9,10,13,14],
	 "roads": [[[0,-610],[0,-600],[-150,-600],[-150,-150],[150,-150],[150,0],[0,0],[0,80]]],
	 "waves": [[["basic",18,0,0,0.9]], [["lantern",10,0,0,1.8]], [["heavy",6,0,0,3],["fast",14,0,4,1]], [["lantern",14,0,0,1.2],["heavy",4,0,5,3]]]},
	{"name": "Twin Furnaces", "brief": "Attacks alternate between the furnaces before both ignite together.", "gold": 500, "pads": [0,1,2,3,5,6,9,10,13,14],
	 "roads": [[[-270,-550],[-150,-550],[-150,-150],[0,-150],[0,80]],[[270,-550],[150,-550],[150,-150],[0,-150],[0,80]]],
	 "waves": [[["basic",20,0,0,0.8]], [["lantern",10,1,0,1.7]], [["fast",14,0,0,1],["fast",14,1,0,1]], [["heavy",5,0,0,3],["lantern",12,1,2,1.5]]]},
	{"name": "Ashen Switchback", "brief": "Dense packs fill the switchback. Pyres and Stormspires reward patient placement.", "gold": 520, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[270,-600],[-150,-600],[-150,-450],[150,-450],[150,-300],[-150,-300],[-150,0],[0,0],[0,80]]],
	 "waves": [[["basic",32,0,0,0.45]], [["fast",24,0,0,0.65]], [["lantern",18,0,0,1]], [["heavy",8,0,0,2.2],["basic",30,0,3,0.45]], [["lantern",20,0,0,0.9],["fast",16,0,8,0.6]]]},
	{"name": "The Breach", "brief": "A side gate bypasses the outer defenses. Keep gold for the short eastern road.", "gold": 580, "pads": [0,1,2,3,5,6,7,9,10,11,13,14],
	 "roads": [[[-270,-600],[150,-600],[150,-300],[-150,-300],[-150,0],[0,0],[0,80]],[[270,-300],[0,-300],[0,80]]],
	 "waves": [[["lantern",14,0,0,1.4]], [["basic",26,0,0,0.6],["fast",10,1,4,1.2]], [["heavy",8,0,0,2.5]], [["lantern",12,1,0,1.8],["fast",20,0,0,0.8]], [["heavy",6,0,0,3],["lantern",14,1,4,1.5]]]},
	{"name": "The Living Furnace", "brief": "The Reliquary accelerates at half health. Frostneedle suppresses its rush.", "gold": 850, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[0,-610],[150,-610],[150,-450],[-150,-450],[-150,-150],[150,-150],[150,0],[0,0],[0,80]], [[-270,-300],[0,-300],[0,80]]],
	 "waves": [[["basic",30,0,0,0.55]], [["heavy",8,0,0,2.5],["fast",12,1,4,1.1]], [["lantern",16,0,0,1.1],["basic",20,1,2,0.8]], [["heavy",10,0,0,2]], [["cindermaw",1,0,0,1],["fast",20,1,5,1.1]]]},
	{"name": "Sunken Steps", "brief": "Drowned enemies move 15% faster. Cover the exit as well as the entrance.", "gold": 600, "pads": [0,1,2,3,5,6,9,10,13,14],
	 "roads": [[[-150,-610],[-150,-450],[0,-450],[0,-300],[150,-300],[150,0],[0,0],[0,80]]],
	 "waves": [[["fast",24,0,0,0.8]], [["lantern",18,0,0,1.2]], [["shade",8,0,0,2]], [["heavy",8,0,0,2.5],["fast",20,0,5,0.8]], [["shade",14,0,0,1.5],["lantern",12,0,3,1.4]]]},
	{"name": "Tombwater Crossing", "brief": "Two routes cross without changing lanes. Towers at the crossing reach both.", "gold": 650, "pads": [0,1,2,3,4,5,6,7,9,10,13,14],
	 "roads": [[[-150,-610],[-150,-450],[0,-450],[0,-150],[150,-150],[150,0],[0,0],[0,80]],[[150,-610],[150,-300],[-150,-300],[-150,0],[0,0],[0,80]]],
	 "waves": [[["basic",24,0,0,0.6],["fast",12,1,3,1]], [["shade",8,1,0,2],["lantern",14,0,0,1.3]], [["fast",24,0,0,0.7],["fast",24,1,0,0.7]], [["sentinel",4,0,0,4],["shade",12,1,2,1.8]], [["shade",14,0,0,1.4],["lantern",20,1,0,1]]]},
	{"name": "The Long Descent", "brief": "Crypt Sentinels endure light fire. Invest in heavy towers and long sightlines.", "gold": 720, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[270,-610],[-150,-610],[-150,-450],[150,-450],[150,-150],[-150,-150],[-150,0],[0,0],[0,80]]],
	 "waves": [[["lantern",20,0,0,1]], [["sentinel",6,0,0,3.5]], [["shade",18,0,0,1.1]], [["sentinel",8,0,0,3],["basic",36,0,4,0.45]], [["sentinel",10,0,0,2.8],["shade",16,0,5,1.1]]]},
	{"name": "Three Tollgates", "brief": "Three entrances converge late. First targeting protects core integrity under pressure.", "gold": 800, "pads": [0,1,2,3,5,6,9,10,13,14],
	 "roads": [[[-150,-610],[-150,0],[0,0],[0,80]],[[0,-610],[0,80]],[[150,-610],[150,0],[0,0],[0,80]]],
	 "waves": [[["basic",20,0,0,0.7],["basic",20,2,0,0.7]], [["shade",10,1,0,1.7]], [["fast",18,0,0,0.8],["fast",18,1,4,0.8],["fast",18,2,8,0.8]], [["sentinel",6,0,0,3],["lantern",16,2,0,1.1]], [["shade",12,0,0,1.5],["sentinel",5,1,2,3.5],["shade",12,2,0,1.5]]]},
	{"name": "The Bell Below", "brief": "The Bell summons escorts along its route. Thunderseal interrupts its toll.", "gold": 1000, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[-270,-610],[150,-610],[150,-450],[-150,-450],[-150,-300],[150,-300],[150,0],[0,0],[0,80]],[[270,-450],[0,-450],[0,80]]],
	 "waves": [[["lantern",24,0,0,0.9]], [["shade",14,1,0,1.5],["basic",30,0,2,0.5]], [["sentinel",8,0,0,3]], [["shade",18,0,0,1.2],["fast",24,1,0,0.8]], [["bell",1,0,0,1],["sentinel",6,0,5,4],["lantern",18,1,7,1.4]]]},
	{"name": "Bloodmoon Avenue", "brief": "Enemies recover 1% of their maximum health each second. Concentrate your damage.", "gold": 800, "pads": [0,1,2,3,5,6,9,10,13,14],
	 "roads": [[[150,-610],[150,-450],[-150,-450],[-150,-150],[0,-150],[0,80]]],
	 "waves": [[["lantern",22,0,0,1]], [["sentinel",8,0,0,3]], [["shade",20,0,0,1.1]], [["heavy",14,0,0,1.8],["fast",24,0,4,0.7]], [["sentinel",12,0,0,2.5],["shade",16,0,3,1.3]]]},
	{"name": "Broken Crown", "brief": "A long western route and a short eastern route demand different investments.", "gold": 900, "pads": [0,1,2,3,5,6,7,9,10,11,13,14],
	 "roads": [[[-270,-600],[150,-600],[150,-450],[-150,-450],[-150,0],[0,0],[0,80]],[[270,-300],[150,-300],[150,0],[0,0],[0,80]]],
	 "waves": [[["heavy",10,0,0,2.5]], [["lantern",16,1,0,1.5],["basic",30,0,0,0.5]], [["shade",20,0,0,1.1],["fast",20,1,5,0.9]], [["sentinel",10,0,0,2.5],["lantern",18,1,4,1.4]], [["shade",18,1,0,1.3],["sentinel",10,0,0,3]]]},
	{"name": "The Silent Court", "brief": "Three fronts test your specializations. Preview each wave before committing gold.", "gold": 1000, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[-270,-550],[-150,-550],[-150,-150],[0,-150],[0,80]],[[0,-610],[0,-300],[150,-300],[150,0],[0,0],[0,80]],[[270,-550],[150,-550],[150,-450],[0,-450],[0,80]]],
	 "waves": [[["lantern",18,0,0,1.2],["basic",30,2,0,0.6]], [["sentinel",8,1,0,3],["fast",20,0,4,0.8]], [["shade",14,0,0,1.4],["shade",14,2,0,1.4]], [["heavy",12,0,0,2],["lantern",20,1,0,1],["fast",24,2,3,0.7]], [["sentinel",8,0,0,3],["shade",18,1,0,1.3],["sentinel",6,2,4,3.5]]]},
	{"name": "Nightfall Bastion", "brief": "The final approach mixes crowds with armored escorts. Save a reserve for the last wave.", "gold": 1050, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[0,-610],[-150,-610],[-150,-450],[150,-450],[150,-300],[-150,-300],[-150,0],[0,0],[0,80]],[[270,-600],[150,-600],[150,-150],[0,-150],[0,80]]],
	 "waves": [[["basic",40,0,0,0.4],["lantern",20,1,0,1]], [["sentinel",10,0,0,2.5]], [["shade",22,1,0,1.1],["fast",30,0,0,0.6]], [["heavy",16,0,0,1.6],["lantern",24,1,0,1]], [["sentinel",10,0,0,2.5],["shade",20,1,0,1.2]], [["sentinel",8,1,0,3],["shade",26,0,3,1]]]},
	{"name": "The Last Vigil", "brief": "Defeat the Eclipse Prior and relight the capital. Doomstone pierces its renewing wards.", "gold": 1500, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[-270,-610],[150,-610],[150,-450],[-150,-450],[-150,-150],[150,-150],[150,0],[0,0],[0,80]],[[270,-450],[150,-450],[150,-300],[0,-300],[0,80]],[[0,-610],[0,-450],[-150,-450],[-150,0],[0,0],[0,80]]],
	 "waves": [[["lantern",24,0,0,0.9],["basic",36,2,0,0.5]], [["sentinel",10,0,0,2.5],["fast",24,1,4,0.8]], [["shade",20,1,0,1.3],["shade",20,2,0,1.3]], [["heavy",16,0,0,1.8],["sentinel",8,2,0,3]], [["lantern",24,1,0,1],["shade",24,0,0,1.1]], [["prior",1,0,0,1],["sentinel",8,2,5,3.5],["shade",18,1,8,1.5]]]},
	{"name": "The Fallen Portcullis", "brief": "Castle sentinels endure light fire. Build a lasting defense along the inner wall.", "gold": 1600, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[-270,-610],[-150,-610],[-150,-450],[150,-450],[150,-300],[-150,-300],[-150,-150],[0,-150],[0,80]]],
	 "waves": [[["shade",16,0,0,1.2]], [["sentinel",8,0,0,3]], [["shade",24,0,0,0.8]], [["sepulcher",2,0,0,6],["sentinel",8,0,3,2.8]], [["sentinel",12,0,0,2.5],["shade",24,0,4,0.9]]]},
	{"name": "Courtyard of Echoes", "brief": "Two stairways meet at the courtyard. Cover both approaches before the procession divides.", "gold": 1700, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[-270,-600],[-150,-600],[-150,-300],[150,-300],[150,-150],[0,-150],[0,80]],[[270,-600],[150,-600],[150,-450],[-150,-450],[-150,-150],[0,-150],[0,80]]],
	 "waves": [[["shade",18,0,0,1.2],["shade",12,1,4,1.4]], [["sentinel",6,0,0,3],["sentinel",6,1,3,3]], [["shade",24,1,0,0.8]], [["sepulcher",2,0,0,6],["shade",20,1,4,1]], [["sentinel",10,0,0,2.6],["sentinel",8,1,4,2.8]]]},
	{"name": "Shattered Ramparts", "brief": "The rampart road doubles back through the ruins. Heavy towers can strike the same formation twice.", "gold": 1800, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[270,-610],[150,-610],[150,-600],[-150,-600],[-150,-450],[150,-450],[150,-300],[-150,-300],[-150,0],[0,0],[0,80]]],
	 "waves": [[["sentinel",10,0,0,2.8]], [["shade",32,0,0,0.7]], [["sepulcher",3,0,0,5]], [["sentinel",14,0,0,2.4],["shade",20,0,6,0.9]], [["sepulcher",4,0,0,4.5],["sentinel",10,0,3,2.8]]]},
	{"name": "The Empty Throne", "brief": "A passage beneath the throne opens close to home. Reserve a defense for the eastern entrance.", "gold": 1900, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[-150,-610],[-150,-600],[150,-600],[150,-450],[-150,-450],[-150,-150],[0,-150],[0,80]],[[270,-450],[150,-450],[150,-150],[0,-150],[0,80]]],
	 "waves": [[["sentinel",12,0,0,2.6]], [["shade",20,1,0,1]], [["sepulcher",3,0,0,5],["sentinel",6,1,5,3]], [["shade",24,0,0,0.8],["shade",24,1,2,0.9]], [["sepulcher",4,0,0,5],["sentinel",10,1,6,3]]]},
	{"name": "The Ruined King", "brief": "Break the king's stone body with sustained heavy damage. His guards arrive from the eastern stair.", "gold": 2100, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[0,-610],[-150,-610],[-150,-450],[150,-450],[150,-300],[-150,-300],[-150,-150],[150,-150],[150,0],[0,0],[0,80]],[[270,-600],[150,-600],[150,-450],[0,-450],[0,80]]],
	 "waves": [[["shade",28,0,0,0.9]], [["sentinel",12,0,0,2.6],["shade",16,1,3,1.2]], [["sepulcher",4,0,0,5]], [["sentinel",14,0,0,2.4],["sentinel",8,1,4,3]], [["ruined_king",1,0,0,1],["shade",24,1,8,1.2]]]},
	{"name": "Pale Boughs", "brief": "The orchard's funeral road winds beneath pale roots. Prepare for a new procession.", "gold": 1800, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[150,-610],[150,-600],[-150,-600],[-150,-300],[150,-300],[150,-150],[0,-150],[0,80]]],
	 "waves": [[["briarling",18,0,0,1.4]], [["veil_widow",20,0,0,1.2]], [["coffinbound",6,0,0,3.5]], [["briarling",28,0,0,0.9],["veil_widow",14,0,6,1.1]], [["coffinbound",10,0,0,3],["veil_widow",20,0,4,1.2]]]},
	{"name": "The Divided Wake", "brief": "Two funeral roads converge beneath the boughs. Spread your opening defense across both lanes.", "gold": 1900, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[-270,-550],[-150,-550],[-150,-300],[0,-300],[0,-150],[150,-150],[150,0],[0,0],[0,80]],[[270,-550],[150,-550],[150,-300],[0,-300],[0,-150],[-150,-150],[-150,0],[0,0],[0,80]]],
	 "waves": [[["briarling",20,0,0,1.2]], [["veil_widow",22,1,0,1.1]], [["coffinbound",6,0,0,3.5],["briarling",20,1,4,1.2]], [["veil_widow",22,0,0,1],["veil_widow",22,1,3,1]], [["coffinbound",8,0,0,3],["coffinbound",8,1,4,3]]]},
	{"name": "Roots of Remembrance", "brief": "The oldest roots force a long turn. Slowing attacks keep the procession within your strongest towers' reach.", "gold": 2000, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[-270,-600],[-150,-600],[-150,-450],[150,-450],[150,-150],[-150,-150],[-150,0],[0,0],[0,80]]],
	 "waves": [[["briarling",30,0,0,0.9]], [["coffinbound",10,0,0,3]], [["veil_widow",32,0,0,0.8]], [["coffinbound",12,0,0,2.8],["briarling",24,0,5,0.9]], [["coffinbound",16,0,0,2.6],["veil_widow",24,0,8,1]]]},
	{"name": "The Last Lanterns", "brief": "Three processions approach the final grove. Keep your late upgrades close to the core.", "gold": 2300, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[-150,-610],[-150,-450],[0,-450],[0,-300],[-150,-300],[-150,0],[0,0],[0,80]],[[0,-610],[0,-600],[150,-600],[150,-150],[0,-150],[0,80]],[[270,-450],[150,-450],[150,-300],[0,-300],[0,80]]],
	 "waves": [[["briarling",20,0,0,1.2],["briarling",16,2,4,1.4]], [["veil_widow",24,1,0,1]], [["coffinbound",8,0,0,3],["veil_widow",20,2,4,1.2]], [["briarling",22,0,0,1],["briarling",22,1,2,1],["veil_widow",18,2,6,1.1]], [["coffinbound",10,0,0,3],["coffinbound",8,1,4,3],["briarling",20,2,8,1.2]]]},
	{"name": "The Mourning Matriarch", "brief": "Slow the Matriarch beneath the funeral boughs and focus your strongest towers on her final approach.", "gold": 2500, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
	 "roads": [[[270,-610],[-150,-610],[-150,-450],[150,-450],[150,-300],[-150,-300],[-150,-150],[150,-150],[150,0],[0,0],[0,80]], [[-270,-450],[-150,-450],[-150,-300],[0,-300],[0,80]]],
	 "waves": [[["briarling",30,0,0,1]], [["coffinbound",12,0,0,3],["veil_widow",20,1,4,1.2]], [["veil_widow",32,0,0,0.9],["briarling",24,1,6,1.1]], [["coffinbound",16,0,0,2.8],["veil_widow",24,1,4,1.1]], [["mourning_matriarch",1,0,0,1],["coffinbound",8,0,8,3.5],["briarling",24,1,10,1.2]]]}
]
