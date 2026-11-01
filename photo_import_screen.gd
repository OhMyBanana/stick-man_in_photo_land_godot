
extends CanvasLayer

signal demo_requested
signal photo_selected(path: String)
signal return_to_level_requested
signal terrain_accepted(background_path: String, mask_path: String)

const SETTINGS_PATH := "user://photo_import_settings.cfg"

var initial_photo_path := ""
var show_return_to_level := false

var file_dialog: FileDialog
var preview: TextureRect
var status_label: Label
var selected_photo_path := ""
var pending_photo_path := ""
var return_button: Button
var continue_button: Button
var generate_button: Button
var camera_button: Button
var confirm_replace_dialog: ConfirmationDialog
var preview_dialog: ConfirmationDialog

var camera_panel: VBoxContainer
var camera_preview: TextureRect
var capture_button: Button
var close_camera_button: Button

var last_directory := ""
var generated_mask_path := ""
var generated_preview_path := ""

var generator_thread: Thread
var generation_running := false

var camera_thread: Thread
var camera_running := false
var camera_frame_path := ""
var camera_stop_path := ""
var camera_error_path := ""
var camera_capture_path := ""
var camera_refresh_elapsed := 0.0


func _ready() -> void:
	layer = 20
	_load_settings()
	_build_interface()

	if not initial_photo_path.is_empty() and FileAccess.file_exists(initial_photo_path):
		_display_photo(initial_photo_path, false)

	return_button.visible = show_return_to_level
	continue_button.visible = not show_return_to_level
	generate_button.disabled = selected_photo_path.is_empty()


func _process(delta: float) -> void:
	_poll_generation()
	_poll_camera(delta)


func _exit_tree() -> void:
	_stop_camera()

	if camera_thread != null and camera_thread.is_started():
		camera_thread.wait_to_finish()
		camera_thread = null


func _poll_generation() -> void:
	if not generation_running or generator_thread == null:
		return

	if not generator_thread.is_alive():
		var result: Dictionary = generator_thread.wait_to_finish()
		generator_thread = null
		generation_running = false
		generate_button.disabled = false
		_handle_generation_result(result)


func _poll_camera(delta: float) -> void:
	if camera_thread != null and camera_thread.is_started():
		if not camera_thread.is_alive():
			var result: Dictionary = camera_thread.wait_to_finish()
			camera_thread = null

			if camera_running:
				camera_running = false
				_handle_camera_result(result)

	if not camera_running:
		return

	camera_refresh_elapsed += delta

	if camera_refresh_elapsed < 0.12:
		return

	camera_refresh_elapsed = 0.0

	if FileAccess.file_exists(camera_error_path):
		var error_file := FileAccess.open(camera_error_path, FileAccess.READ)
		if error_file != null:
			var message := error_file.get_as_text()
			error_file.close()
			status_label.text = "Camera error:\n" + message
			_stop_camera()
			return

	if not FileAccess.file_exists(camera_frame_path):
		return

	var image := Image.new()
	if image.load(camera_frame_path) == OK:
		camera_preview.texture = ImageTexture.create_from_image(image)


func _load_settings() -> void:
	var config := ConfigFile.new()

	if config.load(SETTINGS_PATH) == OK:
		last_directory = str(
			config.get_value("photo_import", "last_directory", "")
		)

	if last_directory.is_empty() or not DirAccess.dir_exists_absolute(last_directory):
		last_directory = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("photo_import", "last_directory", last_directory)
	config.save(SETTINGS_PATH)


