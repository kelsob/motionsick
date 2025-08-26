extends Node3D

# === MAIN SCENE CONTROLLER ===
# Controls high-level game state and debug options

@export_group("Debug Options")
@export var disable_enemy_spawning: bool = false  # Turn off all enemy spawning for testing

func _ready():
	# Pass debug settings to spawn manager
	if disable_enemy_spawning:
		var spawn_manager = get_node("/root/ArenaSpawnManager")
		if spawn_manager:
			spawn_manager.disable_spawning = true
			print("Main: Enemy spawning disabled via debug toggle")
	
	print("Main scene ready")
