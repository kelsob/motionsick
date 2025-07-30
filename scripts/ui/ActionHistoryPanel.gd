extends Control
class_name ActionHistoryPanel

# UI components
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var action_container: VBoxContainer = $MarginContainer/VBoxContainer/ActionContainer

# Action display properties
var max_visible_actions := 5
var action_labels: Array[Label] = []
var fade_duration := 0.3

# Action colors
var action_colors = {
	PlayerActionTracker.ActionType.MOVE_START: Color.WHITE,
	PlayerActionTracker.ActionType.MOVE_STOP: Color.GRAY,
	PlayerActionTracker.ActionType.SPRINT_START: Color.CYAN,
	PlayerActionTracker.ActionType.SPRINT_STOP: Color.WHITE,
	PlayerActionTracker.ActionType.CROUCH_START: Color.YELLOW,
	PlayerActionTracker.ActionType.CROUCH_STOP: Color.WHITE,
	PlayerActionTracker.ActionType.SLIDE_START: Color.MAGENTA,
	PlayerActionTracker.ActionType.SLIDE_STOP: Color.WHITE,
	PlayerActionTracker.ActionType.JUMP: Color.GREEN,
	PlayerActionTracker.ActionType.DOUBLE_JUMP: Color.LIME,
	PlayerActionTracker.ActionType.DASH: Color.ORANGE,
	PlayerActionTracker.ActionType.LAND: Color.BROWN
}

func _ready():
	setup_panel()
	create_action_labels()

func setup_panel():
	# Position panel in bottom-right corner
	#set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	#position = Vector2(-220, -150)
	size = Vector2(200, 120)
	
	# Style the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.7)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color.WHITE
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	add_theme_stylebox_override("panel", style_box)

func create_action_labels():
	# Create labels for displaying actions
	for i in range(max_visible_actions):
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 12)
		label.text = ""
		label.modulate.a = 0.0
		action_container.add_child(label)
		action_labels.append(label)

func update_action_display(history: Array):
	if not action_container:
		return
	
	# Get the most recent actions (up to max_visible_actions)
	var recent_actions = history.slice(-max_visible_actions) if history.size() > 0 else []
	
	# Update each label
	for i in range(max_visible_actions):
		var label = action_labels[i]
		
		if i < recent_actions.size():
			var action_type = recent_actions[i]
			var action_tracker = PlayerActionTracker.new()
			var action_text = action_tracker.action_type_to_string(action_type)
			var action_color = action_colors.get(action_type, Color.WHITE)
			
			# Update label
			label.text = action_text
			label.modulate = action_color
			
			# Fade in new actions
			if label.modulate.a < 1.0:
				var tween = create_tween()
				tween.tween_property(label, "modulate:a", 1.0, fade_duration)
		else:
			# Hide unused labels
			if label.modulate.a > 0.0:
				var tween = create_tween()
				tween.tween_property(label, "modulate:a", 0.0, fade_duration)

func highlight_latest_action():
	# Briefly highlight the most recent action
	if action_labels.size() > 0:
		var latest_label = action_labels[-1]
		var tween = create_tween()
		var original_scale = latest_label.scale
		tween.tween_property(latest_label, "scale", original_scale * 1.2, 0.1)
		tween.tween_property(latest_label, "scale", original_scale, 0.1) 
