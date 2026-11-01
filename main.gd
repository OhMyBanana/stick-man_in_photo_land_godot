
extends Node2D

const LEVEL_OBJECT_SCRIPT = preload("res://level_object.gd")
const PHOTO_IMPORT_SCREEN_SCRIPT = preload("res://photo_import_screen.gd")
const PLAYER_HALF_SIZE := Vector2(8.0, 12.0)
const FALL_RESET_Y := 850.0

@onready var player = $Player
@onready var stage_map: Sprite2D = $StageMap
@onready var photo_background: Sprite2D = $PhotoBackground

var editor_mode := true
var active_tool := "select"
var level_objects: Array = []
var selected_object = null
var dragging := false
var spawn_marker = null
var goal_marker = null

var status_label: Label
var toolbar: HBoxContainer
var play_button: Button
var play_hud_button: Button

var photo_import_screen: CanvasLayer
var selected_photo_path := ""
var was_playing_when_import_opened := false
var player_was_active_before_import := false


func _ready() -> void:
	player.visible = false
	player.set_physics_process(false)

	_build_toolbar()
	_build_play_hud()

	_set_status("EDIT MODE - Choose Spawn, Star, or Hazard, then click the photo")
	_open_photo_import_screen(false)


func _build_toolbar() -> void:
	var layer := CanvasLayer.new()
	layer.name = "EditorUI"
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	layer.add_child(panel)

	var column := VBoxContainer.new()
	panel.add_child(column)

	toolbar = HBoxContainer.new()
	column.add_child(toolbar)

	_add_tool_button("Select / Move", "select")
	_add_tool_button("Spawn", "spawn")
	_add_tool_button("Star", "goal")
	_add_tool_button("+ Hazard", "hazard")

	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.pressed.connect(_delete_selected)
	toolbar.add_child(delete_button)

	var change_photo_button := Button.new()
	change_photo_button.text = "Change Photo"
	change_photo_button.pressed.connect(_open_photo_import_screen.bind(true))
	toolbar.add_child(change_photo_button)

	play_button = Button.new()
	play_button.text = "Play"
	play_button.pressed.connect(_start_playing)
	toolbar.add_child(play_button)

	status_label = Label.new()
	status_label.text = ""
	column.add_child(status_label)


func _build_play_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PlayUI"
	layer.layer = 5
	add_child(layer)

	play_hud_button = Button.new()
	play_hud_button.text = "Change Photo"
	play_hud_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	play_hud_button.position = Vector2(-150, 16)
	play_hud_button.pressed.connect(_open_photo_import_screen.bind(true))
	layer.add_child(play_hud_button)
	play_hud_button.visible = false