func _build_interface() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.035, 0.045, 0.065, 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var heading := Label.new()
	heading.text = "STICK-MAN IN PHOTO LAND"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	column.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = "Turn a photograph into a world to explore."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	var source_buttons := HBoxContainer.new()
	source_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(source_buttons)

	var choose_button := Button.new()
	choose_button.text = "Choose a Photo"
	choose_button.custom_minimum_size = Vector2(190, 48)
	choose_button.pressed.connect(_open_file_dialog)
	source_buttons.add_child(choose_button)

	camera_button = Button.new()
	camera_button.text = "Use Camera"
	camera_button.custom_minimum_size = Vector2(190, 48)
	camera_button.pressed.connect(_start_camera)
	source_buttons.add_child(camera_button)

	camera_panel = VBoxContainer.new()
	camera_panel.add_theme_constant_override("separation", 8)
	camera_panel.visible = false
	column.add_child(camera_panel)

	var camera_heading := Label.new()
	camera_heading.text = "LIVE CAMERA"
	camera_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	camera_panel.add_child(camera_heading)

	camera_preview = TextureRect.new()
	camera_preview.custom_minimum_size = Vector2(520, 260)
	camera_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	camera_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	camera_panel.add_child(camera_preview)

	var camera_controls := HBoxContainer.new()
	camera_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	camera_panel.add_child(camera_controls)

	capture_button = Button.new()
	capture_button.text = "Capture Photo"
	capture_button.custom_minimum_size = Vector2(190, 44)
	capture_button.pressed.connect(_capture_camera_photo)
	camera_controls.add_child(capture_button)

	close_camera_button = Button.new()
	close_camera_button.text = "Close Camera"
	close_camera_button.custom_minimum_size = Vector2(190, 44)
	close_camera_button.pressed.connect(_close_camera)
	camera_controls.add_child(close_camera_button)

	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(520, 260)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.visible = false
	column.add_child(preview)

	status_label = Label.new()
	status_label.text = "Choose a photograph or use your camera."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status_label)

	generate_button = Button.new()
	generate_button.text = "Generate Terrain"
	generate_button.custom_minimum_size = Vector2(0, 48)
	generate_button.disabled = true
	generate_button.pressed.connect(_start_generation)
	column.add_child(generate_button)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)

	continue_button = Button.new()
	continue_button.text = "Play Demo Level"
	continue_button.custom_minimum_size = Vector2(190, 44)
	continue_button.pressed.connect(func(): demo_requested.emit())
	buttons.add_child(continue_button)

	return_button = Button.new()
	return_button.text = "Return to Level"
	return_button.custom_minimum_size = Vector2(190, 44)
	return_button.pressed.connect(func(): return_to_level_requested.emit())
	buttons.add_child(return_button)

	var note := Label.new()
	note.text = "Take a photo with your webcam or select an existing image. Review generated terrain before using it."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	column.add_child(note)

	file_dialog = FileDialog.new()
	file_dialog.title = "Choose a photograph"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.use_native_dialog = true
	file_dialog.filters = PackedStringArray([
		"*.png, *.jpg, *.jpeg, *.webp, *.bmp ; Images (PNG, JPEG, WebP, BMP)",
		"*.png ; PNG images",
		"*.jpg, *.jpeg ; JPEG images",
		"*.webp ; WebP images",
		"*.bmp ; BMP images"
	])
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)

	confirm_replace_dialog = ConfirmationDialog.new()
	confirm_replace_dialog.title = "Replace selected photograph?"
	confirm_replace_dialog.dialog_text = "Use this photograph instead of the currently selected one?\nYour existing level placements will be preserved."
	confirm_replace_dialog.confirmed.connect(_confirm_photo_replacement)
	add_child(confirm_replace_dialog)

	preview_dialog = ConfirmationDialog.new()
	preview_dialog.title = "Accept Generated Terrain?"
	preview_dialog.dialog_text = "Use this generated terrain in your level?"
	preview_dialog.ok_button_text = "Use Terrain"
	preview_dialog.confirmed.connect(_accept_generated_terrain)
	preview_dialog.canceled.connect(_restore_source_preview)
	add_child(preview_dialog)


func _open_file_dialog() -> void:
	if generation_running:
		return

	_stop_camera()
	camera_panel.visible = false
	file_dialog.current_dir = last_directory
	file_dialog.popup_centered_ratio(0.82)


func _on_file_selected(path: String) -> void:
	last_directory = path.get_base_dir()
	_save_settings()

	var loaded_image := Image.new()
	var error := loaded_image.load(path)

	if error != OK:
		status_label.text = "Couldn't load that image. Please choose another file."
		return

	pending_photo_path = path

	if not selected_photo_path.is_empty() and path != selected_photo_path:
		confirm_replace_dialog.popup_centered()
	else:
		_confirm_photo_replacement()


func _confirm_photo_replacement() -> void:
	if pending_photo_path.is_empty():
		return

	_display_photo(pending_photo_path, true)
	pending_photo_path = ""


