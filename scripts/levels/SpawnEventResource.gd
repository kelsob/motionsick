extends Resource
class_name SpawnEventResource

## Resource for defining individual enemy spawn events in levels
## This creates a clean inspector interface for level designers

## Enemy type to spawn (0=Grunt, 1=Sniper, 2=Flanker, 3=Rusher, 4=Artillery)
@export_enum("Grunt", "Sniper", "Flanker", "Rusher", "Artillery") var enemy_type: int = 0
## When to spawn this enemy (seconds from level start)
@export var spawn_time: float = 0.0
## Which spawn marker to use (index in spawn markers array)
@export var spawn_marker_index: int = 0
## Telegraph duration override (use -1 for default level setting)
@export var telegraph_duration: float = -1.0
## Health multiplier for this specific enemy
@export var health_multiplier: float = 1.0
## Speed multiplier for this specific enemy  
@export var speed_multiplier: float = 1.0
