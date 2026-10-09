extends Control
class_name InspectionWindow

## The booth, from the inspector's chair.
##
## The camera sits BEHIND the desk. In front of you, in order of depth:
##
##   1. the desk surface, running off the bottom of the frame
##   2. a document lying flat on it, foreshortened — click it to pick it up
##   3. the clipboard with today's manual, propped at the edge of the desk
##   4. the booth window: a thick opening in the wall in front of you
##   5. through the glass, the queue — boxes, the next one standing at the
##      glass with the rest of the line receding behind it
##
## Everything is drawn with primitives. There are no imported assets.
##
## The one bit of perspective in the whole scene is the document: lying flat it
## is vertically squashed and slightly sheared, which is enough to read as "on
## the desk" without needing a camera.

## Corner bolts on the frame.
const BOLT_R := 9.0
## Radius of the lamp bulb.
const BULB_R := 15.0

# ---------------------------------------------------------------- palette
const WALL := Color("#171310")
const WALL_LIT := Color("#2a2118")
const WALL_DARK := Color("#0a0806")
const FRAME := Color("#8a6a34")
const FRAME_LIT := Color("#c9a24a")
const FRAME_DARK := Color("#4a3517")
const STEEL := Color("#7d6a44")
const STEEL_LIT := Color("#b89a5c")
const NIGHT_TOP := Color("#071c22")
const NIGHT_BOTTOM := Color("#0d3238")
const DESK := Color("#3a2a1c")
const DESK_LIT := Color("#5a4229")
const DESK_DARK := Color("#1c1309")
const PAPER := Color("#cdbf9e")
const PAPER_SHADE := Color("#bcae8c")
const PAPER_EDGE := Color("#6f6046")
const INK := Color("#2e281e")
const INK_FAINT := Color("#6b6151")
const STAMP_OK := Color("#2f7a44")
const STAMP_NO := Color("#a83226")
const LAMP_WARM := Color("#ffcf7a")
## How far the verdict stamp leans, in radians.
const STAMP_TILT := -0.14

const WOOD_AGED := Color("#37281c")
const WOOD_AGED_LIT := Color("#4b3826")
const BRASS := Color("#a87c3a")
const BRASS_LIT := Color("#e0b45f")
const BRASS_DARK := Color("#5c4420")
const BRASS_PATINA := Color("#6b7350")
const VISTA_TEAL := Color("#0d3238")
const VISTA_TEAL_DARK := Color("#071c22")
const PAPER_AGED := Color("#cdbf9e")
const PAPER_AGED_DARK := Color("#a4936f")
const PAPER_AGED_EDGE := Color("#6f6046")
const INK_BROWN := Color("#3a3125")
const ALLOW_GREEN := Color("#57e08a")
const BLOCK_RED := Color("#ef5a4a")
const SHIELD_BLUE := Color("#7fd8ff")
const SCALE_FRAME := Color("#8a6a2e")
# ---------------------------------------------------------------- geometry
## The room fills the whole viewport. It used to be 1080 wide (half the screen),
## which left a dead strip down the right-hand side.
const ROOM_W := 1920.0
const ROOM_H := 1080.0
## The booth window. It starts below the lamp (whose shade bottoms out around
## y=120) or the cone collides with the frame.
const OPENING := Rect2(150.0, 250.0, 1620.0, 430.0)
const FRAME_W := 18.0
## Desk starts here and runs off the bottom.
const DESK_Y := 700.0
## Where the document lies on the desk, before foreshortening.
const DOC_FLAT := Rect2(470.0, 722.0, 330.0, 300.0)
## Vertical squash + shear that sells "flat on the desk". Kept gentle: a strong
## shear pushes content off the page once the form is drawn in sheared space.
const FLAT_SQUASH := 0.58
const FLAT_SHEAR := 0.05
## Where the document stands once lifted. Sized and placed to clear the action
## bar: it stops short of x=1460, which is where the buttons start when the
## document is up.
const DOC_LIFTED := Rect2(540.0, 264.0, 560.0, 700.0)
## The manual clipboard, propped at the left of the desk.
const BOARD := Rect2(64.0, 756.0, 320.0, 300.0)
## The slot the ID documents are fed through, cut into the bench. Sits just
## outside the flat document's footprint so the sheet rests on top of it and the
## opening frames it.
const SLOT := Rect2(404.0, 894.0, 470.0, 28.0)

# ---------------------------------------------------------------- signals

## Emitted whenever the document is picked up (true) or laid back down (false).
## main.gd uses this to enable the decision buttons ONLY while the document is
## actually open — reading it once and clicking away must re-lock them.
signal document_state_changed(up: bool)

## Emitted once when a judged packet has finished walking off and the line has
## settled. main.gd holds the verdict on screen until this, then moves on.
signal departing_finished

## Emitted when the stamp has just landed on the page. main.gd uses this as the
## beat to hold on before the sheet is taken away, so the player actually sees
## the verdict being stamped.
signal stamp_hit


# ---------------------------------------------------------------- state

# ---------------------------------------------------------------- state
enum DocState { FLAT, LIFTED }

## Sentinel meaning "nobody at the glass". A dedicated instance avoids the
## problem that an empty `Packet.new()` and a null `_packet` would both be
## falsy, so `show_packet()` could not tell "clear it" from "show a blank one".
static var NO_PACKET := Packet.new("", 0, "", "", true, "")

var _doc_state: int = DocState.FLAT
## How far the document has been picked up: 0 = lying on the desk, 1 = held up.
## Animated, and it drives the drawing.
var _desk := 0.0
## Where `_desk` is heading. The open/closed state keys off THIS, not `_desk`:
## keying it off the animated value means the buttons are not live until the
## tween has run, so in the frame the player clicks they appear dead.
var _desk_target := 0.0
var _lift_tween: Tween
## The packet currently at the glass, or NO_PACKET.
var _packet: Packet = NO_PACKET
## The verdict stamped on the document. Empty while the packet is still
## awaiting a decision — the stamp is ink applied when the player rules, so it
## must not exist before then.
var _stamp_word := ""
var _stamp_color := STAMP_OK
## How far the stamp has come down: 0 = still above the page, 1 = pressed on it.
var _stamp_press := 1.0
var _stamp_tween: Tween

## The line outside: index 0 is at the glass, the rest recede directly behind it.
## Each entry is {"packet": Packet, "depth": float}; `depth` is animated when the
## queue shuffles forward.
var _queue: Array[Dictionary] = []
## Packets that have been judged and are walking off. Each is
## {"depth": float, "t": float, "approved": bool}. They are removed from _queue
## the instant they are judged, so the next packet is at the glass immediately —
## the walk-off is a visual flourish, not a gate on the game state.
var _leaving: Array[Dictionary] = []
## Shuffle progress, 0 when the line is settled and 1 when it has closed up.
var _shuffling := 1.0
## The packets the line is built from, cycled. Kept so the queue can be topped
## up after each departure instead of running out.
var _templates: Array[Packet] = []
## Where the next packet comes from when topping up the line.
var _next_template := 0
## Document slide-in progress: 0 = still off to the side, 1 = landed on the desk.
var _arrive := 1.0
## Guards `departing_finished` so it fires once per departure, not every idle frame.
var _departing_announced := true