func _display_photo(path: String, emit_selection: bool) -> void:
	var loaded_image := Image.new()
	var error := loaded_image.load(path)

	if error != OK:
		status_label.text = "Couldn't load that image. Please choose another file."
		return

	selected_photo_path = path
	preview.texture = ImageTexture.create_from_image(loaded_image)
	preview.visible = true
	generate_button.disabled = false
	status_label.text = "Selected: " + path.get_file() + "\nReady to generate terrain."

	generated_mask_path = ""
	generated_preview_path = ""

	if emit_selection:
		photo_selected.emit(path)


func _start_camera() -> void:
	if camera_thread != null:
		status_label.text = "The previous camera session is still closing. Please try again in a moment."
		return

	if generation_running:
		return

	var project_root := ProjectSettings.globalize_path("res://")
	var service_dir := project_root.path_join("terrain_service")
	var python_exe := service_dir.path_join(".venv").path_join("Scripts").path_join("python.exe")
	var script_path := service_dir.path_join("camera_service.py")
	var output_dir := service_dir.path_join("output")

	if not FileAccess.file_exists(python_exe):
		status_label.text = "Python environment not found:\n" + python_exe
		return

	if not FileAccess.file_exists(script_path):
		status_label.text = "Camera service not found:\n" + script_path
		return

	DirAccess.make_dir_recursive_absolute(output_dir)

	camera_frame_path = output_dir.path_join("camera_frame.jpg")
	camera_stop_path = output_dir.path_join("camera_stop.flag")
	camera_error_path = output_dir.path_join("camera_error.txt")
	var capture_dir := "user://stick_man_captures"
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(capture_dir)
	)
	camera_capture_path = capture_dir.path_join("captured_photo.jpg")
	for path in [camera_stop_path, camera_error_path, camera_frame_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

	camera_preview.texture = null
	camera_panel.visible = true
	preview.visible = false
	camera_refresh_elapsed = 0.0
	status_label.text = "Starting camera...\nIf prompted, allow Windows camera access."

	var arguments := PackedStringArray([
		script_path,
		"--output",
		output_dir,
		"--device",
		"0"
	])

	camera_thread = Thread.new()
	var start_error := camera_thread.start(
		_run_camera_service.bind(python_exe, arguments)
	)

	if start_error != OK:
		camera_thread = null
		camera_panel.visible = false
		status_label.text = "Couldn't start the camera service."
		return

	camera_running = true


func _run_camera_service(
	python_exe: String,
	arguments: PackedStringArray
) -> Dictionary:
	var process_output: Array = []
	var exit_code := OS.execute(
		python_exe,
		arguments,
		process_output,
		true
	)

	return {
		"exit_code": exit_code,
		"output": "\n".join(process_output)
	}


func _handle_camera_result(result: Dictionary) -> void:
	var exit_code := int(result.get("exit_code", -1))
	var process_output := str(result.get("output", ""))

	if exit_code != 0 and not process_output.is_empty():
		status_label.text = "Camera stopped with an error:\n" + process_output
	elif not FileAccess.file_exists(camera_frame_path):
		status_label.text = "Camera closed. No photo was captured."
	else:
		status_label.text = "Camera closed."


func _capture_camera_photo() -> void:
	if not camera_running:
		return

	if not FileAccess.file_exists(camera_frame_path):
		status_label.text = "Waiting for the first camera frame..."
		return

	var image := Image.new()
	var frame_bytes := PackedByteArray()
	var image_loaded := false

	# Retry in case Python is updating the camera frame.
	for attempt in range(10):
		frame_bytes = FileAccess.get_file_as_bytes(camera_frame_path)

		if not frame_bytes.is_empty():
			var error := image.load_jpg_from_buffer(frame_bytes)

			if error == OK and not image.is_empty():
				image_loaded = true
				break

		OS.delay_msec(100)

	if not image_loaded:
		status_label.text = "Couldn't read a valid camera frame. Please try again."
		return

	# Copy the original JPEG instead of re-encoding it.
	var output_file := FileAccess.open(camera_capture_path, FileAccess.WRITE)

	if output_file == null:
		status_label.text = "Couldn't create captured photo. Error: " + str(FileAccess.get_open_error())
		return

	output_file.store_buffer(frame_bytes)
	output_file.flush()
	output_file.close()

	# Verify that the saved photograph can be loaded.
	var verification_image := Image.new()
	var verification_error := verification_image.load(camera_capture_path)

	if verification_error != OK or verification_image.is_empty():
		status_label.text = "The captured photo was written but couldn't be verified."
		return

	_stop_camera()
	camera_panel.visible = false
	_display_photo(camera_capture_path, true)
	status_label.text = "Camera photo captured!\nYou can generate terrain from this image."

func _close_camera() -> void:
	_stop_camera()
	camera_panel.visible = false
	status_label.text = "Camera closed."


func _stop_camera() -> void:
	if camera_thread == null or not camera_thread.is_started():
		camera_running = false
		return

	camera_running = false

	var stop_file := FileAccess.open(camera_stop_path, FileAccess.WRITE)
	if stop_file != null:
		stop_file.store_string("stop")
		stop_file.close()


func _start_generation() -> void:
	if generation_running or selected_photo_path.is_empty():
		return

	var project_root := ProjectSettings.globalize_path("res://")
	var service_dir := project_root.path_join("terrain_service")
	var python_exe := service_dir.path_join(".venv").path_join("Scripts").path_join("python.exe")
	var script_path := service_dir.path_join("generate_terrain.py")
	var output_dir := service_dir.path_join("output")

	if not FileAccess.file_exists(python_exe):
		status_label.text = "Python environment not found:\n" + python_exe
		return

	if not FileAccess.file_exists(script_path):
		status_label.text = "Terrain generator not found:\n" + script_path
		return

	DirAccess.make_dir_recursive_absolute(output_dir)

	generate_button.disabled = true
	status_label.text = "Generating terrain...\nThe first run may take a little longer while the model loads."

	var absolute_photo_path := ProjectSettings.globalize_path(selected_photo_path)

	generator_thread = Thread.new()
	var start_error := generator_thread.start(
		_run_generator.bind(python_exe, script_path, absolute_photo_path, output_dir)
	)

	if start_error != OK:
		generator_thread = null
		generate_button.disabled = false
		status_label.text = "Couldn't start the terrain generation thread."
		return

	generation_running = true


func _run_generator(
	python_exe: String,
	script_path: String,
	photo_path: String,
	output_dir: String
) -> Dictionary:
	var arguments := PackedStringArray([
		script_path,
		photo_path,
		"--output",
		output_dir
	])

	var process_output: Array = []
	var exit_code := OS.execute(
		python_exe,
		arguments,
		process_output,
		true
	)

	return {
		"exit_code": exit_code,
		"output": "\n".join(process_output)
	}


func _handle_generation_result(result: Dictionary) -> void:
	var exit_code := int(result.get("exit_code", -1))
	var process_output := str(result.get("output", ""))

	if exit_code != 0:
		status_label.text = "Terrain generation failed.\n" + process_output
		push_error("Terrain generation failed:\n" + process_output)
		return

	var output_dir := ProjectSettings.globalize_path("res://").path_join("terrain_service").path_join("output")
	var mask_path := output_dir.path_join("terrain_mask.png")
	var preview_path := output_dir.path_join("terrain_preview.png")
	var metadata_path := output_dir.path_join("terrain_metadata.json")

	if not FileAccess.file_exists(mask_path) or not FileAccess.file_exists(preview_path) or not FileAccess.file_exists(metadata_path):
		status_label.text = "Python finished, but one or more output files are missing.\n" + process_output
		return

	generated_mask_path = mask_path
	generated_preview_path = preview_path
	_show_generated_preview()


func _show_generated_preview() -> void:
	var image := Image.new()
	var error := image.load(generated_preview_path)

	if error != OK:
		status_label.text = "Generated terrain, but couldn't load the preview image."
		return

	preview.texture = ImageTexture.create_from_image(image)
	preview.visible = true
	status_label.text = "Terrain generated successfully!\nReview the result and choose whether to use it."
	preview_dialog.popup_centered()


func _restore_source_preview() -> void:
	if selected_photo_path.is_empty():
		return

	var image := Image.new()
	if image.load(selected_photo_path) == OK:
		preview.texture = ImageTexture.create_from_image(image)

	status_label.text = "Terrain preview dismissed. You can generate again or choose another photo."


func _accept_generated_terrain() -> void:
	if generated_mask_path.is_empty():
		return

	terrain_accepted.emit(selected_photo_path, generated_mask_path)
