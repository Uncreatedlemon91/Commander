extends Node

# Global pre-game configuration (autoload). Set by the main menu before the
# battle scene loads, then read by the battle's GameManager.

var mode: String = "single"     # single | host | client
var local_team: int = 0          # 0 = French, 1 = Austrian
var player_name: String = "Commander"
