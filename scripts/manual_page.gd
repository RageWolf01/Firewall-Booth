class_name ManualPage
extends Control

## The day's manual, typed onto the open notebook at the left of the desk.
##
## The notebook itself is part of the painted plate; this draws only the words:
## the title in the dark bar across the top of the page, and the rules beneath
## it. A blank line in `body` becomes the dashed rule the painting separates its
## paragraphs with, so the layout follows the text rather than the other way
## round.
##
## Coordinates are in this control's space. main.tscn places it with its origin
## at the page's top-left corner (viewport 87, 707), so the numbers below are the
## painting's positions minus that.

const INK := Color("#26221d")
const TITLE_INK := Color("#c9c3b6")
const RULE := Color(0.24, 0.22, 0.19, 0.55)

## Title, baseline-left, inside the dark bar.
const TITLE_POS := Vector2(23.0, 30.0)
const TITLE_SIZE := 25
## Body text: left edge, first baseline, line pitch and size.
const BODY_X := 18.0
const BODY_TOP := 77.0
const BODY_PITCH := 29.0
const BODY_SIZE := 20
## Words wrap at this width; the page's right margin.
const BODY_W := 322.0
## Baseline to baseline across a paragraph break, and how far below the last
## line the dashed rule through that break sits.
const PARAGRAPH_STEP := 58.0
const RULE_DROP := 19.0

@export var title := "":
	set(value):
		title = value
		queue_redraw()

@export_multiline var body := "":
	set(value):
		body = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var font := _font()
	draw_string(font, TITLE_POS, title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, TITLE_INK)

	var y := BODY_TOP
	var first := true
	for paragraph in body.split("\n\n"):
		if not first:
			# `y` is one pitch below the last line drawn.
			var last := y - BODY_PITCH
			_dashed(Vector2(BODY_X, last + RULE_DROP), BODY_W - 12.0)
			y = last + PARAGRAPH_STEP
		first = false
		for line in _wrap_paragraph(font, paragraph):
			draw_string(font, Vector2(BODY_X, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1,
				BODY_SIZE, INK)
			y += BODY_PITCH


func _dashed(from: Vector2, length: float) -> void:
	var x := 0.0
	while x < length:
		draw_rect(Rect2(from.x + x, from.y, minf(9.0, length - x), 2.0), RULE, true)
		x += 14.0


## The paragraph's own line breaks are kept; anything too wide is wrapped.
func _wrap_paragraph(font: Font, paragraph: String) -> PackedStringArray:
	var out := PackedStringArray()
	for raw in paragraph.split("\n"):
		var line := ""
		for word in raw.split(" ", false):
			var trial := word if line.is_empty() else line + " " + word
			var w := font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, BODY_SIZE).x
			if line.is_empty() or w <= BODY_W:
				line = trial
			else:
				out.append(line)
				line = word
		out.append(line)
	return out


func _font() -> Font:
	var node := get_node_or_null("/root/UiFont")
	if node != null and node.get("font") != null:
		return node.get("font")
	return load("res://scripts/ui_font.gd").mono_font()
