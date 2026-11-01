
extends Node2D

enum ObjectType {
	SPAWN,
	GOAL,
	HAZARD
}

@export var object_type: ObjectType = ObjectType.HAZARD

var is_selected: bool = false

const SELECTED_COLOR := Color.WHITE
const OUTLINE_WIDTH := 2.5

func _ready() -> void:
	queue_redraw()

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()

func contains_point(point: Vector2) -> bool:
	return global_position.distance_to(point) <= 22.0

func _draw() -> void:
	match object_type:
		ObjectType.SPAWN:
			draw_spawn()
		ObjectType.GOAL:
			draw_goal()
		ObjectType.HAZARD:
			draw_hazard()

	if is_selected:
		draw_arc(
			Vector2.ZERO,
			24.0,
			0.0,
			TAU,
			48,
			SELECTED_COLOR,
			OUTLINE_WIDTH
		)

func draw_spawn() -> void:
	draw_circle(Vector2.ZERO, 13.0, Color(0.15, 0.85, 0.3))
	draw_circle(Vector2.ZERO, 5.0, Color.WHITE)
	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 32, Color(0.05, 0.4, 0.1), 2.0)

func draw_goal() -> void:
	var points := make_star_points(8.0, 17.0, 5)
	draw_colored_polygon(points, Color(1.0, 0.8, 0.05))
	draw_polyline(
		close_polygon(points),
		Color(0.95, 0.45, 0.0),
		2.0
	)

func draw_hazard() -> void:
	draw_circle(Vector2.ZERO, 15.0, Color(0.9, 0.12, 0.12))
	draw_line(Vector2(-7, -7), Vector2(7, 7), Color.WHITE, 3.0)
	draw_line(Vector2(7, -7), Vector2(-7, 7), Color.WHITE, 3.0)

func make_star_points(inner_radius: float, outer_radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(point_count * 2):
		var angle := -PI / 2.0 + float(i) * PI / float(point_count)
		var radius := outer_radius if i % 2 == 0 else inner_radius
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func close_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	if not points.is_empty():
		closed.append(points[0])
	return closed
