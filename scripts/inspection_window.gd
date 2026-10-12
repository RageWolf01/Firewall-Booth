extends Control
class_name InspectionWindow

## The booth, from the inspector's chair.
##
## The room is the painted booth in `assets/ui/booth_plate.png`, drawn 1:1. That
## plate is the reference painting with every LIVE element cut out of it; this
## node draws those back on top from game state:
##
##   1. the line outside the glass — the packet box at the glass (a sprite cut
##      from the painting) and the translucent "ghost" boxes queued behind it
##   2. the ID sheet in its tray, with the packet's values typed onto it —
##      click it to pick it up
##   3. the verdict stamp, once the player has ruled
##   4. the packet tag number on the red folder tab beside the tray
##
## The manual, the decision buttons and the info panel are separate nodes in
## main.tscn, laid over their painted counterparts.
##
## Every rect below is in viewport pixels (1920x1080) and was measured off the
## painting; tools/build_ui_assets.py prints the ones it derives.

# ---------------------------------------------------------------- art
const PLATE := preload("res://assets/ui/booth_plate.png")
const BOX_TEX := preload("res://assets/ui/packet_box.png")
const DOC_TEX := preload("res://assets/ui/id_document.png")

# ---------------------------------------------------------------- palette
## Typewritten ink on the ID sheet.
const INK := Color("#26221d")
## The tag number, printed on the red folder tab.
const TAG_INK := Color("#4a1210")
const STAMP_OK := Color("#2f7a44")
const STAMP_NO := Color("#a83226")
## The queued packets behind the one at the glass are drawn as pale, glassy
## boxes, exactly as the painting has them. The fill is nearly opaque so each one
## hides the lower part of the one behind it, as in the painting; with a
## see-through fill every rim shows through and the stack reads as wireframe.
const GHOST_FILL := Color(0.122, 0.165, 0.184, 0.92)
const GHOST_EDGE := Color(0.27, 0.35, 0.35, 0.95)
## How far the verdict stamp leans, in radians.
const STAMP_TILT := -0.14

# ---------------------------------------------------------------- geometry
const ROOM_W := 1920.0
const ROOM_H := 1080.0
## The glass. Anything in the line outside this is behind the window frame.
const GLASS := Rect2(108.0, 160.0, 1704.0, 452.0)
## Where the ID sheet lies in its tray — the sheet's place in the painting.
const DOC_RECT := Rect2(537.0, 689.0, 484.0, 306.0)
## Where the sheet is held once picked up: scaled up, in front of the glass,
## clear of the manual on the left and the buttons on the right.
const DOC_LIFTED := Rect2(616.0, 248.0, 688.0, 435.0)
## The feed slot along the bottom of the tray. A sheet rising out of it, or fed
## back into it, is hidden below this line.
const SLOT_Y := 995.0
## The value cells on the sheet, in SHEET pixels (DOC_RECT space): x of the value
## column, its width, and each row's baseline.
const VALUE_X := 247.0
const VALUE_W := 210.0
const VALUE_BASELINES: Array[float] = [119.0, 154.0, 189.0, 222.0]
const VALUE_SIZE := 18.0
## The stamp, in sheet pixels: in the open space at the foot of the sheet, just
## catching the bottom of the table, so the values it rules on stay readable.
const STAMP_RECT := Rect2(236.0, 224.0, 190.0, 66.0)
## The packet tag number on the red folder tab.
const TAG_POS := Vector2(1045.0, 830.0)
const TAG_LINE := 20.0
const TAG_SIZE := 19

# ---------------------------------------------------------------- the line
## The packet at the glass, measured off the painting.
const BOX_RECT := Rect2(861.0, 362.0, 198.0, 234.0)
const LANE_X := 960.0
## Top edge and width of the box at each place in the line, from the painting's
## three ghosts. Fractional depths (a line shuffling up) interpolate between.
const DEPTH_TOP: Array[float] = [362.0, 307.0, 271.0, 241.0, 216.0]
const DEPTH_W: Array[float] = [198.0, 166.0, 138.0, 111.0, 88.0]

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
enum DocState { FLAT, LIFTED }

## Sentinel meaning "nobody at the glass". A dedicated instance avoids the
## problem that an empty `Packet.new()` and a null `_packet` would both be
## falsy, so `show_packet()` could not tell "clear it" from "show a blank one".
static var NO_PACKET := Packet.new("", 0, "", "", true, "")

