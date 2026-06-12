extends Node

# Global pre-game configuration (autoload). Set by the launcher menu / Net before
# the battle scene loads, then read by the battle (game.gd).

var mode: String = "single"     # single | host | client
var local_slot: int = 52        # which battalion index this player commands (centre, first line)
var player_name: String = "Commander"
var match_seed: int = 0          # shared RNG seed so every peer deploys identically
# campaign hook: when set, the AI army's appreciation is DIRECTED to this goal
# (destroy | turn_left | turn_right | break_centre | bleed | delay)
var battle_goal: String = ""
# THE SEAM: the campaign/menu/host authors a BattleSetup here before loading the
# battle; game.gd consumes it and writes `result` + survivor states back into it.
var setup = null   # : BattleSetup (null -> the battle builds a default field)

# PHASE 2 — inflation handoff. The province (world.gd) survives the scene change
# to the battle and back inside these (this autoload persists across scenes).
var return_to_world: bool = false   # battle should return to world.tscn, not the menu
var world_state: Dictionary = {}    # the whole province, serialized across the battle
var battle_tokens: Array = []       # ids of the world tokens that inflated into this battle
