extends Control

## Small signs of life in the painted booth: the red tally lights on the two
## security cameras blink, and the status LEDs on the equipment outside the glass
## pulse gently out of step with each other.
##
## The plate is a still painting, so without this the room is frozen between
## packets. It is its own node because InspectionWindow deliberately stops
## processing when nothing is moving, and these never stop.

## Camera tally lights: [centre, radius]. They blink fully off.
const CAMERAS := [
	[Vector2(345.0, 61.0), 7.0],
	[Vector2(1752.0, 262.0), 6.0],
]
## Status LEDs beyond the glass. They only pulse their glow.
const LEDS: Array[Vector2] = [
	Vector2(205.0, 214.0), Vector2(352.0, 394.0), Vector2(648.0, 452.0),
	Vector2(796.0, 468.0), Vector2(1212.0, 197.0), Vector2(1246.0, 424.0),
	Vector2(1404.0, 432.0), Vector2(1608.0, 294.0),
]
const RED := Color(1.0, 0.16, 0.12)
## The dead lens colour a camera light shows while it is off.
const LENS_OFF := Color(0.16, 0.05, 0.05)

## The booth, so LEDs behind a sheet held up to the glass stay hidden.
@export var booth: InspectionWindow

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for i in CAMERAS.size():
		var c: Vector2 = CAMERAS[i][0]
		var r: float = CAMERAS[i][1]
		# On for most of a 1.6 s cycle, off briefly; the two are out of phase.
		var on := fmod(_time + i * 0.7, 1.6) < 1.25
		if on:
			_glow(c, r * 2.6, 0.22)
		else:
			draw_circle(c, r, LENS_OFF)

	var held := booth.document_rect() if booth != null else Rect2()
	for i in LEDS.size():
		if held.grow(10.0).has_point(LEDS[i]):
			continue
		var phase := float(i) * 1.37
		var k := 0.5 + 0.5 * sin(_time * (1.1 + 0.23 * float(i % 3)) + phase)
		_glow(LEDS[i], 9.0, 0.16 * k)


func _glow(c: Vector2, radius: float, alpha: float) -> void:
	for j in 3:
		var t := float(j + 1) / 3.0
		draw_circle(c, radius * (1.0 - 0.5 * t) + 1.0, Color(RED.r, RED.g, RED.b, alpha * t))