## How many packets to keep in the line, including the one at the glass.
## The line is topped up after every departure, so for now the shift never runs
## dry — a real queue of 20-odd packets arrives with the day's data later.
const QUEUE_TARGET := 4
## How many packets to draw. Depth beyond this is culled.
const QUEUE_VISIBLE := 5
## Seconds for a judged packet to walk out and fade.
const LEAVE_TIME := 1.15
## Seconds for the line to close up after a departure.
const SHUFFLE_TIME := 0.45
## Seconds for a document to slide in across the desk.
const ARRIVE_TIME := 0.42
## Seconds for the stamp to come down onto the page. Deliberately slow enough to
## read: at anything under about a third of a second the player never sees it.
const STAMP_TIME := 0.5
## How far BELOW its resting place a document starts. It is fed up out of the
## slot in the bench, so this offset is vertical rather than horizontal.
const ARRIVE_FROM_Y := 190.0
## Where the single lane runs, and its ground line.
const LANE_X := 960.0
const LANE_BASE_Y := 624.0
## How far up the screen each place in the line sits. Big enough that a queue of
## five reads as five separate boxes; at ~30 they overlapped into one blob.
const LANE_RISE := 62.0
const BOX_W := 138.0
const BOX_H := 204.0
## How much a packet shrinks and dims per place back in the line.
const DEPTH_SHRINK := 0.10
const DEPTH_DIM := 0.17
## Radius of the soft shadow pooled under a packet.
const CONTACT_W := 0.62


## Give the booth the packets it deals from. The line is built from these and
## topped up as it drains, so for now the shift loops.
func set_queue(queue: Array[Packet]) -> void:
	_templates = queue.duplicate()
	_next_template = 0
	_queue.clear()
	_leaving.clear()
	_top_up()
	_shuffling = 0.0
	_desk = 0.0
	_desk_target = 0.0
	if _lift_tween and _lift_tween.is_valid():
		_lift_tween.kill()
	clear_stamp()
	_packet = NO_PACKET          # force _sync_to_front to lay a fresh document
	_arrive = 0.0
	_sync_to_front()
	queue_redraw()
	set_process(true)


## Add packets to the back of the line until it reaches QUEUE_TARGET. Newcomers
## start at the back, so they get a depth AND a target — an entry without
## `target_depth` makes the shuffle in _process error every frame.
func _top_up() -> void:
	if _templates.is_empty():
		return
	while _queue.size() < QUEUE_TARGET:
		var d := float(_queue.size())
		_queue.append({
			"packet": _templates[_next_template],
			"depth": d,
			"from": d,
			"target_depth": d,
		})
		_next_template = (_next_template + 1) % _templates.size()


## Point the desk at whoever is at the glass now. If there is nobody left the
## document is cleared — otherwise the last packet stays readable and judgeable
## forever, which is exactly the bug this replaces.
func _sync_to_front() -> void:
	var front := _front()
	if front == NO_PACKET:
		_packet = NO_PACKET
		_arrive = 1.0
		close_document()
		clear_stamp()
		return
	_packet = front
	_arrive = 0.0
	# The document arrives face down; the player picks it up to read it.
	_doc_state = DocState.FLAT
	_desk = 0.0
	_desk_target = 0.0
	if _lift_tween and _lift_tween.is_valid():
		_lift_tween.kill()
	clear_stamp()


func _front() -> Packet:
	return _queue[0]["packet"] if not _queue.is_empty() else NO_PACKET


## Whoever is at the glass — the packet the document on the desk belongs to.
## Returns NO_PACKET when the line is empty.
func current_packet() -> Packet:
	return _packet


## The packet at the glass is done. It walks off — right if `approved`, left if
## denied — while the line shuffles up behind it.
##
## The packet leaves `_queue` immediately so `_front()` is already the next
## packet; only its *drawing* lingers. Gating the game state on an animation
## would leave the player waiting for a flourish.
func depart(approved: bool) -> void:
	if _queue.is_empty():
		_sync_to_front()
		return
	var gone := _queue[0]
	_leaving.append({"depth": float(gone["depth"]), "t": 0.0001, "approved": approved})
	_queue.remove_at(0)
	# Re-index what is left, THEN top up, so newcomers are appended at the back
	# with the right depth rather than inheriting a stale one.
	for i in _queue.size():
		_queue[i]["from"] = float(_queue[i]["depth"])
		_queue[i]["target_depth"] = float(i)
	_top_up()
	_shuffling = 0.0
	_departing_announced = false
	# NOTE: the document is deliberately NOT re-laid here. main.gd keeps the
	# verdict on screen while the packet walks off, and only hands over the next
	# document once `departing_finished` arrives.
	close_document()
	queue_redraw()
	set_process(true)


func _process(delta: float) -> void:
	# --- the document sliding in across the desk ---
	if _arrive < 1.0:
		_arrive = minf(1.0, _arrive + delta / ARRIVE_TIME)
		queue_redraw()

	# --- judged packets walking off ---
	if not _leaving.is_empty():
		for entry in _leaving:
			entry["t"] = float(entry["t"]) + delta / LEAVE_TIME
		# Keep only the ones still on screen.
		var alive: Array[Dictionary] = []
		for entry in _leaving:
			if float(entry["t"]) < 1.0:
				alive.append(entry)
		_leaving = alive
		queue_redraw()

	# --- the line shuffles forward ---
	if _shuffling < 1.0:
		_shuffling = minf(1.0, _shuffling + delta / SHUFFLE_TIME)
		var eased := 1.0 - pow(1.0 - _shuffling, 3.0)
		for entry in _queue:
			var from: float = entry.get("from", float(entry["depth"]))
			var target: float = entry.get("target_depth", float(entry["depth"]))
			entry["depth"] = lerpf(from, target, eased)
		queue_redraw()

	# Only idle once EVERY animation is done. Omitting the document here was a
	# real bug: the slide-in was cut off partway, freezing the sheet offset to
	# the side and still leaning, so it snapped into place and stayed tilted.
	if _all_settled():
		set_process(false)
		if not _departing_announced:
			_departing_announced = true
			departing_finished.emit()


## True when nothing is still moving: no packets walking off, the line closed
## up, the document landed, and its lift tween finished. Every animation must be
## listed here — the document's, in both directions, was the one that got missed
## and produced a paper frozen mid-tilt.
func _all_settled() -> bool:
	return _leaving.is_empty() \
		and _shuffling >= 1.0 \
		and _arrive >= 1.0 \
		and not _desk_animating() \
		and not _stamp_animating()


func _stamp_animating() -> bool:
	return _stamp_tween != null and _stamp_tween.is_valid() and _stamp_tween.is_running()


func _desk_animating() -> bool:
	return _lift_tween != null and _lift_tween.is_valid() and _lift_tween.is_running()


## Hand the next packet at the glass its document, so the sheet slides in.
## Called by main.gd once the last judged packet has finished walking off.
func advance() -> void:
	_sync_to_front()
	queue_redraw()
	set_process(true)


## Take the judged sheet away and send the packet off. Called by main.gd after
## the stamp has landed and been held for its beat — the delay lives there
## because it is a pacing decision, not a drawing one.
func finish_handover(approved: bool) -> void:
	close_document()
	depart(approved)
	set_process(true)


func _ready() -> void:
	custom_minimum_size = Vector2(ROOM_W, ROOM_H)
	mouse_filter = Control.MOUSE_FILTER_STOP


# ---------------------------------------------------------------- public API

## Nothing at the glass.
func clear_packet() -> void:
	_packet = NO_PACKET
	_doc_state = DocState.FLAT
	_desk = 0.0
	_desk_target = 0.0
	if _lift_tween and _lift_tween.is_valid():
		_lift_tween.kill()
	clear_stamp()
	queue_redraw()


## Remove the stamp, i.e. a fresh document.
func clear_stamp() -> void:
	_stamp_word = ""
	_stamp_press = 1.0
	queue_redraw()


## Ink the verdict onto the document. `approved` reflects what the PLAYER chose,
## not the correct answer — a BLOCK stamp on a legitimate packet is exactly the
## mistake worth showing them.
##
## `stamp_hit()` is emitted when the stamp lands, which is the cue the rest of
## the game waits on before taking the sheet away. Without that pause the paper
## vanished the instant it was marked and the player never saw the stamp at all.
func stamp_verdict(approved: bool) -> void:
	_stamp_word = "ALLOW" if approved else "BLOCK"
	_stamp_color = STAMP_OK if approved else STAMP_NO
	_animate_stamp()
	queue_redraw()


