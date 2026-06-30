class_name Weapon
extends Resource

# An infantry small arm as EDITABLE DATA. Every ballistic number that used to be a global
# constant in game.gd lives here, so a Brown Bess, a Baker rifle and (later) a Sharps each
# behave differently. Tune the .tres files in weapons/ in the Inspector — that's the point.
# The defaults below mirror the old Brown Bess, so an unset weapon = the original behaviour.

@export var id: String = "brown_bess"
@export var display_name: String = "Brown Bess"
@export var max_range: float = 82.0          # effective reach (m); past this the ball can't tell
@export var reload_time: float = 30.0        # base seconds/round, before skill/fatigue/fire-mode modifiers
@export var hit_point_blank: float = 0.24    # fraction of muskets that tell at the muzzle
@export var hit_falloff: float = 1.0         # accuracy ~ (1 - d/max_range)^this; LOWER = deadlier at range
@export var yaw_sd: float = 0.022            # horizontal scatter (rad) — spreads the dead across the front
@export var pitch_sd: float = 0.015          # vertical scatter (rad) — balls fly high/short at range
@export var aim_lead: float = 0.7            # seconds a man levels the piece before it is ready to fire

static var _cache: Dictionary = {}
static var _fallback: Weapon = null

# Resolve a weapon by id, loading weapons/<id>.tres once and caching it. A missing or invalid id
# falls back to a default (Brown Bess) Weapon, so the fire logic is never handed a null.
static func get_weapon(wid: String) -> Weapon:
	if _cache.has(wid):
		return _cache[wid]
	var path := "res://weapons/%s.tres" % wid
	var w: Weapon = null
	if ResourceLoader.exists(path):
		w = load(path) as Weapon
	if w == null:
		w = _default()
	_cache[wid] = w
	return w

static func _default() -> Weapon:
	if _fallback == null:
		_fallback = Weapon.new()
	return _fallback
