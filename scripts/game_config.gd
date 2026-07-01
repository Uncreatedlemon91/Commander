extends Node

# Global pre-game configuration (autoload). Set by the launcher menu / Net before
# the battle scene loads, then read by the battle (game.gd).

var mode: String = "single"     # single | host | client
var local_slot: int = 52        # which battalion index this player commands (centre, first line)
var command_echelon: int = 0    # 0 battalion · 1 brigade · 2 division · 3 corps · 4 army — what you command
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
var load_requested: bool = false    # "Continue Campaign": game.gd loads the save file on start
var dedicated: bool = false         # this peer is a HEADLESS DEDICATED SERVER (hosts + simulates, no local player)
var historical: String = ""         # a set-piece historical battle by key ("waterloo") — drives terrain + OOB

# CHARACTER CREATION — the militia the player raises at the start of a campaign.
# Authored on the intro screen (menu.gd), applied to the player's battalion in the
# world (dress, colours) and the battle (flag, officers). Defaults give a sane unit.
var has_militia: bool = false       # true once the player has raised a force this campaign
var militia_name: String = "1st Volunteers"
var militia_uniform: int = 2        # index into the uniform presets (coat colour)
var militia_facing: Color = Color(0.82, 0.72, 0.50)   # the unit's facing colour
var militia_flag: int = 0           # index into the flag design presets
var militia_officers: Array = []    # per company: { "name": String, "skill": float }
var militia_hat: int = 0            # headgear: index into HAT_NAMES
var militia_belt: int = 0           # crossbelt colour: index into BELT_NAMES
var militia_pants: int = 0          # trouser colour: index into PANTS_NAMES

# Uniform presets (coat colours) and flag designs, shared by the menu and the sim.
const UNIFORM_NAMES := ["King's Red", "Rifle Green", "Provincial Blue", "Hunting Frock", "Continental Buff"]
const UNIFORM_COLS := [Color(0.62, 0.16, 0.14), Color(0.16, 0.24, 0.16), Color(0.16, 0.22, 0.44),
	Color(0.40, 0.34, 0.24), Color(0.74, 0.66, 0.48)]
const FLAG_NAMES := ["Crown Standard", "Bars", "Saltire", "The Pine", "Rattlesnake"]
const FACING_SWATCHES := [Color(0.82, 0.72, 0.50), Color(0.15, 0.30, 0.65), Color(0.70, 0.15, 0.15),
	Color(0.20, 0.50, 0.25), Color(0.90, 0.80, 0.20), Color(0.93, 0.93, 0.89), Color(0.10, 0.10, 0.12),
	Color(0.85, 0.45, 0.15)]
# Headgear, crossbelt and trouser options for the militia you raise.
const HAT_NAMES := ["Shako", "Round Hat", "Bicorne"]
const HAT_COLS := [Color(0.07, 0.07, 0.08), Color(0.30, 0.20, 0.12), Color(0.06, 0.06, 0.07)]
const BELT_NAMES := ["White", "Black", "Brown"]
const BELT_COLS := [Color(0.90, 0.88, 0.82), Color(0.11, 0.11, 0.13), Color(0.34, 0.22, 0.12)]
const PANTS_NAMES := ["Buff", "White", "Grey", "Blue"]
const PANTS_COLS := [Color(0.60, 0.58, 0.53), Color(0.86, 0.84, 0.80), Color(0.42, 0.44, 0.48), Color(0.20, 0.26, 0.45)]
