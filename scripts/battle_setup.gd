class_name BattleSetup
extends RefCounted

# ============================================================ THE SEAM (Phase 0)
# The data contract between the world and a battle. The campaign (or menu, or a
# remote host) builds one of these; game.gd consumes it to spawn the field, and
# fills in `result` when the day is decided. Nothing in here knows about scenes.
#
# Design notes (campaign constraints): multiplayer-first — everything here must
# be serializable (to_dict/from_dict) so a host can hand the setup to clients.

# one battalion as the WORLD sees it (a token): enough to inflate to 700 men
class BattUnit:
	var name: String = ""           # "52nd of Foot"
	var team: int = 0
	var men: int = 700              # survivors carry over between battles
	var ammo: float = 50.0
	var morale: float = 100.0
	var experience: float = 1.0     # drill quality: recruits < 1.0 < veterans
	var coat_idx: int = 0
	var facing_col: Color = Color.WHITE
	var brigade: int = 0            # place in the order of battle
	var division: int = 0
	var corps: int = 0
	var pos: Vector3 = Vector3.ZERO # deployment spot (world coords)
	var facing: float = 0.0
	var human_slot: int = -1        # -1 AI, else the peer slot commanding it

	func to_dict() -> Dictionary:
		return { "n": name, "t": team, "m": men, "a": ammo, "mo": morale,
			"e": experience, "c": coat_idx, "f": [facing_col.r, facing_col.g, facing_col.b],
			"b": brigade, "d": division, "k": corps,
			"p": [pos.x, pos.z], "fa": facing, "h": human_slot }

	static func from_dict(d: Dictionary) -> BattUnit:
		var u := BattUnit.new()
		u.name = d.get("n", "")
		u.team = int(d.get("t", 0))
		u.men = int(d.get("m", 700))
		u.ammo = float(d.get("a", 50.0))
		u.morale = float(d.get("mo", 100.0))
		u.experience = float(d.get("e", 1.0))
		u.coat_idx = int(d.get("c", 0))
		var f: Array = d.get("f", [1.0, 1.0, 1.0])
		u.facing_col = Color(f[0], f[1], f[2])
		u.brigade = int(d.get("b", 0))
		u.division = int(d.get("d", 0))
		u.corps = int(d.get("k", 0))
		var p: Array = d.get("p", [0.0, 0.0])
		u.pos = Vector3(p[0], 0.0, p[1])
		u.facing = float(d.get("fa", 0.0))
		u.human_slot = int(d.get("h", -1))
		return u

var units: Array[BattUnit] = []       # both teams' battalions
var guns_per_team: Array[int] = [32, 32]
var cav_per_team: Array[int] = [6, 6] # regiments
var seed_value: int = 0
var weather: String = "clear"
var time_of_day: float = 8.5
var goal: Array[String] = ["", ""]    # per-team directed goal ("" = deduce freely)
var result: Dictionary = {}           # filled by the battle: winner, losses, survivors

# The battle of Ulm as data: today's hardcoded 70k-vs-70k, expressed through the
# seam — proves the contract carries the current game unchanged.
static func default_field() -> BattleSetup:
	var s := BattleSetup.new()
	s.seed_value = randi() | 1
	# (game.gd's _spawn_armies derives positions/dress from OOB indices for now;
	#  the campaign will instead author every unit here, carrying real histories)
	return s

func to_dict() -> Dictionary:
	var ud: Array = []
	for u in units:
		ud.append(u.to_dict())
	return { "u": ud, "g": guns_per_team, "c": cav_per_team, "s": seed_value,
		"w": weather, "tod": time_of_day, "goal": goal }

static func from_dict(d: Dictionary) -> BattleSetup:
	var s := BattleSetup.new()
	for ud in d.get("u", []):
		s.units.append(BattUnit.from_dict(ud))
	s.seed_value = int(d.get("s", 1))
	s.weather = String(d.get("w", "clear"))
	s.time_of_day = float(d.get("tod", 8.5))
	return s
