extends Control

## Firewall Booth — main UI.
##
## The player is the firewall, sitting at a booth. A packet (a non-human
## "customer" — a box) comes to the glass with an ID document. The player reads
## the document, checks it against the manual, and decides.
##
## The booth itself is drawn entirely in code by InspectionWindow: desk, the
## packet's document lying on it, the manual on its clipboard, the window, and
## the line outside. This script owns the paperwork — the decision buttons and
## the verdict readout — and the hand-off between one packet and the next.
##
## There are no imported assets in this project.
##
## The cycle, with no "next" button to press:
##
##   rule -> stamp + verdict shown -> packet walks off -> verdict cleared
##        -> next document slides in -> buttons re-locked until it is read

## Verdict colours, warmed to sit inside the room's grubby palette.
const COLOR_IDLE := Color(0.30, 0.28, 0.25)
const COLOR_CORRECT := Color(0.55, 0.82, 0.42)
const COLOR_WRONG := Color(0.90, 0.34, 0.26)
const COLOR_MUTED := Color(0.60, 0.55, 0.46)

const MANUAL_TITLE := "MANUAL — SHIFT 1"

const MANUAL_BODY := """Allow: port 80 (HTTP),
443 (HTTPS) and 53 (DNS).

Block: every other
destination port, and any
traffic that looks like a
beacon."""

@onready var booth: InspectionWindow = $Window
@onready var manual_text: Label = $Manual
@onready var manual_body: Label = $ManualBody
@onready var light: StatusLight = $Controls/VerdictPanel/Row/Lamp
@onready var verdict_label: Label = $Controls/VerdictPanel/Row/Verdict
@onready var allow_button: Button = $Controls/Actions/Allow
@onready var block_button: Button = $Controls/Actions/Block

var packets: Array[Packet] = []
var decision_made: bool = false
## Whether the document is CURRENTLY open. The decision buttons are live only
## while this is true: reading a document and then clicking away re-locks them,
## so the player must have it in front of them to rule on it.
var packet_inspected: bool = false
## Countdown while the stamped sheet is held on screen before being taken away.
var _hold := 0.0
## True between a verdict and the hand-over completing, so the desk cannot be
## interacted with in that window.
var _finalizing := false
## Which way the player ruled on the current packet, needed when the packet is
## finally sent on its way.
var _pending_approval := true

## How long the stamped sheet stays put after the stamp lands, in seconds. This
## is the beat that lets the player see the verdict being stamped at all.
const HOLD_AFTER_STAMP := 0.9
## NOTE: there is deliberately no packet_index. The booth owns the line and
## advances it on each verdict, so an index kept here would drift out of step
## with whoever is actually at the glass.


func _ready() -> void:
	packets = _build_shift()
	manual_text.text = MANUAL_TITLE
	manual_body.text = MANUAL_BODY
	# The window owns its own click handling; it reports the document opening and
	# closing so the decision buttons can be gated on it. Guarded so a double
	# call cannot stack two connections.
	if not booth.document_state_changed.is_connected(_on_document_state_changed):
		booth.document_state_changed.connect(_on_document_state_changed)
	# Once a judged packet has finished walking off, hand over the next one.
	if not booth.departing_finished.is_connected(_on_departing_finished):
		booth.departing_finished.connect(_on_departing_finished)
	# The stamp signals when it has landed, which starts the hold.
	if not booth.stamp_hit.is_connected(_on_stamp_hit):
		booth.stamp_hit.connect(_on_stamp_hit)
	# Hand the whole line to the booth: it draws the line and owns it.
	booth.set_queue(packets)
	_begin_packet()

	var args := OS.get_cmdline_user_args()
	# Dev convenience: start with the document lifted and readable.
	if args.has("--lifted"):
		booth.toggle_document()
	# Dev convenience: judged, so the verdict and stamp are on screen.
	if args.has("--judged"):
		booth.toggle_document()
		_judge(false)
	# Dev convenience: freeze the stamp part-way down, to check the descent.
	# Done on a short timer so the render catches it mid-press.
	if args.has("--stamping"):
		booth.toggle_document()
		_judge(true)
		get_tree().create_timer(0.22).timeout.connect(
			func() -> void: booth.set_process(false))


## The packets dealt this shift. Hand-written for now; randomised generation
## replaces this next.
func _build_shift() -> Array[Packet]:
	return [
		Packet.new(
			"192.168.1.45", 443, "TCP", "Login request", true,
			"Port 443 carries HTTPS and is open to everyone today. "
			+ "The payload matches the port, so this is ordinary secure web traffic."
		),
		Packet.new(
			"203.0.113.77", 4444, "TCP", "Encrypted beacon, 30s heartbeat", false,
			"Nothing legitimate talks to port 4444 with a regular heartbeat. "
			+ "That pattern is a compromised machine phoning home to its operator."
		),
		Packet.new(
			"10.0.0.9", 53, "UDP", "Lookup example.com", true,
			"DNS rides on UDP port 53. Letting it through is how the network "
			+ "resolves names at all."
		),
	]


