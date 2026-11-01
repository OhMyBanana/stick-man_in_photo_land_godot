extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const HALF_HEIGHT = 12.0
const HALF_WIDTH = 8.0
const COLLISION_STEP = 1.0
const GROUND_PROBE_DEPTH = 4
const MAX_STEP_UP = 4
const COYOTE_TIME = 0.10
const JUMP_BUFFER_TIME = 0.12
const JUMP_CUT_MULTIPLIER = 0.5

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var spawn_position: Vector2
var active := false
var jump_was_down := false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stage_map = get_tree().current_scene.get_node("StageMap")

func _ready() -> void:
	spawn_position = global_position

func _unhandled_input(event: InputEvent) -> void:
	if not active or not event is InputEventKey:
		return
	if event.pressed and not event.echo and event.keycode == KEY_T:
		stage_map.visible = not stage_map.visible

func reset_player() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	jump_was_down = false
	animated_sprite.play("stand")

func _physics_process(delta: float) -> void:
	if not active:
		return
	var direction := Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A): direction -= 1.0
	if Input.is_key_pressed(KEY_D): direction += 1.0
	direction = clampf(direction, -1.0, 1.0)
	velocity.x = direction * SPEED
	if direction != 0:
		animated_sprite.flip_h = direction < 0

	var jump_pressed := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_UP)
	var jump_just_pressed := jump_pressed and not jump_was_down
	var jump_just_released := not jump_pressed and jump_was_down
	jump_was_down = jump_pressed
	if jump_just_pressed:
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	var grounded := has_ground_below()
	if grounded:
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
	elif grounded and velocity.y > 0.0:
		velocity.y = 0.0
	else:
		velocity.y += gravity * delta
	if jump_just_released and velocity.y < 0.0:
		velocity.y *= JUMP_CUT_MULTIPLIER
	move_horizontally(velocity.x * delta)
	move_vertically(velocity.y * delta)
	grounded = has_ground_below()
	if not grounded:
		animated_sprite.play("jump" if velocity.y < 0.0 else "fall")
	elif abs(velocity.x) > 10.0:
		animated_sprite.play("run")
	else:
		animated_sprite.play("stand")


func move_horizontally(amount: float) -> void:
	if is_zero_approx(amount):
		return

	var direction: float = signf(amount)
	var remaining: float = absf(amount)

	while remaining > 0.0:
		var step: float = minf(COLLISION_STEP, remaining) * direction
		var candidate_x: float = global_position.x + step

		if hits_wall_at(candidate_x, global_position.y):
			var stepped_up: bool = false

			for rise in range(1, MAX_STEP_UP + 1):
				var candidate_y: float = global_position.y - float(rise)

				if not hits_wall_at(candidate_x, candidate_y):
					if not hits_ceiling_at(candidate_y):
						global_position.y = candidate_y
						global_position.x = candidate_x
						stepped_up = true
						break

			if not stepped_up:
				return
		else:
			global_position.x = candidate_x

		remaining -= absf(step)


func move_vertically(amount: float) -> void:
	if is_zero_approx(amount):
		return

	var direction: float = signf(amount)
	var remaining: float = absf(amount)

	while remaining > 0.0:
		var step: float = minf(COLLISION_STEP, remaining) * direction
		var candidate_y: float = global_position.y + step

		if direction > 0.0 and hits_ground_at(candidate_y):
			velocity.y = 0.0
			return

		if direction < 0.0 and hits_ceiling_at(candidate_y):
			velocity.y = 0.0
			return

		global_position.y = candidate_y
		remaining -= absf(step)

func has_ground_below() -> bool:
	for depth in range(1, GROUND_PROBE_DEPTH + 1):
		if hits_ground_at(global_position.y + depth): return true
	return false

func hits_ground_at(player_y: float) -> bool:
	var feet_y := player_y + HALF_HEIGHT
	return stage_map.is_solid_at(Vector2(global_position.x - HALF_WIDTH + 1.0, feet_y)) or stage_map.is_solid_at(Vector2(global_position.x, feet_y)) or stage_map.is_solid_at(Vector2(global_position.x + HALF_WIDTH - 1.0, feet_y))

func hits_ceiling_at(player_y: float) -> bool:
	var head_y := player_y - HALF_HEIGHT
	return stage_map.is_solid_at(Vector2(global_position.x - HALF_WIDTH + 1.0, head_y)) or stage_map.is_solid_at(Vector2(global_position.x, head_y)) or stage_map.is_solid_at(Vector2(global_position.x + HALF_WIDTH - 1.0, head_y))

func hits_wall_at(player_x: float, player_y: float) -> bool:
	var left_x := player_x - HALF_WIDTH
	var right_x := player_x + HALF_WIDTH
	for offset_y in range(-10, 11, 4):
		if stage_map.is_solid_at(Vector2(left_x, player_y + offset_y)) or stage_map.is_solid_at(Vector2(right_x, player_y + offset_y)):
			return true
	return false