## Bring the stamp down onto the page. It starts above and larger, drops past its
## resting size on impact, then settles — the overshoot is what makes it read as
## a stamp landing rather than a graphic fading in.
func _animate_stamp() -> void:
	if _stamp_tween and _stamp_tween.is_valid():
		_stamp_tween.kill()
	_stamp_press = 0.0
	_stamp_tween = create_tween()
	_stamp_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_stamp_tween.tween_method(_set_stamp, 0.0, 1.0, STAMP_TIME)
	_stamp_tween.tween_callback(func() -> void: stamp_hit.emit())
	set_process(true)


func _set_stamp(v: float) -> void:
	_stamp_press = v
	queue_redraw()


## 0 = stamp still above the page, 1 = pressed flat on it.
func stamp_progress() -> float:
	return _stamp_press


## Pick the document up / lay it back down.
func toggle_document() -> void:
	if _packet == NO_PACKET:
		return
	if _doc_state == DocState.FLAT:
		_doc_state = DocState.LIFTED
		_animate_desk(1.0)
	else:
		_doc_state = DocState.FLAT
		_animate_desk(0.0)


func is_document_lifted() -> bool:
	return _doc_state == DocState.LIFTED


## True while the document is open enough to read. The decision buttons key off
## this, so they are live only while the player is actually looking at it.
func is_document_open() -> bool:
	return _desk_target > 0.5


## The verdict currently inked on the document, or "" if it is unstamped.
func stamp_word() -> String:
	return _stamp_word

## Raise or lower the document. BOTH directions are animated: snapping it down
## on a verdict reads as the paper glitching back to the desk, which is exactly
## what it looked like before this was a tween.
func _animate_desk(target: float) -> void:
	var was_open := is_document_open()
	_desk_target = target
	# Announce the state change immediately — not when the tween finishes — so
	# the UI reacts on the same frame the player clicks.
	if is_document_open() != was_open:
		document_state_changed.emit(is_document_open())
	if _lift_tween and _lift_tween.is_valid():
		_lift_tween.kill()
	_lift_tween = create_tween()
	_lift_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lift_tween.tween_method(_set_desk, _desk, target, 0.32)
	# Keep ticking: _process must stay alive until this tween finishes, or the
	# sheet freezes halfway between desk and hand.
	set_process(true)


## Animation-only setter. It must NOT emit document_state_changed: the gate is
## owned by _desk_target, and emitting from both would fire mid-tween.
func _set_desk(v: float) -> void:
	_desk = v
	queue_redraw()


# ---------------------------------------------------------------- input
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# Clicking the document itself picks it up or puts it down.
		if _document_rect().has_point(event.position):
			toggle_document()
			accept_event()


## Where the document is drawn right now, in local coordinates.
func _document_rect() -> Rect2:
	var info := _doc_rect_now()
	return info[0]


## Lay the document back down. Animated — see _animate_desk().
func close_document() -> void:
	if _doc_state == DocState.FLAT and is_equal_approx(_desk_target, 0.0):
		return
	_doc_state = DocState.FLAT
	_animate_desk(0.0)


## Flat placement (squashed onto the desk) blended toward the lifted one.
## Returns [rect, shear]; shear is zero once fully lifted.
##
## While `_arrive` is under 1 the whole sheet is offset to the right and leaning
## back — it is being handed across the counter — and both settle to zero as it
## lands.
func _doc_rect_now() -> Array:
	var rect := Rect2(
		DOC_FLAT.position.lerp(DOC_LIFTED.position, _desk),
		DOC_FLAT.size.lerp(DOC_LIFTED.size, _desk)
	)
	var squash := lerpf(FLAT_SQUASH, 1.0, _desk)
	var shear := lerpf(FLAT_SHEAR, 0.0, _desk)
	rect.size.y *= squash

	# Feed-in: the sheet rises out of the slot and eases into place, so the
	# offset is vertical. A horizontal slide read as the paper flying in from
	# off-screen rather than being handed through the window.
	if _arrive < 1.0:
		var slide := 1.0 - pow(1.0 - _arrive, 3.0)
		rect.position.y += ARRIVE_FROM_Y * (1.0 - slide)
	return [rect, shear]


## Lean applied to the document while it is still being handed over. Zero once
## it has landed.
func _doc_lean() -> float:
	if _arrive >= 1.0:
		return 0.0
	return 0.075 * (1.0 - _arrive)


# ---------------------------------------------------------------- draw
func _draw() -> void:
	_draw_wall()
	_draw_window()          # the opening, its frame, and what is outside
	_draw_desk()
	_draw_board()           # manual clipboard
	_draw_document()        # the packet's ID, flat or lifted
	_draw_lamp()
	_draw_grain()
	_draw_vignette()


# --- the room -------------------------------------------------------------

func _draw_wall() -> void:
	draw_rect(Rect2(0, 0, ROOM_W, ROOM_H), WALL, true)
	# Overhead light fades downward.
	for i in 18:
		var t := float(i) / 17.0
		draw_rect(Rect2(0, i * 26.0, ROOM_W, 26.0),
			Color(WALL_LIT.r, WALL_LIT.g, WALL_LIT.b, 0.5 * (1.0 - t)), true)

	# Slab walls: sunk joints, so the room reads as poured concrete rather than
	# flat fill. Cheap, and it stops the background looking like empty screen.
	draw_rect(Rect2(0, 300.0, ROOM_W, 3.0), Color(0, 0, 0, 0.22), true)
	draw_rect(Rect2(0, 302.0, ROOM_W, 1.0), Color(1, 0.9, 0.75, 0.05), true)
	for sx in [140.0, 1780.0]:
		draw_rect(Rect2(sx, 0, 3.0, ROOM_H), Color(0, 0, 0, 0.20), true)

	# The brass nameplate the sign is engraved on. Without a plate the amber
	# lettering sits on dark wall and almost vanishes.
	_draw_brass_plate(Rect2(608.0, 170.0, 704.0, 44.0))


## A brass plate with bevelled edges, corner screws and a soft sheen.
func _draw_brass_plate(plate: Rect2) -> void:
	draw_rect(Rect2(plate.position.x + 4.0, plate.position.y + 5.0, plate.size.x, plate.size.y),
		Color(0, 0, 0, 0.5), true)
	draw_rect(plate, BRASS_DARK, true)
	draw_rect(plate.grow(-3.0), BRASS, true)
	# Bevel: lit top-left, shadowed bottom-right.
	draw_rect(Rect2(plate.position.x, plate.position.y, plate.size.x, 3.0), BRASS_LIT, true)
	draw_rect(Rect2(plate.position.x, plate.position.y, 3.0, plate.size.y), BRASS_LIT, true)
	draw_rect(Rect2(plate.position.x, plate.position.y + plate.size.y - 3.0, plate.size.x, 3.0),
		Color(0, 0, 0, 0.45), true)
	draw_rect(Rect2(plate.position.x + plate.size.x - 3.0, plate.position.y, 3.0, plate.size.y),
		Color(0, 0, 0, 0.45), true)
	# Sheen across the middle.
	for i in 6:
		var tt := float(i) / 5.0
		draw_rect(Rect2(plate.position.x + 6.0, plate.position.y + 6.0 + tt * 2.0,
			plate.size.x - 12.0, 1.0), Color(1, 0.93, 0.75, 0.05 * (1.0 - tt)), true)
	for sx in [plate.position.x + 12.0, plate.end.x - 12.0]:
		for sy in [plate.position.y + 12.0, plate.end.y - 12.0]:
			draw_circle(Vector2(sx, sy), 3.5, BRASS_LIT)
			draw_circle(Vector2(sx, sy), 2.0, BRASS_DARK)