func _add_tool_button(label_text: String, tool_name: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.pressed.connect(func(): _choose_tool(tool_name))
	toolbar.add_child(button)


func _choose_tool(tool_name: String) -> void:
	active_tool = tool_name
	dragging = false
	_set_status("Tool: " + tool_name.capitalize() + " - Click to place; drag existing objects to move")


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(photo_import_screen):
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and not editor_mode:
			_return_to_editor()
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			if editor_mode:
				_delete_selected()
		elif event.keycode == KEY_R and not editor_mode:
			_respawn_player()
		elif event.keycode == KEY_T and editor_mode:
			stage_map.visible = not stage_map.visible
		return

	if not editor_mode:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_position := get_global_mouse_position()

		if event.pressed:
			var hit := _find_object_at(mouse_position)

			if hit != null:
				_select_object(hit)
				dragging = true
				return

			_select_object(null)

			if active_tool in ["spawn", "goal", "hazard"]:
				_place_object(active_tool, mouse_position)

		elif not event.pressed:
			dragging = false

	if event is InputEventMouseMotion and dragging and selected_object != null:
		selected_object.global_position = get_global_mouse_position()


func _place_object(kind: String, world_position: Vector2) -> void:
	if kind == "spawn" and is_instance_valid(spawn_marker):
		spawn_marker.queue_free()

	if kind == "goal" and is_instance_valid(goal_marker):
		goal_marker.queue_free()

	var marker := Node2D.new()
	marker.set_script(LEVEL_OBJECT_SCRIPT)

	match kind:
		"spawn":
			marker.set("object_type", 0)
		"goal":
			marker.set("object_type", 1)
		"hazard":
			marker.set("object_type", 2)

	marker.position = to_local(world_position)
	add_child(marker)

	if kind == "spawn":
		spawn_marker = marker
	elif kind == "goal":
		goal_marker = marker
	else:
		level_objects.append(marker)

	_select_object(marker)
	_set_status(kind.capitalize() + " placed. Select / Move to reposition it.")


func _find_object_at(world_position: Vector2) -> Node2D:
	var candidates: Array[Node2D] = []

	if is_instance_valid(spawn_marker):
		candidates.append(spawn_marker)

	if is_instance_valid(goal_marker):
		candidates.append(goal_marker)

	for item in level_objects:
		if is_instance_valid(item):
			candidates.append(item)

	for i in range(candidates.size() - 1, -1, -1):
		if candidates[i].call("contains_point", world_position):
			return candidates[i]

	return null


func _select_object(object: Node2D) -> void:
	if is_instance_valid(selected_object):
		selected_object.call("set_selected", false)

	selected_object = object

	if is_instance_valid(selected_object):
		selected_object.call("set_selected", true)


func _delete_selected() -> void:
	if not is_instance_valid(selected_object):
		return

	if selected_object == spawn_marker:
		spawn_marker = null
	elif selected_object == goal_marker:
		goal_marker = null
	else:
		level_objects.erase(selected_object)

	selected_object.queue_free()
	selected_object = null
	_set_status("Selected object deleted.")


func _start_playing() -> void:
	if not is_instance_valid(spawn_marker):
		_set_status("Place a Spawn marker before playing.")
		return

	if not is_instance_valid(goal_marker):
		_set_status("Place a Star goal before playing.")
		return

	editor_mode = false
	dragging = false
	_select_object(null)

	toolbar.visible = false
	play_hud_button.visible = true

	player.global_position = spawn_marker.global_position
	player.set("spawn_position", spawn_marker.global_position)
	player.velocity = Vector2.ZERO
	player.set("active", true)
	player.visible = true
	player.set_physics_process(true)

	_set_status("PLAY MODE - WASD / Arrows to move, Space / W to jump, Esc to edit")


func _return_to_editor() -> void:
	editor_mode = true
	player.set("active", false)
	player.set_physics_process(false)
	player.visible = false

	toolbar.visible = true
	play_hud_button.visible = false

	_set_status("EDIT MODE - Your level layout has been preserved")


func _respawn_player() -> void:
	if is_instance_valid(spawn_marker):
		player.call("reset_player")


func _physics_process(_delta: float) -> void:
	if editor_mode or not player.get("active"):
		return

	if player.global_position.y > FALL_RESET_Y:
		_respawn_player()
		return

	var player_rect := Rect2(
		player.global_position - PLAYER_HALF_SIZE,
		PLAYER_HALF_SIZE * 2.0
	)

	for hazard in level_objects:
		if is_instance_valid(hazard):
			var hazard_rect := Rect2(
				hazard.global_position - Vector2(12, 12),
				Vector2(24, 24)
			)

			if player_rect.intersects(hazard_rect):
				_respawn_player()
				return

	if is_instance_valid(goal_marker):
		if player.global_position.distance_to(goal_marker.global_position) < 24.0:
			player.set("active", false)
			player.set_physics_process(false)
			play_hud_button.visible = false
			_set_status("YOU WIN! - Press Esc to return to the editor")


func _open_photo_import_screen(from_existing_level: bool) -> void:
	if is_instance_valid(photo_import_screen):
		return

	was_playing_when_import_opened = from_existing_level and not editor_mode
	player_was_active_before_import = was_playing_when_import_opened and bool(player.get("active"))

	if was_playing_when_import_opened:
		player.set("active", false)
		player.set_physics_process(false)
		player.visible = false

	toolbar.visible = false
	play_hud_button.visible = false

	photo_import_screen = PHOTO_IMPORT_SCREEN_SCRIPT.new()
	photo_import_screen.initial_photo_path = selected_photo_path
	photo_import_screen.show_return_to_level = from_existing_level

	add_child(photo_import_screen)

	photo_import_screen.demo_requested.connect(_on_demo_requested)
	photo_import_screen.photo_selected.connect(_on_photo_selected)
	photo_import_screen.return_to_level_requested.connect(_on_return_to_level_requested)
	photo_import_screen.terrain_accepted.connect(_on_terrain_accepted)


func _close_photo_import_screen() -> void:
	if is_instance_valid(photo_import_screen):
		photo_import_screen.queue_free()

	photo_import_screen = null


func _on_demo_requested() -> void:
	_close_photo_import_screen()

	editor_mode = true
	player.set("active", false)
	player.set_physics_process(false)
	player.visible = false

	toolbar.visible = true
	play_hud_button.visible = false

	_set_status("EDIT MODE - Choose Spawn, Star, or Hazard, then click the photo")


func _on_photo_selected(path: String) -> void:
	selected_photo_path = path
	print("Photo selected for terrain generation: ", path)
	_set_status("Selected photo: " + path.get_file())



func _on_terrain_accepted(background_path: String, mask_path: String) -> void:
	var background_image := Image.new()
	var background_error := background_image.load(background_path)

	if background_error != OK:
		_set_status("Couldn't load the selected photograph.")
		push_error("Could not load background image: " + background_path)
		return

	var mask_image := Image.new()
	var mask_error := mask_image.load(mask_path)

	if mask_error != OK:
		_set_status("Couldn't load the generated terrain mask.")
		push_error("Could not load terrain mask: " + mask_path)
		return

	if background_image.get_width() != mask_image.get_width() or background_image.get_height() != mask_image.get_height():
		_set_status("The photograph and terrain mask dimensions don't match.")
		push_error("Background and terrain mask dimensions differ.")
		return

	photo_background.texture = ImageTexture.create_from_image(background_image)
	stage_map.call("set_stage_texture", ImageTexture.create_from_image(mask_image))

	# Fit both images into the game viewport while preserving aspect ratio.
		# Fit both images into the game viewport while preserving aspect ratio.
	var viewport_size: Vector2 = get_viewport_rect().size
	var image_size: Vector2 = Vector2(
		background_image.get_width(),
		background_image.get_height()
	)

	var scale_factor: float = minf(
		viewport_size.x / image_size.x,
		viewport_size.y / image_size.y
	)

	var displayed_size: Vector2 = image_size * scale_factor
	var image_offset: Vector2 = (viewport_size - displayed_size) / 2.0

	# Both sprites must use precisely the same transform.
	photo_background.centered = false
	photo_background.position = image_offset
	photo_background.scale = Vector2.ONE * scale_factor

	stage_map.centered = false
	stage_map.position = image_offset
	stage_map.scale = Vector2.ONE * scale_factor

	selected_photo_path = background_path

	_close_photo_import_screen()

	editor_mode = true
	player.set("active", false)
	player.set_physics_process(false)
	player.visible = false

	toolbar.visible = true
	play_hud_button.visible = false

	_set_status("NEW WORLD GENERATED - Place Spawn, Star, and Hazards to build your level!")


func _on_return_to_level_requested() -> void:
	_close_photo_import_screen()

	if was_playing_when_import_opened:
		editor_mode = false
		player.set("active", player_was_active_before_import)
		player.visible = player_was_active_before_import
		player.set_physics_process(player_was_active_before_import)

		toolbar.visible = false
		play_hud_button.visible = true

		if player_was_active_before_import:
			_set_status("PLAY MODE - WASD / Arrows to move, Space / W to jump, Esc to edit")
		else:
			_set_status("YOU WIN! - Press Esc to return to the editor")
	else:
		editor_mode = true
		player.set("active", false)
		player.set_physics_process(false)
		player.visible = false

		toolbar.visible = true
		play_hud_button.visible = false

		_set_status("EDIT MODE - Your level layout has been preserved")


func _set_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message
