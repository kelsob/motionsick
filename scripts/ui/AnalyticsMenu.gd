extends Control

# === ANALYTICS MENU ===
# UI controller for displaying player analytics and statistics
# Handles both per-level and global statistics display

## === EXPORTED CONFIGURATION ===
@export_group("Debug Settings")
## Enable debug output
@export var debug_analytics_menu: bool = false

## === UI REFERENCES ===
# Header elements
@onready var title_label: Label = $VBoxContainer/HeaderContainer/LevelNameLabel
@onready var global_view_button: Button = $VBoxContainer/HeaderContainer/GlobalViewButton
@onready var level_selection_dropdown: OptionButton = $VBoxContainer/HeaderContainer/LevelViewButton

# Basic stats
@onready var sessions_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/BasicStatsSection/BasicStats/SessionsLabel
@onready var playtime_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/BasicStatsSection/BasicStats/PlaytimeLabel
@onready var best_time_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/BasicStatsSection/BasicStats/BestTimeLabel
@onready var average_time_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/BasicStatsSection/BasicStats/AverageTimeLabel
@onready var success_rate_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/BasicStatsSection/BasicStats/SuccessRateLabel

# Combat stats
@onready var bullets_fired_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/CombatStatsSection/CombatStats/BulletsFiredLabel
@onready var bullets_hit_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/CombatStatsSection/CombatStats/BulletsHitLabel
@onready var accuracy_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/CombatStatsSection/CombatStats/AccuracyLabel
@onready var enemies_killed_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/CombatStatsSection/CombatStats/EnemiesKilledLabel
@onready var damage_dealt_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/CombatStatsSection/CombatStats/DamageDealtLabel
@onready var multi_kills_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/CombatStatsSection/CombatStats/MultiKillsLabel
@onready var multi_hits_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/CombatStatsSection/CombatStats/MultiHitsLabel

# Movement stats
@onready var distance_traveled_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/MovementStatsSection/MovementStats/DistanceTraveledLabel
@onready var dashes_used_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/MovementStatsSection/MovementStats/DashesUsedLabel
@onready var jumps_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/MovementStatsSection/MovementStats/JumpsLabel
@onready var slides_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/MovementStatsSection/MovementStats/SlidesLabel
@onready var deflections_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/MovementStatsSection/MovementStats/DeflectionsLabel

# Time stats
@onready var combat_time_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/TimeStatsSection/TimeStats/CombatTimeLabel
@onready var moving_time_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/TimeStatsSection/TimeStats/MovingTimeLabel
@onready var stationary_time_label: Label = $VBoxContainer/StatsContainer/VBoxContainer/TimeStatsSection/TimeStats/StationaryTimeLabel

# Footer elements
@onready var back_button: Button = $VBoxContainer/FooterContainer/BackButton
@onready var clear_data_button: Button = $VBoxContainer/FooterContainer/ClearDataButton

## === RUNTIME STATE ===
# Current view mode (global or level-specific)
var current_view_mode: String = "global"
# Currently selected level for level view
var selected_level_id: String = ""
# Available levels for selection
var available_levels: Array = []

func _ready():
	# Ensure mouse is visible for menu interaction
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Connect button signals
	_setup_connections()
	
	# Initialize UI
	_update_ui()
	
	# Load available levels
	_load_available_levels()
	
	if debug_analytics_menu:
		print("AnalyticsMenu: Initialized")

func _setup_connections():
	"""Connect UI button signals."""
	global_view_button.pressed.connect(_on_global_view_pressed)
	level_selection_dropdown.item_selected.connect(_on_level_dropdown_selected)
	back_button.pressed.connect(_on_back_pressed)
	clear_data_button.pressed.connect(_on_clear_data_pressed)

func _load_available_levels():
	"""Load available levels from LevelManager."""
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		available_levels = level_manager.get_available_levels()
		_populate_level_selection()
	else:
		if debug_analytics_menu:
			print("AnalyticsMenu: LevelManager not found")

func _populate_level_selection():
	"""Populate level selection dropdown with available levels."""
	# Clear existing items
	level_selection_dropdown.clear()
	
	# Add "Select Level" as first item
	level_selection_dropdown.add_item("Select Level")
	
	# Add each available level
	for level_data in available_levels:
		level_selection_dropdown.add_item(level_data.display_name)
	
	# Set default selection
	level_selection_dropdown.selected = 0

func _update_ui():
	"""Update all UI elements with current analytics data."""
	var analytics_data: AnalyticsManager.LevelAnalytics
	
	# Get appropriate analytics data
	if current_view_mode == "global":
		analytics_data = AnalyticsManager.get_global_analytics()
		title_label.text = "Global Statistics"
	else:
		analytics_data = AnalyticsManager.get_level_analytics(selected_level_id)
		title_label.text = "Level: " + selected_level_id
	
	# Update basic stats
	_update_basic_stats(analytics_data)
	
	# Update combat stats
	_update_combat_stats(analytics_data)
	
	# Update movement stats
	_update_movement_stats(analytics_data)
	
	# Update time stats
	_update_time_stats(analytics_data)

