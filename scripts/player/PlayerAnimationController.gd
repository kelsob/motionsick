extends Node
class_name PlayerAnimationController

## === PLAYER ANIMATION CONTROLLER ===
## Manages the mannequin character animations based on player state
## Follows best practices: state-driven, decoupled, and maintainable

## === CONFIGURATION ===
@export_group("Animation Settings")
## Blend time for smooth transitions between animations
@export var blend_time: float = 0.2
## Speed threshold to transition from idle to run
@export var run_speed_threshold: float = 0.5
## Enable debug output
@export var debug_animations: bool = false

# Node references (automatically set in _ready)
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
var player: CharacterBody3D
var time_manager: Node

## === ANIMATION STATE ===
enum AnimState {
	IDLE,
	RUN,
	JUMP_ANTICIPATION,
	JUMP,
	FALL,
	LAND,
	DASH,
	FIGHT_IDLE,
	FIGHT_PUNCH,
	FIGHT_KICK,
	IDLE_TO_FIGHT
}

var current_state: AnimState = AnimState.IDLE
var previous_state: AnimState = AnimState.IDLE
var is_in_combat_mode: bool = false

# State tracking
var was_on_floor: bool = true
var jump_anticipation_timer: float = 0.0
var land_animation_timer: float = 0.0

## === ANIMATION NAMES (matches mannequiny animations) ===
const ANIM_IDLE = "idle"
const ANIM_RUN = "run"
const ANIM_JUMP_ANTICIPATION = "air_jump_anticipation"
const ANIM_JUMP = "air_jump"
const ANIM_LAND = "air_land"
const ANIM_DASH = "dash"
const ANIM_FIGHT_IDLE = "fight_idle"
const ANIM_FIGHT_PUNCH = "fight_punch"
const ANIM_FIGHT_KICK = "fight_kick"
const ANIM_IDLE_TO_FIGHT = "idle_to_fight"

func _ready():
	# Get player reference (parent node)
	player = get_parent() as CharacterBody3D
	if not player:
		push_error("PlayerAnimationController: Parent is not a CharacterBody3D!")
		return
	
	# Get animation player (sibling node)
	if not animation_player:
		push_error("PlayerAnimationController: Could not find AnimationPlayer")
		return
	
	# Get animation tree
	if not animation_tree:
		push_error("PlayerAnimationController: Could not find AnimationTree")
		return
	
	# Make sure AnimationTree is active
	animation_tree.active = true
	
	# DEBUG: Try to access the parameters to see what works
	print("=== AnimationTree Debug ===")
	print("Trying different parameter paths:")
	print("  parameters/Blend2/blend_amount = ", animation_tree.get("parameters/Blend2/blend_amount"))
	print("  parameters/UpperBodyPose/animation = ", animation_tree.get("parameters/UpperBodyPose/animation"))
	print("  parameters/LowerBodyLocomotion/animation = ", animation_tree.get("parameters/LowerBodyLocomotion/animation"))
	# Try with common default names
	print("  parameters/Animation/animation = ", animation_tree.get("parameters/Animation/animation"))
	print("  parameters/Animation2/animation = ", animation_tree.get("parameters/Animation2/animation"))
	print("===========================")
	
	# Get TimeManager reference
	time_manager = get_node("/root/TimeManager")
	if time_manager and time_manager.has_signal("time_scale_changed"):
		time_manager.time_scale_changed.connect(_on_time_scale_changed)
		# Set initial speed scale
		_on_time_scale_changed(time_manager.custom_time_scale)
	
	# Start with idle animation
	_play_animation(ANIM_IDLE, true)
	
	if debug_animations:
		print("PlayerAnimationController initialized with AnimationTree")

func _process(delta: float):
	if not animation_tree or not player:
		return
	
	# Update timers
	if jump_anticipation_timer > 0.0:
		jump_anticipation_timer -= delta
	
	if land_animation_timer > 0.0:
		land_animation_timer -= delta
	
	# Determine and apply animation state
	_update_animation_state()

func _update_animation_state():
	"""Determine which animation should play based on player state."""
	var new_state = _determine_state()
	
	# Only change if state actually changed
	if new_state != current_state:
		_transition_to_state(new_state)

func _determine_state() -> AnimState:
	"""Determine the appropriate animation state based on player conditions."""
	
	# Priority 1: Landing animation (if timer active)
	if land_animation_timer > 0.0:
		return AnimState.LAND
	
	# Priority 2: Jump anticipation (if timer active)
	if jump_anticipation_timer > 0.0:
		return AnimState.JUMP_ANTICIPATION
	
	# Priority 3: Airborne states
	if not player.is_on_floor():
		# Check if jumping (positive Y velocity) or falling (negative Y velocity)
		if player.velocity.y > 0.5:
			return AnimState.JUMP
		else:
			return AnimState.FALL
	
	# Priority 4: Dash
	if player.is_dashing:
		return AnimState.DASH
	
	# Priority 5: Combat animations (if in combat mode)
	if is_in_combat_mode:
		# Could add punch/kick detection here if needed
		return AnimState.FIGHT_IDLE
	
	# Priority 6: Movement (run vs idle)
	var horizontal_speed = Vector2(player.velocity.x, player.velocity.z).length()
	if horizontal_speed > run_speed_threshold:
		return AnimState.RUN
	else:
		return AnimState.IDLE

