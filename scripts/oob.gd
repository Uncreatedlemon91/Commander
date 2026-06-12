extends RefCounted
class_name OOB

# Order of Battle for the Battle of Austerlitz (2 December 1805) — French vs the
# Russo-Austrian army — organised into BRIGADES (corps/columns) with their
# historical commanders. A player commands one brigade; the AI runs the rest.
#
# Deployment (west = French, east = Allied):
#   - French right (south) thin under Davout; centre Soult facing the Pratzen
#     Heights; left (north) Lannes + Murat by the Santon. Guard/Bernadotte/
#     Oudinot in reserve.
#   - Allies massed on their left (south: Dokhturov/Langeron/Przybyszewski) to
#     roll up the French right; Kollowrat on the Pratzen; Bagration + Liechtenstein
#     north; Russian Guard in reserve.
#
# NOTE: corps/columns and commanders are historical; battalion designations are
# representative. Extend by editing BRIGADES.

const BRIGADES := [
	# French (team 0)
	{ "id": 0,  "short": "Davout",       "name": "Davout — III Corps (French)",          "team": 0, "hq": [-460, 360],  "inf": 3, "cav": 0, "art": 1 },
	{ "id": 1,  "short": "Soult",        "name": "Soult — IV Corps (French)",            "team": 0, "hq": [-360, 40],   "inf": 5, "cav": 0, "art": 1 },
	{ "id": 2,  "short": "Bernadotte",   "name": "Bernadotte — I Corps (French)",        "team": 0, "hq": [-560, -150], "inf": 4, "cav": 0, "art": 0 },
	{ "id": 3,  "short": "Lannes",       "name": "Lannes — V Corps (French)",            "team": 0, "hq": [-520, -380], "inf": 4, "cav": 0, "art": 1 },
	{ "id": 4,  "short": "Murat",        "name": "Murat — Cavalry Reserve (French)",     "team": 0, "hq": [-680, -280], "inf": 0, "cav": 5, "art": 0 },
	{ "id": 5,  "short": "Guard",        "name": "Imperial Guard — Bessières (French)",  "team": 0, "hq": [-700, 40],   "inf": 2, "cav": 1, "art": 1 },
	{ "id": 6,  "short": "Oudinot",      "name": "Oudinot — Grenadiers (French)",        "team": 0, "hq": [-700, 190],  "inf": 3, "cav": 0, "art": 0 },
	# Allied (team 1)
	{ "id": 7,  "short": "Dokhturov",    "name": "Dokhturov — I Column (Allied)",        "team": 1, "hq": [480, 470],  "inf": 4, "cav": 0, "art": 0 },
	{ "id": 8,  "short": "Langeron",     "name": "Langeron — II Column (Allied)",        "team": 1, "hq": [470, 330],  "inf": 4, "cav": 0, "art": 1 },
	{ "id": 9,  "short": "Przybyszewski","name": "Przybyszewski — III Column (Allied)",  "team": 1, "hq": [400, 200],  "inf": 4, "cav": 0, "art": 0 },
	{ "id": 10, "short": "Kollowrat",    "name": "Kollowrat–Miloradovich — IV Column (Allied)", "team": 1, "hq": [300, 20], "inf": 5, "cav": 0, "art": 1 },
	{ "id": 11, "short": "RussGuard",    "name": "Russian Imperial Guard — Constantine (Allied)", "team": 1, "hq": [680, 40], "inf": 3, "cav": 1, "art": 1 },
	{ "id": 12, "short": "Liechtenstein","name": "Liechtenstein — Cavalry (Allied)",     "team": 1, "hq": [620, -240], "inf": 0, "cav": 5, "art": 0 },
	{ "id": 13, "short": "Bagration",    "name": "Bagration — Advance Guard (Allied)",   "team": 1, "hq": [520, -380], "inf": 3, "cav": 1, "art": 1 },
	# Additional French formations
	{ "id": 14, "short": "Vandamme",     "name": "Vandamme — IV Corps (French)",         "team": 0, "hq": [-300, -460], "inf": 4, "cav": 0, "art": 0 },
	{ "id": 15, "short": "St-Hilaire",   "name": "Saint-Hilaire — IV Corps (French)",    "team": 0, "hq": [-300, 280],  "inf": 4, "cav": 0, "art": 1 },
	{ "id": 16, "short": "Nansouty",     "name": "Nansouty — Heavy Cavalry (French)",    "team": 0, "hq": [-820, -160], "inf": 0, "cav": 5, "art": 0 },
	# Additional Allied formations
	{ "id": 17, "short": "Kienmayer",    "name": "Kienmayer — Advance Guard (Allied)",   "team": 1, "hq": [300, -460], "inf": 3, "cav": 1, "art": 0 },
	{ "id": 18, "short": "Buxhowden",    "name": "Buxhöwden — Left Wing (Allied)",       "team": 1, "hq": [300, 460],  "inf": 4, "cav": 0, "art": 1 },
	{ "id": 19, "short": "Uvarov",       "name": "Uvarov — Cavalry (Allied)",            "team": 1, "hq": [820, -160], "inf": 0, "cav": 5, "art": 0 },
]