func _update_basic_stats(analytics: AnalyticsManager.LevelAnalytics):
	"""Update basic statistics labels."""
	sessions_label.text = "Sessions: " + str(analytics.sessions_played)
	
	var hours = int(analytics.total_playtime) / 3600
	var minutes = (int(analytics.total_playtime) % 3600) / 60
	var seconds = int(analytics.total_playtime) % 60
	playtime_label.text = "Total Time: %02d:%02d:%02d" % [hours, minutes, seconds]
	
	best_time_label.text = "Best Time: %.1fs" % analytics.best_survival_time
	average_time_label.text = "Average Time: %.1fs" % analytics.average_survival_time
	success_rate_label.text = "Success Rate: %.1f%%" % (analytics.success_rate * 100.0)

func _update_combat_stats(analytics: AnalyticsManager.LevelAnalytics):
	"""Update combat statistics labels."""
	bullets_fired_label.text = "Bullets Fired: " + str(analytics.bullets_fired)
	bullets_hit_label.text = "Bullets Hit: " + str(analytics.bullets_hit)
	accuracy_label.text = "Accuracy: %.1f%%" % (analytics.get_accuracy() * 100.0)
	enemies_killed_label.text = "Enemies Killed: " + str(analytics.enemies_killed)
	damage_dealt_label.text = "Damage Dealt: %.0f" % analytics.total_damage_dealt
	multi_kills_label.text = "Multi-Kills: " + str(analytics.multi_kills)
	multi_hits_label.text = "Multi-Hits: " + str(analytics.multi_hits)

func _update_movement_stats(analytics: AnalyticsManager.LevelAnalytics):
	"""Update movement statistics labels."""
	distance_traveled_label.text = "Distance: %.1fm" % analytics.distance_traveled
	dashes_used_label.text = "Dashes: " + str(analytics.dashes_used)
	jumps_label.text = "Jumps: " + str(analytics.jumps_performed)
	slides_label.text = "Slides: " + str(analytics.slides_performed)
	deflections_label.text = "Deflections: " + str(analytics.deflections_performed)

func _update_time_stats(analytics: AnalyticsManager.LevelAnalytics):
	"""Update time-based statistics labels."""
	combat_time_label.text = "Combat Time: %.1fs" % analytics.time_in_combat
	moving_time_label.text = "Moving Time: %.1fs" % analytics.time_moving
	stationary_time_label.text = "Stationary Time: %.1fs" % analytics.time_stationary

## === SIGNAL HANDLERS ===

func _on_global_view_pressed():
	"""Switch to global statistics view."""
	current_view_mode = "global"
	# Reset dropdown selection
	level_selection_dropdown.selected = 0
	_update_ui()
	
	if debug_analytics_menu:
		print("AnalyticsMenu: Switched to global view")

func _on_level_dropdown_selected(index: int):
	"""Handle level selection from dropdown."""
	if index == 0:  # "Select Level" option
		return
	
	# Get the selected level data
	var level_data = available_levels[index - 1]  # -1 because index 0 is "Select Level"
	selected_level_id = level_data.id
	current_view_mode = "level"
	_update_ui()
	
	if debug_analytics_menu:
		print("AnalyticsMenu: Selected level: ", level_data.display_name, " (", level_data.id, ")")

func _on_back_pressed():
	"""Return to main menu."""
	if debug_analytics_menu:
		print("AnalyticsMenu: Back button pressed")
	
	# Ensure all game systems are properly reset before returning to main menu
	_reset_all_game_systems()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _reset_all_game_systems():
	"""Reset all game systems to ensure proper state for new games."""
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	if game_state_manager:
		game_state_manager.reset_for_analytics()
	else:
		# Fallback to individual resets if GameStateManager not available
		_reset_systems_fallback()
	
	if debug_analytics_menu:
		print("AnalyticsMenu: Reset all game systems")

func _reset_systems_fallback():
	"""Fallback method for resetting systems if GameStateManager is not available."""
	# Reset TimeManager
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.deactivate_for_menus()
	
	# Reset GameplayUIManager
	var ui_manager = get_node_or_null("/root/GameplayUIManager")
	if ui_manager:
		ui_manager.deactivate_gameplay_ui()
	
	# Reset ArenaSpawnManager
	var arena_spawn_manager = get_node_or_null("/root/ArenaSpawnManager")
	if arena_spawn_manager:
		arena_spawn_manager.stop_spawning()
		if arena_spawn_manager.has_method("reset_for_level"):
			arena_spawn_manager.reset_for_level()
	
	# Reset TracerManager
	var tracer_manager = get_node_or_null("/root/TracerManager")
	if tracer_manager:
		tracer_manager.reset_tracer_system()

func _on_clear_data_pressed():
	"""Clear all analytics data."""
	AnalyticsManager.clear_analytics()
	_update_ui()
	
	if debug_analytics_menu:
		print("AnalyticsMenu: Analytics data cleared")

## === PUBLIC API ===

func show_analytics():
	"""Show the analytics menu."""
	visible = true
	_update_ui()

func hide_analytics():
	"""Hide the analytics menu."""
	visible = false