var _doc_state: int = DocState.FLAT
## How far the document has been picked up: 0 = lying in the tray, 1 = held up.
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
## Each entry is {"packet": Packet, "depth": float, "from": float,
## "target_depth": float}; `depth` is animated when the queue shuffles forward.
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
## Document feed-in progress: 0 = still down in the slot, 1 = in the tray.
var _arrive := 1.0
## Document feed-out progress: 0 = in the tray, 1 = gone back down the slot.
var _retract := 0.0
## Guards `departing_finished` so it fires once per departure, not every idle frame.
var _departing_announced := true
## Counts sheets handed over, for the number on the packet tag.
var _serial := -1


## How many packets to keep in the line, including the one at the glass.
## The line is topped up after every departure, so for now the shift never runs
## dry — a real queue of 20-odd packets arrives with the day's data later.
const QUEUE_TARGET := 4
## How many packets to draw. Depth beyond this is culled.
const QUEUE_VISIBLE := 4
## Seconds for a judged packet to walk out of the window.
const LEAVE_TIME := 1.15
## Seconds for the line to close up after a departure.
const SHUFFLE_TIME := 0.45
## Seconds for a document to rise out of the slot.
const ARRIVE_TIME := 0.5
## Seconds for a judged document to sink back into it.
const RETRACT_TIME := 0.4
## Seconds for the stamp to come down onto the page. Deliberately slow enough to
## read: at anything under about a third of a second the player never sees it.
const STAMP_TIME := 0.5
## How far below its resting place a document starts. It is fed up out of the
## slot, so this is the sheet's full height: it starts entirely below SLOT_Y.
const FEED_DEPTH := 312.0


## Give the booth the packets it deals from. The line is built from these and
## topped up as it drains, so for now the shift loops.
func set_queue(queue: Array[Packet]) -> void:
	_templates = queue.duplicate()
	_next_template = 0
	_queue.clear()
	_leaving.clear()
	_top_up(false)
	_shuffling = 1.0
	_desk = 0.0
	_desk_target = 0.0
	if _lift_tween and _lift_tween.is_valid():
		_lift_tween.kill()
	clear_stamp()
	_packet = NO_PACKET          # force _sync_to_front to lay a fresh document
	_sync_to_front()
	queue_redraw()
	set_process(true)


