class_name StatusLight
extends Control

## A round status lamp, drawn rather than typed.
##
## This is deliberately not a Label with a "●" character: Godot's default theme
## font has no U+25CF, so the glyph falls back to an undefined-character box.
## Drawing the circle keeps the lamp identical on every platform and font.

## Diffuse glow drawn behind the bulb, at low alpha.
const HALO_ALPHA := 0.22
## Ring drawn around the bulb for definition.
const RIM := Color(1, 1, 1, 0.25)

@export var color: Color = Color(0.30, 0.30, 0.33):
	set(value):
		color = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)


func _draw() -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.5

	# Soft halo, so a lit lamp reads as glowing rather than as a flat disc.
	draw_circle(centre, radius, Color(color.r, color.g, color.b, HALO_ALPHA))
	draw_circle(centre, radius * 0.78, color)
	draw_arc(centre, radius * 0.78, 0.0, TAU, 48, RIM, 2.0, true)
