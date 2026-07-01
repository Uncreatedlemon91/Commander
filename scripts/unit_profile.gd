class_name UnitProfile
extends Resource

# A unit TYPE as EDITABLE DATA — nationality (doctrine), weapon, dress and drill quality bundled
# into one Inspector-editable resource. The order-of-battle references a profile by id; a battle
# then places instances (name, strength, position, experience) that stamp the profile's fields.
# Edit the .tres files in units/ to author or tune a unit type. Defaults = a generic line battalion.

@export var id: String = "line"
@export var display_name: String = "Line Battalion"
@export var nation: String = "GEN"           # doctrine key (FR/BR/PR/KG…) → national doctrine + army role
@export var weapon: String = "brown_bess"    # weapon id → weapons/<id>.tres
@export var coat_idx: int = 0                 # dress: national coat slot
@export var facing_col: Color = Color(0.7, 0.7, 0.7)   # collar / cuff / lapel facing colour
@export var belt_idx: int = 0                 # crossbelt colour (0 white, 1 black…)
@export var pants_idx: int = -1               # trouser colour (-1 = default)
@export var hat_idx: int = -1                 # headgear shape (-1 = default shako)
@export var skill_base: float = 55.0          # drill/quality base (Guards high, militia low); experience scales it

static var _cache: Dictionary = {}
static var _fallback: UnitProfile = null

# Resolve a profile by id, loading units/<id>.tres once and caching it. Missing/invalid → a default
# generic profile, so authoring never crashes on a typo'd id.
static func get_profile(pid: String) -> UnitProfile:
	if _cache.has(pid):
		return _cache[pid]
	var path := "res://units/%s.tres" % pid
	var p: UnitProfile = null
	if ResourceLoader.exists(path):
		p = load(path) as UnitProfile
	if p == null:
		p = _default()
	_cache[pid] = p
	return p

static func _default() -> UnitProfile:
	if _fallback == null:
		_fallback = UnitProfile.new()
	return _fallback
