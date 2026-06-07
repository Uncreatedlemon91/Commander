extends Camera2D

@onready var commander: Node2D = get_node_or_null("../Player")

@export var SPEED := 8.0

func _ready() -> void:
	make_current()

func _process(delta: float) -> void:
	if commander:
		global_position = global_position.lerp(commander.global_position, SPEED * delta)
