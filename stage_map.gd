
extends Sprite2D

var stage_image: Image


func _ready() -> void:
	_refresh_stage_image()


func _refresh_stage_image() -> void:
	if texture:
		stage_image = texture.get_image()
	else:
		stage_image = null


func set_stage_texture(new_texture: Texture2D) -> void:
	texture = new_texture
	_refresh_stage_image()


func is_solid_at(world_position: Vector2) -> bool:
	if stage_image == null:
		return false

	# Convert the world position into a pixel in the stage image.
	var local_position = to_local(world_position)
	var pixel_x = int(floor(local_position.x))
	var pixel_y = int(floor(local_position.y))

	# Points outside the image are not solid.
	if pixel_x < 0 or pixel_y < 0:
		return false
	if pixel_x >= stage_image.get_width():
		return false
	if pixel_y >= stage_image.get_height():
		return false

	var pixel = stage_image.get_pixel(pixel_x, pixel_y)

	# Match the original game's rule: colored pixels are solid.
	return not (
		is_equal_approx(pixel.r, pixel.g)
		and is_equal_approx(pixel.g, pixel.b)
	)