# The booth window: thick frame, dark recess, and the queue beyond the glass.
func _draw_window() -> void:
	# Recess: the wall is thick, so draw a darker lip around the opening.
	draw_rect(OPENING.grow(FRAME_W), WALL_DARK, true)

	# Outside: night sky gradient, banded.
	var bands := 20
	var h := OPENING.size.y / float(bands)
	for i in bands:
		var t := float(i) / float(bands - 1)
		draw_rect(Rect2(OPENING.position.x, OPENING.position.y + i * h,
			OPENING.size.x, h + 1.0), NIGHT_TOP.lerp(NIGHT_BOTTOM, t), true)
	# Floor haze near the ground.
	draw_rect(Rect2(OPENING.position.x, OPENING.position.y + OPENING.size.y * 0.66,
		OPENING.size.x, OPENING.size.y * 0.34), Color(0.17, 0.20, 0.20, 0.55), true)

	# What is actually outside the glass: the network floor the packets come in
	# from, not a city. Drawn before the line so the packets stand in front of it.
	_draw_network_floor()

	# The line is drawn clipped to the opening — see _draw_box_packet().
	_draw_queue()

	# Glass: tint, streaks and a reflection, over the queue.
	draw_rect(OPENING, Color(0.16, 0.20, 0.22, 0.30), true)
	for i in 7:
		var x := OPENING.position.x + 60.0 + i * (OPENING.size.x - 120.0) / 6.0
		draw_rect(Rect2(x, OPENING.position.y, 5.0 + (i % 3) * 4.0, OPENING.size.y),
			Color(1, 1, 1, 0.020), true)
	draw_colored_polygon(PackedVector2Array([
		OPENING.position + Vector2(150, 0),
		OPENING.position + Vector2(260, 0),
		OPENING.position + Vector2(OPENING.size.x * 0.70, OPENING.size.y),
		OPENING.position + Vector2(OPENING.size.x * 0.52, OPENING.size.y),
	]), Color(0.85, 0.90, 0.95, 0.030))

	# The frame itself, drawn last so it sits in front of the glass.
	var o := OPENING.grow(FRAME_W)
	draw_rect(Rect2(o.position.x, o.position.y, o.size.x, FRAME_W), FRAME, true)
	draw_rect(Rect2(o.position.x, o.position.y + o.size.y - FRAME_W, o.size.x, FRAME_W), FRAME, true)
	draw_rect(Rect2(o.position.x, o.position.y, FRAME_W, o.size.y), FRAME, true)
	draw_rect(Rect2(o.position.x + o.size.x - FRAME_W, o.position.y, FRAME_W, o.size.y), FRAME, true)
	# bevel
	draw_rect(Rect2(o.position.x, o.position.y, o.size.x, 4), FRAME_LIT, true)
	draw_rect(Rect2(o.position.x, o.position.y, 4, o.size.y), FRAME_LIT, true)
	draw_rect(Rect2(o.position.x, o.position.y + o.size.y - 4, o.size.x, 4), FRAME_DARK, true)
	draw_rect(Rect2(o.position.x + o.size.x - 4, o.position.y, 4, o.size.y), FRAME_DARK, true)
	_bolts(OPENING)


# --- what is outside the glass -------------------------------------------

## The far side of the firewall: a network operations floor, seen through the
## window.
##
## This replaced a city skyline. A skyline of towers with lit windows looks almost
## identical to a hall of equipment racks covered in status LEDs — same vertical
## masses, same scatter of warm and cold points — so the picture costs the same and
## now means something. The dots are link lights, not apartment windows; the
## horizontals are cable trays, not walkways; the bright line on the floor is the
## trunk the packets arrive on.
##
## Nothing here is a tower and nothing is a building. If you are adding to it, keep
## that true: this is the infrastructure a packet crossed to reach the booth.
func _draw_network_floor() -> void:
	var rng := RandomNumberGenerator.new()
	# Fixed seed: the hall must look the same on every redraw, or the background
	# would crawl every frame the window invalidates.
	rng.seed = 90210

	var left := OPENING.position.x
	var right := OPENING.end.x
	var floor_y := OPENING.position.y + OPENING.size.y * 0.88

	# Upper cable tray. Horizontal, with support hangers dropping from it — the
	# detail that stops the far wall reading as empty space.
	var tray_y := OPENING.position.y + 26.0
	draw_rect(Rect2(left, tray_y, OPENING.size.x, 5.0), Color(0.07, 0.11, 0.12, 0.95), true)
	draw_rect(Rect2(left, tray_y, OPENING.size.x, 2.0), Color(0.20, 0.30, 0.30, 0.85), true)
	for x in range(int(left) + 40, int(right), 130):
		draw_rect(Rect2(x, tray_y + 5.0, 3.0, 16.0), Color(0.06, 0.10, 0.11, 0.9), true)

	# A second tray lower down, so the cabling reads as several runs.
	var tray2_y := OPENING.position.y + OPENING.size.y * 0.30
	draw_rect(Rect2(left, tray2_y, OPENING.size.x, 4.0), Color(0.06, 0.10, 0.11, 0.85), true)

	# THE RACKS. Deliberately WIDE and SHORT, and packed together with small gaps.
	#
	# This matters more than it looks. A first pass used narrow cabinets (46-108 px)
	# with height varied 120-300 px and gaps up to 22 px, and the result read as a
	# city skyline again — narrow vertical masses, uneven heights, sky between them.
	# Buildings and cabinets are told apart by proportion, not by the lights: wide,
	# short and tightly packed reads as equipment; tall, thin and gappy reads as a
	# skyline no matter what colour the dots are.
	var x := left - 20.0
	while x < right:
		var w := rng.randf_range(92.0, 190.0)
		var h := rng.randf_range(96.0, 205.0)
		var top := floor_y - h
		# Body, then a lighter front face and a darker seam, so each cabinet has a
		# near edge and a far edge without needing any real geometry.
		var body := Color(0.055, 0.085, 0.095).lerp(Color(0.10, 0.15, 0.16), rng.randf())
		draw_rect(Rect2(x, top, w, h), body, true)
		draw_rect(Rect2(x, top, w, 3.0), Color(0.16, 0.24, 0.24, 0.9), true)
		draw_rect(Rect2(x + w - 2.0, top, 2.0, h), Color(0, 0, 0, 0.55), true)

		# Unit seams down the front, every so often.
		var seam := top + 10.0
		while seam < floor_y - 8.0:
			draw_rect(Rect2(x + 3.0, seam, w - 6.0, 1.0), Color(0, 0, 0, 0.35), true)
			seam += rng.randf_range(14.0, 26.0)

		# The link lights. Cyan is traffic, amber is activity, green is link-up —
		# the same three colours the booth's own verdict lamp uses, and the reason
		# this reads as equipment rather than as a night skyline.
		var lights := int((w * h) / 900.0)
		for i in lights:
			var lx := x + 5.0 + rng.randf_range(0.0, w - 12.0)
			var ly := top + 6.0 + rng.randf_range(0.0, h - 14.0)
			var pick := rng.randf()
			var col := SHIELD_BLUE
			if pick > 0.72:
				col = LAMP_WARM
			elif pick > 0.44:
				col = ALLOW_GREEN
			col.a = rng.randf_range(0.45, 1.0)
			draw_rect(Rect2(lx, ly, 2.0, 2.0), col, true)

		# Patch strips: dense horizontal runs of ports across the middle of every
		# cabinet. This is the detail that says "network equipment" outright, and it
		# also fills the tall empty area that made the first pass look like buildings.
		var strip_y := top + h * rng.randf_range(0.22, 0.40)
		draw_rect(Rect2(x + 4.0, strip_y, w - 8.0, 7.0), Color(0.02, 0.04, 0.05, 0.9), true)
		var port_x := x + 6.0 + 1.0
		while port_x < x + w - 8.0:
			var up := rng.randf() > 0.42
			var pc := SHIELD_BLUE if rng.randf() > 0.35 else ALLOW_GREEN
			pc.a = 0.9 if up else 0.14
			draw_rect(Rect2(port_x, strip_y + 1.5, 3.0, 4.0), pc, true)
			port_x += 5.0

		x += w + rng.randf_range(2.0, 9.0)

	# The floor: a dark apron, then the lit trunk line the packets travel along.
	draw_rect(Rect2(left, floor_y, OPENING.size.x, OPENING.end.y - floor_y),
		Color(0.03, 0.05, 0.06, 0.98), true)
	draw_rect(Rect2(left, floor_y, OPENING.size.x, 2.0), Color(0.30, 0.62, 0.66, 0.9), true)
	# Data pulses on the trunk: short bright dashes that read as traffic in flight.
	var px := left + rng.randf_range(10.0, 60.0)
	while px < right:
		draw_rect(Rect2(px, floor_y - 1.0, rng.randf_range(10.0, 34.0), 3.0),
			Color(SHIELD_BLUE.r, SHIELD_BLUE.g, SHIELD_BLUE.b, rng.randf_range(0.35, 0.95)), true)
		px += rng.randf_range(60.0, 150.0)

	# Uplinks: a few thin vertical runs from the racks up into the top tray, so the
	# two trays are visibly connected rather than being stripes of decoration.
	for i in 6:
		var ux := left + rng.randf_range(40.0, OPENING.size.x - 40.0)
		draw_rect(Rect2(ux, tray_y + 5.0, 2.0, floor_y - tray_y - 5.0),
			Color(0.09, 0.16, 0.17, 0.75), true)

	# A rack-status panel on the far wall, reading as a bank of link indicators.
	var panel := Rect2(left + OPENING.size.x * 0.06, OPENING.position.y + 52.0, 96.0, 40.0)
	draw_rect(panel, Color(0.04, 0.07, 0.08, 0.95), true)
	draw_rect(panel.grow(1.0), Color(0.18, 0.30, 0.30, 0.6), false, 1.0)
	for row in 3:
		for col_i in 8:
			var on := rng.randf() > 0.35
			var c := SHIELD_BLUE if (row + col_i) % 3 else LAMP_WARM
			c.a = 0.85 if on else 0.16
			draw_rect(Rect2(panel.position.x + 6.0 + col_i * 11.0,
				panel.position.y + 6.0 + row * 11.0, 5.0, 5.0), c, true)