## A new packet is at the glass: clear the verdict and lock the buttons until
## its document has been read.
func _begin_packet() -> void:
	_set_light(COLOR_IDLE)
	verdict_label.text = ""
	verdict_label.visible = false
	verdict_label.add_theme_color_override("font_color", COLOR_MUTED)
	packet_inspected = false
	decision_made = false
	allow_button.disabled = true
	block_button.disabled = true
	_update_prompt()


## Lock or unlock the decision buttons to match whether the document is open.
func _update_buttons() -> void:
	if decision_made:
		return
	allow_button.disabled = not packet_inspected
	block_button.disabled = not packet_inspected


## Before the document is open the lamp is the only thing in the verdict panel,
## so this label doubles as the instruction for what to do next.
func _update_prompt() -> void:
	if decision_made or packet_inspected:
		verdict_label.text = ""
		verdict_label.visible = false
		return
	verdict_label.visible = true
	verdict_label.add_theme_color_override("font_color", COLOR_MUTED)
	verdict_label.text = "Keep the document open to rule on it.\nClick it to pick it up."


## The document was picked up or laid back down. Only an OPEN document lets the
## player rule, so closing it again re-locks the buttons.
func _on_document_state_changed(up: bool) -> void:
	if decision_made:
		return
	packet_inspected = up
	_update_buttons()
	_update_prompt()


## The judged packet has finished walking off. Now hand over the next document —
## doing it any earlier would slide a fresh sheet in on top of the verdict the
## player has not finished reading.
func _on_departing_finished() -> void:
	booth.advance()
	_begin_packet()


## The stamp has landed. Hold on it for a beat before the sheet is taken away:
## at any less the paper vanished the moment it was marked and the player never
## registered what the verdict was.
func _on_stamp_hit() -> void:
	_hold = HOLD_AFTER_STAMP
	set_process(true)


func _process(delta: float) -> void:
	if _hold <= 0.0:
		set_process(false)
		return
	_hold -= delta
	if _hold > 0.0:
		return
	_hold = 0.0
	set_process(false)
	# Packet walks off; `departing_finished` brings the next sheet in once the
	# line has settled, so the two animations do not overlap.
	booth.finish_handover(_pending_approval)


## The player's call. `chose_allow` is what they pressed; correctness is
## whatever the packet says it should have been.
func _judge(chose_allow: bool) -> void:
	if decision_made:
		return
	# Judge whoever the booth actually has at the glass. Asking the booth rather
	# than indexing a local list is what keeps the verdict attached to the packet
	# the player is looking at.
	var packet := booth.current_packet()
	if packet == InspectionWindow.NO_PACKET:
		return
	decision_made = true

	var correct := chose_allow == packet.should_allow
	var verdict_word := "Allowed" if chose_allow else "Blocked"

	_set_light(COLOR_CORRECT if correct else COLOR_WRONG)
	# Ink the stamp now — it reflects the call the player made, so a BLOCK stamp
	# on a legitimate packet shows them exactly what they did.
	booth.stamp_verdict(chose_allow)
	verdict_label.visible = true
	if correct:
		verdict_label.text = "CORRECT — %s\n%s" % [verdict_word, packet.lesson]
		verdict_label.add_theme_color_override("font_color", COLOR_CORRECT)
	else:
		verdict_label.text = "WRONG — you %s\nIt should have been %s. %s" % [
			verdict_word.to_lower(), packet.correct_verdict_word(), packet.lesson
		]
		verdict_label.add_theme_color_override("font_color", COLOR_WRONG)

	print("[Firewall Booth] %s | chose %s | correct %s | %s" % [
		"CORRECT" if correct else "WRONG",
		verdict_word,
		packet.correct_verdict_word(),
		packet.payload,
	])

	allow_button.disabled = true
	block_button.disabled = true

	# The verdict is in. The packet does NOT leave yet: first the stamp comes
	# down, then the sheet is held for a beat, and only then is it taken away and
	# the next one slid in. Previously all of that happened at once and the stamp
	# was over before it could be seen.
	_pending_approval = chose_allow
	_finalizing = true


func _set_light(color: Color) -> void:
	light.color = color


func _on_allow_pressed() -> void:
	_judge(true)


func _on_block_pressed() -> void:
	_judge(false)
