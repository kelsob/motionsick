extends Node
class_name PlayerActionTracker

# Action types we're tracking
enum ActionType {
	MOVE_START,
	MOVE_STOP,
	SPRINT_START,
	SPRINT_STOP,
	CROUCH_START,
	CROUCH_STOP,
	SLIDE_START,
	SLIDE_STOP,
	JUMP,
	DOUBLE_JUMP,
	DASH,
	LAND
}

# Action history
var action_history: Array[ActionType] = []
var max_history_size := 10  # Keep last 10 actions

# Signals for UI updates
signal action_recorded(action_type: ActionType)
signal history_updated(history: Array[ActionType])

func _ready():
	# Connect to player if available
	var player = get_parent()
	if player.has_signal("movement_started"):
		player.movement_started.connect(_on_movement_started)
		player.movement_stopped.connect(_on_movement_stopped)
		player.dash_performed.connect(_on_dash_performed)
		player.jump_performed.connect(_on_jump_performed)
		player.landed.connect(_on_landed)

func record_action(action_type: ActionType):
	# Add to history
	action_history.append(action_type)
	
	# Keep only the last max_history_size actions
	if action_history.size() > max_history_size:
		action_history.pop_front()
	
	# Emit signals
	action_recorded.emit(action_type)
	history_updated.emit(action_history)
	
	print("Action recorded: ", ActionType.keys()[action_type])

func get_recent_actions(count: int = 3) -> Array[ActionType]:
	var recent_count = min(count, action_history.size())
	if recent_count == 0:
		return []
	return action_history.slice(-recent_count)

func get_last_action() -> ActionType:
	if action_history.size() > 0:
		return action_history[-1]
	return ActionType.MOVE_STOP  # Default

func action_type_to_string(action_type: ActionType) -> String:
	match action_type:
		ActionType.MOVE_START: return "Move"
		ActionType.MOVE_STOP: return "Stop"
		ActionType.SPRINT_START: return "Sprint"
		ActionType.SPRINT_STOP: return "Walk"
		ActionType.CROUCH_START: return "Crouch"
		ActionType.CROUCH_STOP: return "Stand"
		ActionType.SLIDE_START: return "Slide"
		ActionType.SLIDE_STOP: return "End Slide"
		ActionType.JUMP: return "Jump"
		ActionType.DOUBLE_JUMP: return "Double Jump"
		ActionType.DASH: return "Dash"
		ActionType.LAND: return "Land"
		_: return "Unknown"

# Signal handlers
func _on_movement_started():
	record_action(ActionType.MOVE_START)

func _on_movement_stopped():
	record_action(ActionType.MOVE_STOP)

func _on_dash_performed():
	record_action(ActionType.DASH)

func _on_jump_performed():
	# We need to differentiate between normal jump and double jump
	# This will be handled in the Player script
	pass

func _on_landed():
	record_action(ActionType.LAND)

# These will be called directly from Player script
func record_sprint_start():
	record_action(ActionType.SPRINT_START)

func record_sprint_stop():
	record_action(ActionType.SPRINT_STOP)

func record_crouch_start():
	record_action(ActionType.CROUCH_START)

func record_crouch_stop():
	record_action(ActionType.CROUCH_STOP)

func record_slide_start():
	record_action(ActionType.SLIDE_START)

func record_slide_stop():
	record_action(ActionType.SLIDE_STOP)

func record_jump():
	record_action(ActionType.JUMP)

func record_double_jump():
	record_action(ActionType.DOUBLE_JUMP) 