## Bolts at the four corners of the opening, so the frame reads as bolted on.
func _bolts(opening: Rect2) -> void:
	for corner in [opening.position, Vector2(opening.end.x, opening.position.y),
			Vector2(opening.position.x, opening.end.y), opening.end]:
		draw_circle(corner, BOLT_R, STEEL)
		draw_circle(corner - Vector2(2, 2), BOLT_R * 0.6, STEEL_LIT)
		draw_circle(corner + Vector2(2, 2), BOLT_R * 0.4, Color(0, 0, 0, 0.4))


# The queue: one box at the glass, the rest in single file directly behind it,
# shrinking and darkening into shadow with distance.
#
# All of them share one x, so the line recedes straight back down the middle of
# the opening rather than fanning out. Because "further" also means "higher",
# the boxes stack upward and the nearer ones naturally overlap the ones behind,
# which is what sells the depth.
func _draw_queue() -> void:
	# Farthest first, so nearer boxes draw over the ones behind them.
	var order: Array[Dictionary] = _queue.duplicate()
	order.reverse()
	for entry in order:
		var depth: float = entry["depth"]
		if depth >= float(QUEUE_VISIBLE):
			continue
		var scale := _depth_scale(depth)
		var w := BOX_W * scale
		var h := BOX_H * scale
		var ground := LANE_BASE_Y - depth * LANE_RISE
		_draw_contact_shadow(LANE_X, ground, w, _depth_lit(depth))
		_draw_box_packet(Vector2(LANE_X - w * 0.5, ground - h), Vector2(w, h),
			_depth_lit(depth), _is_shadow(depth), 1.0, OPENING)

	# Judged packets on their way out, drawn last so they pass in front.
	for entry in _leaving:
		_draw_departing(entry)


## How much smaller and dimmer a packet is `depth` places back in the line.
func _depth_scale(depth: float) -> float:
	return 1.0 - depth * DEPTH_SHRINK


func _depth_lit(depth: float) -> float:
	return clampf(1.0 - depth * DEPTH_DIM, 0.14, 1.0)


## Everything queued behind the packet at the glass is a flat silhouette.
static func _is_shadow(depth: float) -> bool:
	return depth > 0.5


