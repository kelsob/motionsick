extends Control
class_name GameUI

# UI components
@onready var crosshair: Control = $Crosshair
@onready var action_history_panel: Control = $ActionHistoryPanel

# Player reference
var player: CharacterBody3D
var action_tracker: PlayerActionTracker

func _ready():
	# Find player in scene
	player = get_tree().get_first_node_in_group("player")
	if player:
		action_tracker = player.get_node("PlayerActionTracker")
		if action_tracker:
			action_tracker.history_updated.connect(_on_action_history_updated)

func _on_action_history_updated(history: Array):
	if action_history_panel:
		action_history_panel.update_action_display(history) 
