class_name StatusLight
extends Control

## The verdict lamp, set into the "i" badge of the info panel.
##
## While no call has been made it draws nothing at all, so the painted "i" badge
## shows through. Once the player rules it lights up over the badge — green with
## a tick for a correct call, red with a cross for a wrong one.
##
## Drawn rather than typed: Godot's default theme font has no U+25CF, so a "●"
## Label falls back to an undefined-character box.

## Diffuse glow drawn around the bulb, at low alpha.
const HALO_ALPHA := 0.28
## Ring drawn around the bulb for definition.
const RIM := Color(0, 0, 0, 0.55)
const MARK := Color(0.06, 0.05, 0.04, 0.85)

## Lamp colour. Fully transparent means "off": the painted badge shows instead.
@export var color: Color = Color(0, 0, 0, 0):
	set(value):
		color = value
		queue_redraw()

## Whether the mark on the lit lamp is a tick (true) or a cross (false).
@export var good := true:
	set(value):
		good = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if color.a <= 0.0:
		return
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.5

	# Soft halo, so a lit lamp reads as glowing rather than as a flat disc.
	for i in 4:
		var t := float(i) / 3.0
		draw_circle(centre, radius * (1.0 + 0.45 * (1.0 - t)),
			Color(color.r, color.g, color.b, HALO_ALPHA * t * 0.5))
	draw_circle(centre, radius, RIM)
	draw_circle(centre, radius - 3.0, color)
	draw_circle(centre - Vector2(radius, radius) * 0.28, radius * 0.32,
		Color(1, 1, 1, 0.18))

	var r := radius * 0.42
	if good:
		draw_polyline(PackedVector2Array([
			centre + Vector2(-r, 0.0),
			centre + Vector2(-r * 0.3, r * 0.7),
			centre + Vector2(r, -r * 0.7),
		]), MARK, 5.0)
	else:
		draw_line(centre + Vector2(-r, -r), centre + Vector2(r, r), MARK, 5.0)
		draw_line(centre + Vector2(-r, r), centre + Vector2(r, -r), MARK, 5.0)