## A soft dark ellipse where a packet meets the floor, so the line reads as
## standing on a surface rather than floating in the dark. Clamped to the
## opening so it cannot bleed onto the wall either.
func _draw_contact_shadow(cx: float, ground: float, box_w: float, lit: float) -> void:
	var rx := box_w * CONTACT_W
	var ry := 11.0 + box_w * 0.035
	var left := maxf(cx - rx, OPENING.position.x)
	var right := minf(cx + rx, OPENING.end.x)
	if right <= left:
		return
	rx = (right - left) * 0.5
	var centre := (left + right) * 0.5
	var a := 0.30 * clampf(lit, 0.15, 1.0)
	draw_set_transform(Vector2(centre, ground), 0.0, Vector2(1.0, ry / rx))
	draw_circle(Vector2.ZERO, rx, Color(0, 0, 0, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A judged packet: strides left or right, waddling, fading as it goes.
func _draw_departing(entry: Dictionary) -> void:
	var t: float = clampf(float(entry["t"]), 0.0, 1.0)
	var depth: float = float(entry["depth"])
	var dir := 1.0 if bool(entry["approved"]) else -1.0
	var dist := 1180.0                      # far enough to leave the frame

	# Ease out, so it strides away rather than sliding at constant speed.
	var travel := dist * (1.0 - pow(1.0 - t, 2.2)) * dir
	# Waddle: a rock and a small hop, both settling as it recedes. The rock is
	# kept modest — a big lean makes a box look like it is falling over.
	var phase := t * 24.0
	var rock := sin(phase) * 0.055 * (1.0 - t)
	var hop := absf(sin(phase)) * 13.0 * (1.0 - t)

	var scale := _depth_scale(depth)
	var w := BOX_W * scale
	var h := BOX_H * scale
	var cx := LANE_X + travel
	var ground := LANE_BASE_Y - depth * LANE_RISE - hop
	var alpha := clampf(1.0 - pow(t, 1.35), 0.0, 1.0)
	if alpha <= 0.004:
		return

	var box := Rect2(cx - w * 0.5, ground - h, w, h)
	# Waddle only while the packet is wholly inside the window. Once it starts
	# leaving, the lean is dropped: clipping a rotated quad would need real
	# polygon clipping, and a straight slide out of frame looks correct anyway.
	var wholly_inside := box.position.x >= OPENING.position.x \
		and box.end.x <= OPENING.end.x \
		and box.position.y >= OPENING.position.y \
		and box.end.y <= OPENING.end.y
	if wholly_inside and absf(rock) > 0.0005:
		var centre := box.get_center()
		draw_set_transform_matrix(_rotation_about(centre, rock))
		_draw_box_packet(box.position, box.size, 1.0, false, alpha)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_draw_box_packet(box.position, box.size, 1.0, false, alpha, OPENING)


## One packet: a shipping box with a face panel taped to the front.
## `lit` 1.0 is the packet at the glass; lower values are in shadow.
## `alpha` fades the whole box out as it walks away.
##
## Everything is clipped to the opening by hand. `canvas_item_set_clip()` does
## NOT work here: the clip is sampled when the canvas item is drawn, so calling
## it from inside `_draw()` is too late — verified by A/B rendering the same
## frame with and without it, which produced byte-identical images. Composing
## inside `clip` is the reliable way for rects.
func _draw_box_packet(top_left: Vector2, size: Vector2, lit: float, shadow: bool = false,
		alpha: float = 1.0, clip: Rect2 = Rect2()) -> void:
	if alpha <= 0.004:
		return
	var box := Rect2(top_left, size)
	var r := box
	if clip.size.x > 0.0:
		# A box that is entirely clear of the window is not drawn at all, which
		# is what makes a departing packet vanish at the frame edge.
		r = r.intersection(clip)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			return
		# Is ANY of it cut off? Tested by edges rather than by comparing sizes—
		# comparing `r.size` to `size` reads as "unchanged" in cases where an edge
		# has in fact moved.
		var untouched := r.position.x <= top_left.x + 0.01 \
			and r.position.y <= top_left.y + 0.01 \
			and r.end.x >= top_left.x + size.x - 0.01 \
			and r.end.y >= top_left.y + size.y - 0.01
		if not untouched:
			# Partly outside the window. The label is drawn in BOX coordinates and
			# only its visible part is kept, so it stays bolted to the packet and
			# slides out with it. Deriving it from the clipped rect instead moves
			# it as the visible slice shrinks — the label then appears to slide
			# across the face of the box, which is worse than the bug it replaced.
			_draw_box_clipped(r, box, lit, shadow, alpha)
			return
		_draw_box_full(r, lit, shadow, alpha, size)
		return
	_draw_box_full(r, lit, shadow, alpha, size)


## Box body with lit top/left and shadowed bottom/right, plus the taped label.
func _draw_box_full(r: Rect2, lit: float, shadow: bool, alpha: float, full: Vector2) -> void:
	if shadow:
		var body := _shadow_body(lit, alpha)
		draw_rect(r, body, true)
		var rim := Color(body.r + 0.055, body.g + 0.06, body.b + 0.06, body.a)
		draw_rect(Rect2(r.position.x, r.position.y, full.x, 2.0), rim, true)
		draw_rect(Rect2(r.position.x, r.position.y, 2.0, full.y), rim, true)
		return

	var body := Color("#4a3826").lerp(Color("#6f5636"), lit)
	body.a *= alpha
	var hi := body.lightened(0.30)
	var hi2 := body.lightened(0.22)
	var edge := body.darkened(0.45)
	var tape := body.darkened(0.25)
	var label := PAPER.darkened(0.10)
	label.a *= alpha

	draw_rect(r, body, true)
	# Top and left lit edges, bottom and right in shadow — enough for volume.
	draw_rect(Rect2(r.position.x, r.position.y, full.x, 2.5), hi, true)
	draw_rect(Rect2(r.position.x, r.position.y, 2.5, full.y), hi2, true)
	draw_rect(Rect2(r.position.x, r.position.y + full.y - 3, full.x, 3), edge, true)
	draw_rect(Rect2(r.position.x + full.x - 3, r.position.y, 3, full.y), edge, true)
	# The paper label taped to the front — this is the "face".
	var face_w := full.x * 0.62
	var face_h := full.y * 0.30
	var face_rect := Rect2(r.position.x + (full.x - face_w) * 0.5,
		r.position.y + full.y * 0.22, face_w, face_h)
	draw_rect(face_rect, label, true)
	draw_rect(Rect2(face_rect.position.x, face_rect.position.y, face_rect.size.x, 2), label, true)
	# Tape strip across the top of the box.
	draw_rect(Rect2(r.position.x + full.x * 0.46, r.position.y, full.x * 0.08,
		full.y * 0.22), tape, true)


## A partly clipped box: the visible slice of the body, with the label and tape
## placed in BOX coordinates and clipped to the same slice. Anchoring them to the
## box (not to the slice) is what keeps the label stuck to the packet as it
## leaves, rather than travelling across the face of it.
func _draw_box_clipped(r: Rect2, box: Rect2, lit: float, shadow: bool, alpha: float) -> void:
	if shadow:
		draw_rect(r, _shadow_body(lit, alpha), true)
		return
	var body := _lit_body(lit, alpha)
	var label := PAPER.darkened(0.10)
	label.a *= alpha
	var tape := body.darkened(0.25)

	draw_rect(r, body, true)

	# Same geometry as _draw_box_full(), measured from the real box...
	var face_w := box.size.x * 0.62
	var face_h := box.size.y * 0.30
	var face := Rect2(box.position.x + (box.size.x - face_w) * 0.5,
		box.position.y + box.size.y * 0.22, face_w, face_h)
	var strip := Rect2(box.position.x + box.size.x * 0.46, box.position.y,
		box.size.x * 0.08, box.size.y * 0.22)

	# ...then intersected with what is actually visible, so each is cut off by the
	# window edge exactly like the body.
	var face_vis := face.intersection(r)
	if face_vis.size.x > 0.0 and face_vis.size.y > 0.0:
		draw_rect(face_vis, label, true)
	var strip_vis := strip.intersection(r)
	if strip_vis.size.x > 0.0 and strip_vis.size.y > 0.0:
		draw_rect(strip_vis, tape, true)


func _shadow_body(lit: float, alpha: float) -> Color:
	var c := Color("#0f1418").lerp(Color("#2b3339"), clampf(lit, 0.0, 1.0))
	c.a *= alpha
	return c


func _lit_body(lit: float, alpha: float) -> Color:
	var c := Color("#4a3826").lerp(Color("#6f5636"), lit)
	c.a *= alpha
	return c


# --- the desk -------------------------------------------------------------

func _draw_desk() -> void:
	draw_rect(Rect2(0, DESK_Y, ROOM_W, ROOM_H - DESK_Y), DESK, true)
	# Lit near edge, then the surface falling away.
	draw_rect(Rect2(0, DESK_Y, ROOM_W, 6), DESK_LIT, true)
	for i in 22:
		var t := float(i) / 21.0
		draw_rect(Rect2(0, DESK_Y + 6 + i * 8.0, ROOM_W, 8.0),
			Color(0, 0, 0, 0.05 * t), true)
	# A seam down the middle of the desk.
	draw_rect(Rect2(ROOM_W * 0.5 - 2, DESK_Y, 4, ROOM_H - DESK_Y), DESK_DARK, true)
	# Warm pool of light where the lamp falls, centred under it.
	var lamp_x := ROOM_W * 0.5
	for i in 14:
		var t := float(i) / 13.0
		var w := 640.0 + t * 760.0
		draw_rect(Rect2(lamp_x - w * 0.5, DESK_Y, w, 30.0 + t * 60.0),
			Color(LAMP_WARM.r, LAMP_WARM.g, LAMP_WARM.b, 0.022 * (1.0 - t)), true)

	_draw_doc_slot()


## The slot the documents come through: a framed opening in the bench, directly
## under where a sheet lands. Paper arrives out of it and is fed back into it,
## which is what makes the hand-over read as a mechanism rather than a graphic
## appearing. Drawn before the document so the sheet covers it while present.
func _draw_doc_slot() -> void:
	var slot := SLOT
	# Recess: dark inside, with a lip of shadow along the top edge where the
	# bench overhangs it.
	draw_rect(slot, Color("#0a0705"), true)
	draw_rect(Rect2(slot.position.x, slot.position.y, slot.size.x, 10.0),
		Color(0, 0, 0, 0.85), true)
	draw_rect(Rect2(slot.position.x, slot.position.y, slot.size.x, 4.0),
		Color(0, 0, 0, 0.95), true)
	# Brushed metal lip all the way round, lit on the near edge.
	var lip := 6.0
	draw_rect(Rect2(slot.position.x - lip, slot.position.y - lip,
		slot.size.x + lip * 2.0, lip), BRASS, true)
	draw_rect(Rect2(slot.position.x - lip, slot.position.y - lip,
		slot.size.x + lip * 2.0, 2.0), BRASS_LIT, true)
	draw_rect(Rect2(slot.position.x - lip, slot.end.y, slot.size.x + lip * 2.0, lip), BRASS_DARK, true)
	draw_rect(Rect2(slot.position.x - lip, slot.position.y - lip, lip, slot.size.y + lip * 2.0),
		BRASS, true)
	draw_rect(Rect2(slot.end.x, slot.position.y - lip, lip, slot.size.y + lip * 2.0),
		BRASS_DARK, true)
	# Screws at the corners of the lip.
	for corner in [Vector2(slot.position.x - lip * 0.5, slot.position.y - lip * 0.5),
			Vector2(slot.end.x + lip * 0.5, slot.position.y - lip * 0.5),
			Vector2(slot.position.x - lip * 0.5, slot.end.y + lip * 0.5),
			Vector2(slot.end.x + lip * 0.5, slot.end.y + lip * 0.5)]:
		draw_circle(corner, 4.0, BRASS_LIT)
		draw_circle(corner, 2.2, BRASS_DARK)


# --- the manual, on a clipboard ------------------------------------------

func _draw_board() -> void:
	# Board, slightly darker than the desk, with a clip at the top.
	draw_rect(Rect2(BOARD.position.x + 6, BOARD.position.y + 8, BOARD.size.x, BOARD.size.y),
		Color(0, 0, 0, 0.35), true)
	draw_rect(BOARD, Color("#4a3626"), true)
	draw_rect(Rect2(BOARD.position.x, BOARD.position.y, BOARD.size.x, 4), Color("#6b5038"), true)
	draw_rect(Rect2(BOARD.position.x, BOARD.position.y + BOARD.size.y - 4, BOARD.size.x, 4),
		Color("#2a1e14"), true)
	var clip := Rect2(BOARD.position.x + BOARD.size.x * 0.30, BOARD.position.y - 16,
		BOARD.size.x * 0.40, 30)
	draw_rect(clip, STEEL, true)
	draw_rect(Rect2(clip.position.x, clip.position.y, clip.size.x, 4), STEEL_LIT, true)

	# The sheet of rules clipped to it. The rules themselves are a real Label
	# node overlaid by main.tscn — text drawn as bars here would be unreadable
	# and would duplicate the manual in two places.
	var sheet := BOARD.grow(-16)
	sheet.position.y += 10
	draw_rect(sheet, PAPER.darkened(0.06), true)
	draw_rect(Rect2(sheet.position.x, sheet.position.y + sheet.size.y - 3, sheet.size.x, 3),
		PAPER_EDGE, true)
	draw_rect(Rect2(sheet.position.x, sheet.position.y, sheet.size.x, 2), Color(0, 0, 0, 0.08), true)


# --- the document ---------------------------------------------------------

## The packet's ID card. Lying flat it is squashed and sheared; lifted it
## stands up and fills the middle of the screen.
func _draw_document() -> void:
	if _packet == NO_PACKET:
		return
	var info := _doc_rect_now()
	var rect: Rect2 = info[0]
	var shear: float = info[1]
	var lean := _doc_lean()

	# Shadow, offset down-right so the sheet looks laid on the desk. Fades as it
	# rises, since a lifted page casts less on the surface.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _desk < 0.5:
		draw_rect(Rect2(rect.position.x + 10, rect.position.y + 12, rect.size.x, rect.size.y),
			Color(0, 0, 0, 0.35 * (1.0 - _desk)), true)

	# One rotation about the paper's BOTTOM edge. Pivoting at the centre makes it
	# look like it is floating and spinning; pivoting at the bottom edge reads as
	# a sheet being lifted off the desk and tilted toward you. The lean while it
	# is being handed over is folded into the same rotation.
	var pivot := Vector2(rect.get_center().x, rect.end.y)
	if absf(lean) > 0.0005:
		draw_set_transform_matrix(_rotation_about(pivot, lean))

	# A sheared "page": draw the body as a parallelogram, everything else in
	# the transformed space.
	var skew := shear * rect.size.y
	var page := PackedVector2Array([
		Vector2(rect.position.x + skew, rect.position.y),
		Vector2(rect.position.x + rect.size.x + skew, rect.position.y),
		Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y),
		Vector2(rect.position.x, rect.position.y + rect.size.y),
	])
	draw_colored_polygon(page, PAPER if _desk > 0.5 else PAPER_SHADE)
	# Edges.
	draw_polyline(PackedVector2Array([page[0], page[1]]), PAPER_EDGE, 2.0)
	draw_polyline(PackedVector2Array([page[3], page[2]]), PAPER_EDGE, 2.0)
	draw_polyline(PackedVector2Array([page[0], page[3]]), PAPER_EDGE, 2.0)
	draw_polyline(PackedVector2Array([page[1], page[2]]), PAPER_EDGE, 2.0)

	# Content is drawn in a sheared space so it lies on the page.
	draw_set_transform(Vector2(skew, 0.0), 0.0, Vector2.ONE)
	_draw_document_content(rect)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The form on the page: a header, one row per ID field, and — once lifted —
## the verdict stamp. `rect` is the page in the sheared space, so content only
## needs to stay inside it.
##
## Text is drawn with real glyphs via draw_string(). An earlier pass blocked the
## text out as bars, which is stable but unreadable — and a document the player
## cannot read is not a document.
func _draw_document_content(rect: Rect2) -> void:
	var font: Font = _ui_font()
	var s := rect.size.x / 540.0          # 1.0 at lifted size
	var pad := 34.0 * s
	var x := rect.position.x + pad
	var w := rect.size.x - pad * 2.0
	var y := rect.position.y + 38.0 * s
	var has_font := font != null

	# Header: agency line, then the document title.
	draw_rect(Rect2(x, y, w, 2.0 * s), INK, true)
	y += 14.0 * s
	if has_font:
		_text("NETWORK BORDER CONTROL", Vector2(x, y + 13.0 * s), 13.0 * s, INK_FAINT)
	y += 24.0 * s
	if has_font:
		_text("PACKET IDENTIFICATION", Vector2(x, y + 20.0 * s), 21.0 * s, INK)
	y += 32.0 * s
	draw_rect(Rect2(x, y, w, 2.0 * s), INK, true)
	y += 26.0 * s

	# Field rows.
	var rows := [
		["SOURCE IP", _packet.source_ip],
		["DESTINATION PORT", str(_packet.destination_port)],
		["PROTOCOL", _packet.protocol],
		["PAYLOAD", _packet.payload],
	]
	for row in rows:
		if has_font:
			_text(row[0], Vector2(x, y + 11.0 * s), 12.0 * s, INK_FAINT)
			_text(row[1], Vector2(x + w * 0.32, y + 15.0 * s), 17.0 * s, INK)
		y += 30.0 * s
		draw_rect(Rect2(x, y - 10.0 * s, w, 1.0 * s), Color(0, 0, 0, 0.10), true)

	# Stamped verdict, inked across the lower half of the form — but only once
	# the player has actually ruled on this packet, and only once the stamp has
	# come down onto the page.
	if _desk > 0.6 and not _stamp_word.is_empty() and _stamp_press > 0.001:
		_draw_stamp_descending(Rect2(x + w * 0.30, y + 14.0 * s, w * 0.70, 104.0 * s), s)

	# Wear: a horizontal fold and a vertical crease.
	draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * 0.52, rect.size.x, 2.0),
		Color(0, 0, 0, 0.10), true)
	draw_rect(Rect2(rect.position.x + rect.size.x * 0.5, rect.position.y, 2.0, rect.size.y),
		Color(0, 0, 0, 0.07), true)