func _transition_to_state(new_state: AnimState):
	"""Handle state transition and play appropriate animation."""
	previous_state = current_state
	current_state = new_state
	
	if debug_animations:
		print("Animation state: ", _state_to_string(previous_state), " -> ", _state_to_string(new_state))
	
	# Play animation based on new state
	match new_state:
		AnimState.IDLE:
			_play_animation(ANIM_IDLE, true)
		
		AnimState.RUN:
			_play_animation(ANIM_RUN, true)
		
		AnimState.JUMP_ANTICIPATION:
			_play_animation(ANIM_JUMP_ANTICIPATION, false)
		
		AnimState.JUMP:
			_play_animation(ANIM_JUMP, false)
		
		AnimState.FALL:
			# Use jump animation but don't loop (or could add a separate fall anim)
			_play_animation(ANIM_JUMP, false)
		
		AnimState.LAND:
			_play_animation(ANIM_LAND, false)
		
		AnimState.DASH:
			_play_animation(ANIM_DASH, false)
		
		AnimState.FIGHT_IDLE:
			_play_animation(ANIM_FIGHT_IDLE, true)
		
		AnimState.FIGHT_PUNCH:
			_play_animation(ANIM_FIGHT_PUNCH, false)
		
		AnimState.FIGHT_KICK:
			_play_animation(ANIM_FIGHT_KICK, false)
		
		AnimState.IDLE_TO_FIGHT:
			_play_animation(ANIM_IDLE_TO_FIGHT, false)

func _play_animation(anim_name: String, loop: bool = false):
	"""Play an animation through the AnimationTree."""
	if not animation_player.has_animation(anim_name):
		print("WARNING: Animation not found: ", anim_name)
		return
	
	# Set loop mode on the animation
	var animation = animation_player.get_animation(anim_name)
	if animation:
		animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	
	# Access the BlendTree root and set animation on the nodes directly
	var tree_root = animation_tree.tree_root as AnimationNodeBlendTree
	if tree_root:
		# Get the animation nodes from the blend tree
		var upper_body_node = tree_root.get_node("UpperBodyPose") as AnimationNodeAnimation
		var lower_body_node = tree_root.get_node("LowerBodyLocomotion") as AnimationNodeAnimation
		
		# Set the animation property on each node
		if upper_body_node:
			upper_body_node.animation = anim_name
		else:
			print("ERROR: Could not find UpperBodyPose node in BlendTree")
		
		if lower_body_node:
			lower_body_node.animation = anim_name
		else:
			print("ERROR: Could not find LowerBodyLocomotion node in BlendTree")
		
		if debug_animations:
			print("Set animation to: ", anim_name, " (loop: ", loop, ")")
	else:
		print("ERROR: AnimationTree tree_root is not an AnimationNodeBlendTree")

## === PUBLIC API (called by Player.gd) ===

func on_jump_started():
	"""Called when player initiates a jump."""
	# Start anticipation animation briefly
	jump_anticipation_timer = 0.1  # Very brief anticipation
	
	if debug_animations:
		print("Jump started - playing anticipation")

func on_landed():
	"""Called when player lands on ground."""
	# Only play land animation if we were actually in the air
	if not was_on_floor:
		land_animation_timer = 0.3  # Duration of landing animation
		
		if debug_animations:
			print("Player landed - playing land animation")
	
	was_on_floor = true

func on_dash_started():
	"""Called when player starts dashing."""
	if debug_animations:
		print("Dash started")

func enter_combat_mode():
	"""Switch to combat stance animations."""
	if not is_in_combat_mode:
		is_in_combat_mode = true
		# Play transition animation
		_play_animation(ANIM_IDLE_TO_FIGHT, false)
		
		if debug_animations:
			print("Entering combat mode")

func exit_combat_mode():
	"""Return to normal movement animations."""
	if is_in_combat_mode:
		is_in_combat_mode = false
		
		if debug_animations:
			print("Exiting combat mode")

func play_punch():
	"""Trigger punch animation."""
	if is_in_combat_mode:
		_transition_to_state(AnimState.FIGHT_PUNCH)

func play_kick():
	"""Trigger kick animation."""
	if is_in_combat_mode:
		_transition_to_state(AnimState.FIGHT_KICK)

## === TIME SCALE INTEGRATION ===

func _on_time_scale_changed(time_scale: float):
	"""Update animation speed based on time dilation."""
	if animation_player:
		animation_player.speed_scale = time_scale
		
		if debug_animations:
			print("Animation speed_scale set to: ", time_scale)

## === HELPER FUNCTIONS ===

func _state_to_string(state: AnimState) -> String:
	"""Convert state enum to readable string for debugging."""
	match state:
		AnimState.IDLE: return "IDLE"
		AnimState.RUN: return "RUN"
		AnimState.JUMP_ANTICIPATION: return "JUMP_ANTICIPATION"
		AnimState.JUMP: return "JUMP"
		AnimState.FALL: return "FALL"
		AnimState.LAND: return "LAND"
		AnimState.DASH: return "DASH"
		AnimState.FIGHT_IDLE: return "FIGHT_IDLE"
		AnimState.FIGHT_PUNCH: return "FIGHT_PUNCH"
		AnimState.FIGHT_KICK: return "FIGHT_KICK"
		AnimState.IDLE_TO_FIGHT: return "IDLE_TO_FIGHT"
		_: return "UNKNOWN"