const SPREAD := 70.0

# Higher command: brigades grouped into DIVISIONS (each belongs to its team's
# Corps). The AI Corps assigns each division a mission; the division sets a
# stance for its brigades. role: "main" | "reserve".
const DIVISIONS := [
	{ "id": 0, "team": 0, "role": "main",    "brigades": [0] },        # Davout — right
	{ "id": 1, "team": 0, "role": "main",    "brigades": [1, 5] },     # Soult + Guard — centre
	{ "id": 2, "team": 0, "role": "main",    "brigades": [3, 4] },     # Lannes + Murat — left
	{ "id": 3, "team": 0, "role": "reserve", "brigades": [2, 6] },     # Bernadotte + Oudinot
	{ "id": 4, "team": 1, "role": "main",    "brigades": [7, 8] },     # Dokhturov + Langeron — south
	{ "id": 5, "team": 1, "role": "main",    "brigades": [9, 10] },    # Przybyszewski + Kollowrat — centre
	{ "id": 6, "team": 1, "role": "main",    "brigades": [12, 13] },   # Liechtenstein + Bagration — north
	{ "id": 7, "team": 1, "role": "reserve", "brigades": [11] },       # Russian Guard
	{ "id": 8,  "team": 0, "role": "main",    "brigades": [14, 15] },  # Vandamme + St-Hilaire
	{ "id": 9,  "team": 0, "role": "main",    "brigades": [16] },      # Nansouty (heavy cav)
	{ "id": 10, "team": 1, "role": "main",    "brigades": [17, 18] },  # Kienmayer + Buxhöwden
	{ "id": 11, "team": 1, "role": "main",    "brigades": [19] },      # Uvarov (cav)
]

static func brigade_team(brigade_id: int) -> int:
	for b in BRIGADES:
		if b["id"] == brigade_id:
			return b["team"]
	return 0

static func brigade_name(brigade_id: int) -> String:
	for b in BRIGADES:
		if b["id"] == brigade_id:
			return b["name"]
	return "Brigade"

static func brigade_ids() -> Array:
	var out: Array = []
	for b in BRIGADES:
		out.append(b["id"])
	return out

static func build_battalions() -> Array:
	var out: Array = []
	var bid := 0
	for br in BRIGADES:
		var specs: Array = []
		for i in range(br["inf"]):
			specs.append("infantry")
		for i in range(br["cav"]):
			specs.append("cavalry")
		for i in range(br["art"]):
			specs.append("artillery")
		var n := specs.size()
		var quality := "line"
		if br["short"] == "Guard" or br["short"] == "RussGuard":
			quality = "guard"
		elif br["cav"] > 0 and br["inf"] == 0:
			quality = "veteran"
		var counts := { "infantry": 0, "cavalry": 0, "artillery": 0 }
		for i in range(n):
			var t: String = specs[i]
			counts[t] += 1
			var label := ""
			match t:
				"infantry": label = "%d%s Bn" % [counts[t], _ord(counts[t])]
				"cavalry": label = "%d%s Sqn" % [counts[t], _ord(counts[t])]
				"artillery": label = "Battery %d" % counts[t]
			# lateral offset of this battalion within its brigade's frontage; the
			# GameManager places the brigade anchor (randomised each match) and lays
			# battalions out along the brigade's facing line from there.
			var off: float = (i - (n - 1) * 0.5) * SPREAD
			out.append({
				"id": bid, "brigade": br["id"], "team": br["team"],
				"name": "%s %s" % [br["short"], label], "type": t,
				"off": off, "quality": quality,
			})
			bid += 1
	return out

# Brigade ids belonging to one team, in book order.
static func team_brigades(team: int) -> Array:
	var out: Array = []
	for b in BRIGADES:
		if b["team"] == team:
			out.append(b["id"])
	return out

static func _ord(n: int) -> String:
	match n:
		1: return "st"
		2: return "nd"
		3: return "rd"
	return "th"
