class_name HpBar extends Node2D

var bar_width: float = 32.0
var y_offset: float = -24.0
var always_show: bool = false:
	set(value):
		if always_show != value:
			always_show = value
			queue_redraw()

var _ratio: float = 1.0

func set_ratio(r: float) -> void:
	if _ratio != r:
		_ratio = r
		queue_redraw()

func should_draw() -> bool:
	return _ratio > 0.0 and (_ratio < 1.0 or always_show)

func _draw() -> void:
	if not should_draw():
		return
		
	var bg_rect := Rect2(-bar_width / 2.0, y_offset, bar_width, 4.0)
	draw_rect(bg_rect, Color(0.1, 0.1, 0.1, 0.8))
	
	var fill_width := bar_width * _ratio
	var fill_rect := Rect2(-bar_width / 2.0, y_offset, fill_width, 4.0)
	
	# Color: green when full, red when empty
	var c := Color(1.0, 0.0, 0.0)
	if _ratio > 0.5:
		# 0.5 -> 1.0 (yellow to green)
		c = Color(1.0 - (_ratio - 0.5) * 2.0, 1.0, 0.0)
	else:
		# 0.0 -> 0.5 (red to yellow)
		c = Color(1.0, _ratio * 2.0, 0.0)
		
	draw_rect(fill_rect, c)