func _text(sv: String, pos: Vector2, size: float, c: Color) -> void:
	var font := _ui_font()
	if font == null:
		return
	draw_string(font, pos, sv, HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(size, 6.0)), c)


## The shared UI font. Prefers the UiFont autoload but falls back to the theme
## font, because autoloads are not registered when a script runs under
## `--script` (the headless harness) and the document must draw there too.
func _ui_font() -> Font:
	var node := get_node_or_null("/root/UiFont")
	if node != null and node.get("font") != null:
		return node.get("font")
	return ThemeDB.fallback_font


## The stamp on its way down. `_stamp_press` runs 0 -> 1: it starts above the page,
## oversized and faint, then lands. The press is simulated by scaling slightly
## past its resting size at the moment of impact and easing back, which is what
## sells it as a physical stamp rather than a graphic appearing.
func _draw_stamp_descending(r: Rect2, s: float) -> void:
	var k := clampf(_stamp_press, 0.0, 1.0)
	var centre := r.get_center()
	# Above the page and larger while falling.
	var rise := (1.0 - k) * 90.0 * s
	# Overshoot: biggest a hair after impact, then settle.
	var press := 1.0 + sin(k * PI) * 0.10
	var scale_v := Vector2(press, press)

	draw_set_transform_matrix(
		_rotation_about(centre, STAMP_TILT)
		* Transform2D(0.0, Vector2(0.0, -rise))
		* Transform2D(0.0, Vector2.ZERO).scaled(scale_v)
		* Transform2D(0.0, -centre)
		* Transform2D(0.0, centre))
	# Faint while falling, solid once it bites.
	var c := _stamp_color
	c.a = clampf(0.35 + k * 0.65, 0.0, 1.0)
	_stamp_at(r, s, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A rubber stamp, inked onto the form: ALLOW in green, BLOCK in red.
##
## Drawn tilted on purpose. The word matches the action buttons, so an
## axis-aligned box with a neat border reads as a *clickable button* rather than
## a stamp on paper — the rotation is what makes it unambiguous.
func _stamp(r: Rect2, s: float) -> void:
	_stamp_at(r, s, _stamp_color)


func _stamp_at(r: Rect2, s: float, c: Color) -> void:
	var label := _stamp_word
	var centre := r.get_center()
	var t := 4.0 * s

	# Build the border as rotated quads so the whole stamp leans together.
	var bars := [
		Rect2(r.position.x, r.position.y, r.size.x, t),
		Rect2(r.position.x, r.position.y + r.size.y - t, r.size.x, t),
		Rect2(r.position.x, r.position.y, t, r.size.y),
		Rect2(r.position.x + r.size.x - t, r.position.y, t, r.size.y),
		Rect2(r.position.x + t * 2, r.position.y + t * 2, r.size.x - t * 4, t * 0.7),
		Rect2(r.position.x + t * 2, r.position.y + r.size.y - t * 3, r.size.x - t * 4, t * 0.7),
	]
	for bar in bars:
		draw_colored_polygon(_rotate_rect(bar, centre, STAMP_TILT), c)

	# The word, on the same tilt.
	var font := _ui_font()
	if font != null:
		var font_size := int(54.0 * s)
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var asc := font.get_ascent(font_size)
		draw_set_transform_matrix(_rotation_about(centre, STAMP_TILT))
		_text(label, Vector2(centre.x - w * 0.5, centre.y + asc * 0.5), float(font_size), c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The four corners of `rect`, rotated by `angle` around `pivot`.
func _rotate_rect(rect: Rect2, pivot: Vector2, angle: float) -> PackedVector2Array:
	var m := _rotation_about(pivot, angle)
	return PackedVector2Array([
		m * rect.position,
		m * Vector2(rect.end.x, rect.position.y),
		m * rect.end,
		m * Vector2(rect.position.x, rect.end.y),
	])


func _rotation_about(pivot: Vector2, angle: float) -> Transform2D:
	return Transform2D(angle, Vector2.ZERO).translated(pivot) * Transform2D(0.0, -pivot)


# --- atmosphere -----------------------------------------------------------

## The fixture: a brass balance-scale lamp hanging over the booth. It is the
## only warm object in a cold room, which is what makes the bench read as
## somewhere a person actually sits. Drawn as armature plus a warm pool, so the
## light has a visible source rather than just appearing on the desk.
func _draw_lamp() -> void:
	var cx := ROOM_W * 0.5
	var bulb_y := 88.0

	# Ceiling rose, then the hanging bar. Two arms and a scale pan each side.
	draw_rect(Rect2(cx - 26.0, 0.0, 52.0, 12.0), BRASS_DARK, true)
	draw_rect(Rect2(cx - 26.0, 0.0, 52.0, 3.0), BRASS_LIT, true)
	draw_rect(Rect2(cx - 3.0, 12.0, 6.0, 26.0), BRASS, true)
	draw_rect(Rect2(cx - 3.0, 12.0, 2.0, 26.0), BRASS_LIT, true)
	draw_circle(Vector2(cx, 40.0), 7.0, BRASS)
	draw_circle(Vector2(cx - 2.0, 38.0), 3.0, BRASS_LIT)

	# Balance arms sweeping out and down, each with a pan on chains.
	for side in [-1.0, 1.0]:
		var tip := Vector2(cx + side * 132.0, 18.0)
		draw_line(Vector2(cx, 40.0), tip, BRASS, 5.0)
		draw_line(Vector2(cx, 38.0), tip - Vector2(0, 2.0), BRASS_LIT, 2.0)
		# Chains.
		for k in 3:
			var px := tip.x + (float(k) - 1.0) * 16.0
			draw_line(tip, Vector2(px, 86.0), Color(BRASS_DARK.r, BRASS_DARK.g, BRASS_DARK.b, 0.85), 2.0)
		# Pan.
		draw_rect(Rect2(tip.x - 30.0, 86.0, 60.0, 8.0), BRASS, true)
		draw_rect(Rect2(tip.x - 30.0, 86.0, 60.0, 3.0), BRASS_LIT, true)
		draw_rect(Rect2(tip.x - 30.0, 92.0, 60.0, 3.0), BRASS_DARK, true)

	# Bulb under the centre boss.
	draw_rect(Rect2(cx - 8.0, 44.0, 16.0, 12.0), BRASS_DARK, true)
	draw_circle(Vector2(cx, bulb_y), 20.0, LAMP_WARM)
	draw_circle(Vector2(cx, bulb_y), 10.0, Color(1, 0.96, 0.86))

	# Warm pool thrown down onto the bench, and up the wall behind.
	for i in 18:
		var tt := float(i) / 17.0
		draw_circle(Vector2(cx, bulb_y), 30.0 + tt * 620.0,
			Color(LAMP_WARM.r, LAMP_WARM.g, LAMP_WARM.b, 0.014 * (1.0 - tt) * (1.0 - tt)))
	# The visible cone, brightest just under the bulb.
	var cone := PackedVector2Array([
		Vector2(cx - 26.0, bulb_y + 8.0),
		Vector2(cx + 26.0, bulb_y + 8.0),
		Vector2(cx + 210.0, DESK_Y),
		Vector2(cx - 210.0, DESK_Y),
	])
	draw_colored_polygon(cone, Color(LAMP_WARM.r, LAMP_WARM.g, LAMP_WARM.b, 0.045))
	var cone2 := PackedVector2Array([
		Vector2(cx - 12.0, bulb_y + 8.0),
		Vector2(cx + 12.0, bulb_y + 8.0),
		Vector2(cx + 96.0, DESK_Y),
		Vector2(cx - 96.0, DESK_Y),
	])
	draw_colored_polygon(cone2, Color(LAMP_WARM.r, LAMP_WARM.g, LAMP_WARM.b, 0.05))


func _draw_grain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 1500:
		draw_rect(Rect2(rng.randf_range(0, ROOM_W), rng.randf_range(0, ROOM_H), 2, 2),
			Color(0, 0, 0, 0.05), true)


func _draw_vignette() -> void:
	var steps := 32
	var band := 24.0
	for i in steps:
		var t := float(i) / float(steps)
		var a := 0.10 * (1.0 - t) * (1.0 - t)
		var inset := i * band
		draw_rect(Rect2(0, inset, ROOM_W, band), Color(0, 0, 0, a), true)
		draw_rect(Rect2(0, ROOM_H - inset - band, ROOM_W, band), Color(0, 0, 0, a), true)
		draw_rect(Rect2(inset, 0, band, ROOM_H), Color(0, 0, 0, a), true)
		draw_rect(Rect2(ROOM_W - inset - band, 0, band, ROOM_H), Color(0, 0, 0, a), true)
