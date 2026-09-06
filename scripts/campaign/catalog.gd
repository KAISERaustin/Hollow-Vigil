extends RefCounted

const COUNT := 20
const MAX_HEALTH := 20
const BOARD := Rect2(-310, -660, 620, 800)
const CORE := Vector2(0, 80)
const CHAPTERS := [
	{"name": "The Overgrown Road", "style": "forest", "story": "The last sanctuary has gone dark. Carry its ember beyond the forest."},
	{"name": "The Ashen Fortress", "style": "ashen_forge", "story": "The old watchfires still burn, but something else tends them now."},
	{"name": "The Drowned Crypts", "style": "drowned_crypt", "story": "Beneath the flood, a bell calls the dead back to their posts."},
	{"name": "The Eclipsed Capital", "style": "bloodmoon_sanctuary", "story": "One flame remains between the kingdom and a night without end."}
]

# Each road is authored from its entrance to the same sanctuary. Wave groups are
# [enemy, count, lane, delay, interval]; there is no random map or wave selection.
const MISSIONS := [
	{"name": "A Single Ember", "brief": "Build beside the bend. Two towers can cover the same stretch of road.", "gold": 240, "pads": [5, 6, 9, 10, 13, 14],
	 "roads": [[[0,-610],[0,-450],[150,-450],[150,-150],[0,-150],[0,80]]],
	 "waves": [[["basic",8,0,0,1.8]], [["basic",12,0,0,1.4]], [["basic",10,0,0,1.1],["fast",4,0,14,1.8]]]},
	{"name": "Briar Bend", "brief": "The long hairpin rewards towers that can reach both sides.", "gold": 260, "pads": [1,2,5,6,9,10,13,14],
	 "roads": [[[-270,-600],[150,-600],[150,-300],[-150,-300],[-150,0],[0,0],[0,80]]],
	 "waves": [[["basic",12,0,0,1.3]], [["fast",10,0,0,1.5]], [["basic",18,0,0,0.7]], [["lantern",5,0,0,2.4],["fast",8,0,5,1.2]]]},
	{"name": "Pilgrim's Fork", "brief": "Two entrances meet halfway down. Defend the junction or divide your gold.", "gold": 300, "pads": [0,3,5,6,9,10,13,14],
	 "roads": [[[-150,-610],[-150,-300],[0,-300],[0,80]],[[150,-610],[150,-300],[0,-300],[0,80]]],
	 "waves": [[["basic",10,0,0,1.3]], [["fast",8,1,0,1.6]], [["basic",12,0,0,1],["basic",12,1,0,1]], [["lantern",6,0,0,2.5],["fast",10,1,2,1.1]]]},
	{"name": "The Old Watch", "brief": "Armored revenants lead the procession. Use an Obelisk for concentrated damage.", "gold": 400, "pads": [0,1,2,3,5,6,9,10,13,14],
	 "roads": [[[270,-600],[-150,-600],[-150,-450],[150,-450],[150,-150],[0,-150],[0,80]]],
	 "waves": [[["basic",16,0,0,0.9]], [["heavy",3,0,0,4],["basic",12,0,3,0.8]], [["fast",16,0,0,1]], [["heavy",5,0,0,3.5],["lantern",6,0,4,2]]]},
	{"name": "Rootbound Gate", "brief": "Break the Warden before it reaches the flame. Cinderfield burns its regrowing shield.", "gold": 1000, "pads": [0,1,2,3,4,5,6,7,8,9,10,11,13,14],
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
	{"name": "Three Tollgates", "brief": "Three entrances converge late. First targeting protects the flame under pressure.", "gold": 800, "pads": [0,1,2,3,5,6,9,10,13,14],
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
	 "waves": [[["lantern",24,0,0,0.9],["basic",36,2,0,0.5]], [["sentinel",10,0,0,2.5],["fast",24,1,4,0.8]], [["shade",20,1,0,1.3],["shade",20,2,0,1.3]], [["heavy",16,0,0,1.8],["sentinel",8,2,0,3]], [["lantern",24,1,0,1],["shade",24,0,0,1.1]], [["prior",1,0,0,1],["sentinel",8,2,5,3.5],["shade",18,1,8,1.5]]]}
]

static func level(index: int) -> Dictionary:
	if index < 0 or index >= COUNT:
		return {}
	var result: Dictionary = MISSIONS[index].duplicate(true)
	result.index = index
	result.chapter = index / 5
	result.style = CHAPTERS[index / 5].style
	result.reward = 35 + index * 4
	# The first chapter introduces shield counters with a gentler boss budget.
	result.tuning = {"bosses": {"warden": {"hp": 1800.0, "shield": 300.0, "regen_period": 12.0}}} if index == 4 else {}
	result.routes = []
	for road in result.roads:
		var path: Array[Vector2] = []
		for point in road:
			path.append(Vector2(point[0], point[1]))
		result.routes.append(path)
	result.sockets = []
	for socket_id in result.pads:
		result.sockets.append(socket(int(socket_id)))
	return result

static func socket(index: int) -> Dictionary:
	var column := index % 4
	var row := index / 4
	var region := Vector2i(-1 if column == 0 else (1 if column == 3 else 0), -2 if row == 0 else (-1 if row < 3 else 0))
	var pad := (1 if column in [0, 2] else 0) + (2 if row in [0, 2] else 0)
	return {"region": VigilWorld.key(region), "pad": pad, "position": VigilWorld.pad_position(VigilWorld.key(region), pad), "index": index}

static func wave_text(mission: Dictionary, wave: int) -> String:
	if wave >= mission.waves.size():
		return "All waves cleared"
	var parts: PackedStringArray = []
	for group in mission.waves[wave]:
		var definitions: Dictionary = Balance.BOSSES if Balance.BOSSES.has(group[0]) else Balance.ENEMIES
		parts.append("%d %s · %s" % [group[1], definitions[group[0]].name, String.chr(65 + int(group[2]))])
	return "\n".join(parts)