## Add packets to the back of the line until it reaches QUEUE_TARGET. Newcomers
## get a depth AND a target — an entry without `target_depth` makes the shuffle
## in _process error every frame. With `walk_in` they start one place further
## back, so they fade up into the line as it shuffles rather than popping in.
func _top_up(walk_in: bool) -> void:
	if _templates.is_empty():
		return
	while _queue.size() < QUEUE_TARGET:
		var d := float(_queue.size())
		var start := d + 1.0 if walk_in else d
		_queue.append({
			"packet": _templates[_next_template],
			"depth": start,
			"from": start,
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
	_serial += 1
	_arrive = 0.0
	_retract = 0.0
	# The sheet arrives in the tray; the player picks it up to read it properly.
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


## The number printed on the current packet's tag, e.g. "#0317-A".
func packet_tag() -> String:
	var n := maxi(_serial, 0)
	return "#%04d-%s" % [317 + n, char(65 + n % 26)]


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
	_top_up(true)
	_shuffling = 0.0
	_departing_announced = false
	# NOTE: the next document is deliberately NOT laid here. main.gd keeps the
	# verdict on screen while the packet walks off, and only hands over the next
	# document once `departing_finished` arrives. The judged sheet goes back down
	# the slot meanwhile.
	close_document()
	_retract = 0.0001
	queue_redraw()
	set_process(true)


func _process(delta: float) -> void:
	# --- the document rising out of the slot ---
	if _arrive < 1.0:
		_arrive = minf(1.0, _arrive + delta / ARRIVE_TIME)
		queue_redraw()

	# --- the judged document sinking back into it ---
	if _retract > 0.0 and _retract < 1.0:
		_retract = minf(1.0, _retract + delta / RETRACT_TIME)
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
	# real bug: the slide-in was cut off partway, freezing the sheet mid-flight.
	if _all_settled():
		set_process(false)
		if not _departing_announced:
			_departing_announced = true
			departing_finished.emit()


## True when nothing is still moving: no packets walking off, the line closed
## up, the document fed in or out, and its lift and stamp tweens finished. Every
## animation must be listed here — one that is missing freezes partway.
func _all_settled() -> bool:
	return _leaving.is_empty() \
		and _shuffling >= 1.0 \
		and _arrive >= 1.0 \
		and (_retract <= 0.0 or _retract >= 1.0) \
		and not _desk_animating() \
		and not _stamp_animating()


func _stamp_animating() -> bool:
	return _stamp_tween != null and _stamp_tween.is_valid() and _stamp_tween.is_running()


func _desk_animating() -> bool:
	return _lift_tween != null and _lift_tween.is_valid() and _lift_tween.is_running()


## Hand the next packet at the glass its document, so the sheet rises in.
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
	# The plate and the box are drawn 1:1; only the sheet is scaled (when held
	# up), and the painting is soft enough that filtering it smoothly looks right.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


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
## the game waits on before taking the sheet away.
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
## on a verdict reads as the paper glitching back to the desk.
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
	# sheet freezes halfway between tray and hand.
	set_process(true)


## Animation-only setter. It must NOT emit document_state_changed: the gate is
## owned by _desk_target, and emitting from both would fire mid-tween.
func _set_desk(v: float) -> void:
	_desk = v
	queue_redraw()


# ---------------------------------------------------------------- input
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var over := _packet != NO_PACKET and _document_rect().has_point(event.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over \
			else Control.CURSOR_ARROW
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# Clicking the document itself picks it up or puts it down.
		if _packet != NO_PACKET and _document_rect().has_point(event.position):
			toggle_document()
			accept_event()


## Where the document is drawn right now, in local coordinates.
func _document_rect() -> Rect2:
	return _doc_rect_now()


## Where the document is on screen, or an empty rect when there is none. Used by
## overlays that must not draw over a sheet held up in front of them.
func document_rect() -> Rect2:
	return Rect2() if _packet == NO_PACKET else _doc_rect_now()


## Lay the document back down. Animated — see _animate_desk().
func close_document() -> void:
	if _doc_state == DocState.FLAT and is_equal_approx(_desk_target, 0.0):
		return
	_doc_state = DocState.FLAT
	_animate_desk(0.0)


## The sheet's rect right now: in the tray blended toward held-up, then pushed
## down into the slot while it is being fed in or out.
func _doc_rect_now() -> Rect2:
	var rect := Rect2(
		DOC_RECT.position.lerp(DOC_LIFTED.position, _desk),
		DOC_RECT.size.lerp(DOC_LIFTED.size, _desk)
	)
	rect.position.y += _feed_offset()
	return rect


## How far down the slot the sheet is. Eased so it decelerates into the tray and
## accelerates away down the slot.
func _feed_offset() -> float:
	var down := 0.0
	if _arrive < 1.0:
		down = 1.0 - (1.0 - pow(1.0 - _arrive, 3.0))
	if _retract > 0.0:
		down = maxf(down, pow(_retract, 2.0))
	return FEED_DEPTH * down


# ---------------------------------------------------------------- draw
func _draw() -> void:
	draw_texture(PLATE, Vector2.ZERO)
	_draw_queue()
	_draw_tag()
	_draw_document()


# --- the line outside -----------------------------------------------------

## The queue: the box at the glass, and the rest of the line as pale ghost boxes
## stacked up behind it, smaller and higher with each place back.
func _draw_queue() -> void:
	# Farthest first, so nearer boxes draw over the ones behind them.
	var order: Array[Dictionary] = _queue.duplicate()
	order.reverse()
	for entry in order:
		var depth: float = entry["depth"]
		if depth > float(QUEUE_VISIBLE):
			continue
		var r := _box_at(depth)
		# Fading in at the back of the line, and from ghost to solid as it reaches
		# the glass.
		var presence := clampf(float(QUEUE_VISIBLE) - depth, 0.0, 1.0)
		var solid := clampf(1.0 - depth, 0.0, 1.0)
		if solid < 1.0:
			_draw_ghost(r, presence * (1.0 - solid))
		if solid > 0.0:
			draw_texture_rect(BOX_TEX, r, false, Color(1, 1, 1, solid))

	for entry in _leaving:
		_draw_departing(entry)

	# Anything that has wandered past the glass is behind the window frame:
	# redraw the wall over it. Cheaper and more robust than clipping each box
	# (and it clips the rotated, waddling ones correctly too).
	_cover_with_plate(Rect2(0.0, GLASS.position.y - 60.0, GLASS.position.x, GLASS.size.y + 120.0))
	_cover_with_plate(Rect2(GLASS.end.x, GLASS.position.y - 60.0,
		ROOM_W - GLASS.end.x, GLASS.size.y + 120.0))


## Redraw the painted room over `r`, hiding whatever was drawn there.
func _cover_with_plate(r: Rect2) -> void:
	draw_texture_rect_region(PLATE, r, r)


## The box's rect `depth` places back in the line.
func _box_at(depth: float) -> Rect2:
	var i := clampi(int(floor(depth)), 0, DEPTH_TOP.size() - 2)
	var f := clampf(depth - float(i), 0.0, 1.0)
	var top := lerpf(DEPTH_TOP[i], DEPTH_TOP[i + 1], f)
	var w := lerpf(DEPTH_W[i], DEPTH_W[i + 1], f)
	var h := w * BOX_RECT.size.y / BOX_RECT.size.x
	return Rect2(LANE_X - w * 0.5, top, w, h)


## A queued packet: a see-through box with a lit rim, as in the painting.
func _draw_ghost(r: Rect2, alpha: float) -> void:
	if alpha <= 0.004:
		return
	var fill := GHOST_FILL
	fill.a *= alpha
	var edge := GHOST_EDGE
	edge.a *= alpha
	draw_rect(r, fill, true)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), edge, true)
	draw_rect(Rect2(r.position, Vector2(2.0, r.size.y)), edge, true)
	draw_rect(Rect2(r.end.x - 2.0, r.position.y, 2.0, r.size.y), edge, true)


## A judged packet: strides left or right, waddling, until the frame hides it.
func _draw_departing(entry: Dictionary) -> void:
	var t: float = clampf(float(entry["t"]), 0.0, 1.0)
	var dir := 1.0 if bool(entry["approved"]) else -1.0
	var dist := 1000.0                      # far enough to clear the glass

	# Ease in, so it sets off and then strides away.
	var travel := dist * pow(t, 1.6) * dir
	# Waddle: a rock and a small hop. The rock is kept modest — a big lean makes
	# a box look like it is falling over.
	var phase := t * 24.0
	var rock := sin(phase) * 0.05
	var hop := absf(sin(phase)) * 10.0

	var r := _box_at(float(entry["depth"]))
	r.position.x += travel
	r.position.y -= hop
	var pivot := Vector2(r.get_center().x, r.end.y)
	draw_set_transform_matrix(_rotation_about(pivot, rock))
	draw_texture_rect(BOX_TEX, r, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- the tag beside the tray ------------------------------------------------

func _draw_tag() -> void:
	if _packet == NO_PACKET:
		return
	var font := _mono()
	draw_string(font, TAG_POS, "PKT", HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE, TAG_INK)
	draw_string(font, TAG_POS + Vector2(0.0, TAG_LINE), packet_tag(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE, TAG_INK)


# --- the document -----------------------------------------------------------

## The packet's ID sheet: in the tray, or held up to read.
func _draw_document() -> void:
	if _packet == NO_PACKET:
		return
	var rect := _doc_rect_now()
	if rect.position.y >= SLOT_Y:
		return                               # entirely down the slot
	var s := rect.size.x / DOC_RECT.size.x

	# Held up, it throws a shadow onto the glass and desk behind it.
	if _desk > 0.01:
		var off := Vector2(14.0, 20.0) * _desk
		draw_texture_rect(DOC_TEX, Rect2(rect.position + off, rect.size), false,
			Color(0, 0, 0, 0.45 * _desk))

	draw_texture_rect(DOC_TEX, rect, false)
	_draw_values(rect, s)

	if not _stamp_word.is_empty() and _stamp_press > 0.001:
		_draw_stamp_descending(Rect2(rect.position + STAMP_RECT.position * s,
			STAMP_RECT.size * s), s)

	# Being fed through the slot: whatever is below it is inside the desk.
	if rect.end.y > SLOT_Y + 0.5:
		_cover_with_plate(Rect2(DOC_RECT.position.x - 20.0, SLOT_Y,
			DOC_RECT.size.x + 40.0, ROOM_H - SLOT_Y))


## The packet's details, typed into the value column of the sheet.
func _draw_values(rect: Rect2, s: float) -> void:
	var font := _mono()
	var rows := [
		_packet.source_ip,
		str(_packet.destination_port),
		_packet.protocol,
		_packet.payload,
	]
	var max_w := VALUE_W * s
	var x := rect.position.x + VALUE_X * s
	for i in rows.size():
		var text: String = rows[i]
		var base := rect.position.y + VALUE_BASELINES[i] * s
		var size := VALUE_SIZE
		# Long values first shrink a little, then wrap onto two smaller lines —
		# the payload cell is the tallest on the form, so it has room for two.
		while size > 14.0 and _width(font, text, size * s) > max_w:
			size -= 1.0
		if _width(font, text, size * s) <= max_w:
			_text(font, text, Vector2(x, base), size * s, INK)
			continue
		var lines := _wrap(font, text, 13.0 * s, max_w)
		var lead := 15.0 * s
		var y := base - lead * 0.5 * float(mini(lines.size(), 2) - 1)
		for k in mini(lines.size(), 2):
			_text(font, lines[k], Vector2(x, y + lead * k), 13.0 * s, INK)


func _width(font: Font, text: String, size: float) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x


## Greedy word wrap to `max_w` pixels.
func _wrap(font: Font, text: String, size: float, max_w: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var trial := word if line.is_empty() else line + " " + word
		if line.is_empty() or _width(font, trial, size) <= max_w:
			line = trial
		else:
			lines.append(line)
			line = word
	if not line.is_empty():
		lines.append(line)
	return lines


func _text(font: Font, sv: String, pos: Vector2, size: float, c: Color) -> void:
	draw_string(font, pos, sv, HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(size, 6.0)), c)


## The paperwork font. Prefers the UiFont autoload but loads it directly when
## that is missing, because autoloads are not registered when a script runs
## under `--script` (the headless harness) and the document must draw there too.
func _mono() -> Font:
	var node := get_node_or_null("/root/UiFont")
	if node != null and node.get("font") != null:
		return node.get("font")
	return load("res://scripts/ui_font.gd").mono_font()


## The stamp on its way down. `_stamp_press` runs 0 -> 1: it starts above the page,
## oversized and faint, then lands. The press is simulated by scaling slightly
## past its resting size at the moment of impact and easing back, which is what
## sells it as a physical stamp rather than a graphic appearing.
func _draw_stamp_descending(r: Rect2, s: float) -> void:
	var k := clampf(_stamp_press, 0.0, 1.0)
	var centre := r.get_center()
	var rise := (1.0 - k) * 90.0 * s
	var press := 1.0 + sin(k * PI) * 0.10
	var m := Transform2D(0.0, Vector2(0.0, -rise)) \
		* Transform2D(0.0, centre) \
		* Transform2D(0.0, Vector2.ZERO).scaled(Vector2(press, press)) \
		* Transform2D(0.0, -centre)
	var c := _stamp_color
	c.a = clampf(0.35 + k * 0.65, 0.0, 1.0) * 0.88
	_stamp_at(r, s, c, m)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A rubber stamp, inked onto the form: ALLOW in green, BLOCK in red.
##
## Drawn tilted on purpose. The word matches the action buttons, so an
## axis-aligned box with a neat border reads as a *clickable button* rather than
## a stamp on paper — the rotation is what makes it unambiguous.
func _stamp_at(r: Rect2, s: float, c: Color, m: Transform2D) -> void:
	var centre := r.get_center()
	var tilt := m * _rotation_about(centre, STAMP_TILT)
	draw_set_transform_matrix(tilt)
	var t := 4.0 * s
	draw_rect(r, c, false, t)
	draw_rect(r.grow(-t * 2.2), c, false, t * 0.6)
	var font := _mono()
	var size := int(36.0 * s)
	var w := font.get_string_size(_stamp_word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	# Capitals only, so centre on the cap height (about 0.7 em) rather than ascent.
	draw_string(font, Vector2(centre.x - w * 0.5, centre.y + size * 0.35), _stamp_word,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _rotation_about(pivot: Vector2, angle: float) -> Transform2D:
	return Transform2D(angle, Vector2.ZERO).translated(pivot) * Transform2D(0.0, -pivot)
