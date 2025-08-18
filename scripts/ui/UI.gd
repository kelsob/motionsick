extends CanvasLayer
class_name UI

# UI components
@onready var crosshair: Control = $Control/Crosshair
@onready var action_history_panel: Control = $Control/ActionHistoryPanel
@onready var score_label: Label = $Control/ScoreLabel

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
	
	# Connect to ScoreManager
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		score_manager.score_changed.connect(_on_score_changed)
		# Set initial score
		_update_score_display(score_manager.get_current_score())
		print("UI connected to ScoreManager")
	else:
		print("WARNING: ScoreManager not found for UI!")

func _on_score_changed(new_score: int):
	"""Called when score changes."""
	_update_score_display(new_score)

func _update_score_display(score: int):
	"""Update the score display."""
	if score_label:
		score_label.text = "Score: " + str(score)

func _on_action_history_updated(history: Array):
	if action_history_panel:
		action_history_panel.update_action_display(history) 
