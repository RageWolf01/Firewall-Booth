# Firewall Booth

A pixel-art inspection sim. You are the personification of a firewall, working a
booth. Packets arrive as "customers" â€” never human, always a circle, a square,
some other simple shape â€” and each one hands over an ID card. You read the
card, consult the day's manual, and decide: **Allow** or **Block**.

It is *Papers, Please* with the paperwork replaced by network security, and the
point is that the player ends up understanding ports, protocols and packet
filtering because they had to make a call about them, not because a tutorial
said so.

> **The 2D build is the game.** `scenes/main.tscn`. Everything here describes it.
>
> A 3D first-person version was built on top of this and then removed â€” it did not
> match the intended art style, so `scenes/booth3d.tscn` and its scripts
> (`booth_3d.gd`, `booth_look.gd`, `booth_interact.gd`, `pixel_art.gd`,
> `dev_capture.gd`) are **deleted**, along with the 3D autoload, input bindings and
> Jolt physics setting. Nothing here references them and there is no git history to
> recover them from.
>
> The view is still first person: a fixed seat looking straight out of the booth,
> with no camera movement at all. What was wanted was that fixed view **drawn as
> pixel art**, which is what this build is.


## Running it

```
godot --path .
```

`F5` (or "Run Project") launches `res://scenes/main.tscn`. There is nothing to
install. The first time the project opens, Godot imports the booth art in
`assets/ui` and the two fonts in `assets/fonts`.

## The look: the painted booth

The screen **is** the reference painting, `source_files/booth_ui_source.png`
(1672x941). It is not redrawn or approximated: `tools/build_ui_assets.py` scales
it once to 1920x1080 and cuts it into the pieces the game needs, and the game
lays them back together exactly where they came from. With a fresh packet at the
glass the opening frame matches the painting almost pixel for pixel.

What is cut out, and what puts it back:

| In the painting | Cut into | Put back by |
| --- | --- | --- |
| The whole room | `booth_plate.png`, with every live element removed | `InspectionWindow`, drawn 1:1 |
| The box at the glass | `packet_box.png` | `InspectionWindow`: the line, shuffling and walking off |
| The pale boxes behind it | (drawn) | `InspectionWindow._draw_ghost()`, sizes measured off the painting |
| The PACKET IDENTIFICATION sheet | `id_document.png`, value cells wiped | `InspectionWindow`: the packet's values, the stamp, picking it up |
| The manual's words | wiped from the plate | `ManualPage`, typed from `MANUAL_TITLE` / `MANUAL_BODY` |
| `PKT #0317-A` on the red tab | wiped from the plate | `InspectionWindow._draw_tag()`, numbered per sheet |
| ALLOW / BLOCK caps | `btn_*_{normal,hover,pressed,disabled}.png`, masked to the cap | two `TextureButton`s over the painted caps |
| The info panel's text | wiped from the plate | the `Verdict` label, auto-sized to the slot |
| The "i" badge | left in the plate | `StatusLight` lights over it green / red on a verdict |
| Camera tally lights, rack LEDs | left in the plate | `ambient_lights.gd` blinks and pulses them |

The text is wiped by inpainting only the ink strokes, so the paper grain, rules
and seals around it survive. The window behind the line is rebuilt row by row
between the two lit uprights either side of it, which keeps the floor and rail
bands straight.

The lettering is matched with two OFL fonts in `assets/fonts` (licences
alongside): **IBM Plex Mono SemiBold** for all the paperwork — it is the face
the painting's typewritten text is in, close enough that the values on the
sheet land on the painted ones — and **Rubik SemiBold** for the info panel.

Things worth knowing before changing it:

- **Every coordinate is a viewport pixel measured off the scaled painting.** If
  the painting changes, re-run the tool, then check `DOC_RECT`, `BOX_RECT`,
  `DEPTH_TOP` / `DEPTH_W` and `VALUE_BASELINES` in `inspection_window.gd`; the
  tool prints the ones it derives. The button rects live in both the tool and
  `main.tscn`.
- **Clipping is done by drawing the plate back over things.** A packet walking
  past the glass, and a sheet down the feed slot, are hidden by redrawing that
  part of `booth_plate.png` on top (`_cover_with_plate()`). It clips rotated
  sprites and text as well as rects, which hand-clipping did not.
- **The variable font's weight is set by numeric OpenType tag.** Keying
  `variation_opentype` with the string `"wght"` is silently ignored and the
  face renders in its thin default.
- **The locked buttons are only dimmed, not dark.** The painting shows the caps
  lit while the sheet is still unread, so the locked state is kept close to it.
  The strength is one line in `write_button()` in the tool.
- **The Verdict label is sized against a fixed slot (`PANEL_TEXT`).** A Label
  grows to fit its text, so testing the fit against its own size always passes
  and long lessons spilled off the panel.

To rebuild the art:

```
python -m pip install pillow numpy opencv-python-headless
python tools/build_ui_assets.py
```

## How a shift plays right now

You are sitting behind the desk. In front of you: the booth window, with the
queue visible outside â€” the next packet standing at the glass and the rest of
the line backed up behind it. Today's manual is clipped to a board on your
left. The packet's ID document is lying on the desk in front of you.

**Click the document to pick it up.** It lifts and fills the middle of the
screen so you can read it, and clicking again lays it back down. Compare it
against the manual, then press **Allow** or **Block**.

**You cannot rule on a document you have not read â€” and only while it is open.**
Both decision buttons are locked whenever the document is lying flat, with a
prompt reading *"Keep the document open to rule on it"*. Picking it up unlocks
them; **clicking it shut again re-locks them**, so you always have the document
in front of you when you rule.

**The stamp is ink, applied when you rule.** The document arrives clean; the
tilted `ALLOW` (green) or `BLOCK` (red) stamp appears only after you press a
button â€” and it shows **the call you actually made**, not the correct answer. So
if you block a legitimate packet you get a red `BLOCK` stamp *and* a `WRONG`
verdict underneath, which is the mistake worth showing you.

The lamp answers immediately:

| Lamp | Meaning |
| --- | --- |
| Dark grey | No call made yet |
| **Green** | Correct call |
| **Red** | Wrong call |

Underneath it the booth spells out what happened â€” either `CORRECT â€” Allowed`
or `WRONG â€” you blocked`, followed by the reason, so a wrong call teaches the
rule rather than just punishing it.

**There is no "next" button.** The cycle turns on its own, and the verdict is
timed so you actually see it:

| Beat | What happens |
| --- | --- |
| 1 | You press Allow / Block. Both buttons lock immediately. |
| 2 | The **stamp comes down** onto the sheet: it starts above the page, oversized and faint, and lands over `STAMP_TIME` (0.5s). |
| 3 | The stamped sheet is **held** for `HOLD_AFTER_STAMP` (0.9s) so you can read the verdict. |
| 4 | The packet walks off â€” right if approved, left if denied â€” and the line shuffles up. |
| 5 | The sheet is fed back and the next one **rises out of the slot**. Buttons stay locked until you read it. |

Steps 2â€“4 used to happen simultaneously, which meant the paper was taken away in
the same breath as it was marked: the player never saw the stamp at all. The
sequencing now lives in `main.gd` (`_on_stamp_hit()` starts the hold,
`_process()` counts it down and then calls `booth.finish_handover()`), while
`InspectionWindow` only reports `stamp_hit` when the stamp lands. The delay is a
pacing decision, so it is not in the drawing code.

The hand-over itself is driven by `InspectionWindow.departing_finished`, which
fires once the judged packet has left and the line has settled. `main.gd` holds
the verdict on screen until then, and only calls `booth.advance()` afterwards â€”
handing over any earlier would slide a fresh sheet in on top of a verdict the
player has not finished reading.

Three packets are dealt, hand-written: a legitimate HTTPS login, a beacon
phoning home on port 4444, and a DNS lookup on port 53. **The line loops** â€”
the booth tops itself up from those three as it drains, so the shift never runs
out. That is a placeholder: a real day will hand it ~20 packets and stop.

### The document arrives

A new document does not appear â€” it is **fed up out of a slot** in the bench.
The opening is cut into the desk directly under where a sheet lands, edged in
brass with corner screws, and the paper rises out of it and eases into place.
The offset is therefore **vertical** (`ARRIVE_FROM_Y`); an earlier version slid
the sheet in horizontally from off-screen, which read as the paper flying in
from outside rather than being handed through the window.

The sheet's lower edge has to land on the slot lip. `DOC_FLAT` is measured
*before* foreshortening, so its visible bottom is
`DOC_FLAT.position.y + DOC_FLAT.size.y * FLAT_SQUASH` â€” change either constant
and you must re-check `SLOT`.

**Both directions are animated.** `_desk` (0 = lying on the desk, 1 = held up) is
tweened in *both* directions by `_animate_desk()`. An earlier version set it to 0
instantly on a verdict, which teleported the paper from its held pose back down
to the desk â€” that is the "glitch" where it appeared to jump. Like `_lift_target`
before it, the open/closed state keys off `_desk_target` (where it is heading),
not `_desk` (where it is), so the buttons go live on the frame you click rather
than when the tween finishes.

The paper is rotated about its **bottom edge**, not its centre: pivoting at the
centre makes it look like it is floating and spinning, while pivoting at the
bottom edge reads as a sheet being picked up off the desk.

## Art direction: the industrial hybrid

> **Superseded by the painted booth above.** This section and "The room, and what
> makes it feel like a room" describe the procedural, primitives-only pass that
> came before it. The palette block and the draw functions they mention no longer
> exist; the ideas behind them are what the painting was made from.

The look is a **deliberate clash**: a cold, teal-lit vista seen through a heavy
brass window, against a warm timber bench lit by a single amber lamp. The room
is institutional and the objects on it are worn and physical. That contrast is
the whole idea â€” a drab government post crossed with a network operations
centre â€” so anything that softens one side or the other weakens it.

The palette lives at the top of `scripts/inspection_window.gd`:

| Role | Colour |
| --- | --- |
| Walls / floor | near-black warm brown `#171310` |
| Brass (frame, plate, fixture) | `#a87c3a` â†’ `#e0b45f` lit |
| Timber bench | `#3a2a1c` â†’ `#5a4229` lit |
| Vista beyond the glass | cold teal `#0d3238` |
| Aged paper (manual, manifest) | `#cdbf9e`, ink `#2e281e` |
| Verdict lamps | green `#57e08a`, red `#ef5a4a` |

Things that carry the style, in rough order of how much they matter:

- **The lamp** (`_draw_lamp()`) â€” a brass balance-scale fixture: ceiling rose,
  arms with hanging pans, and a warm bulb throwing a visible cone onto the
  bench. It is the only warm light source and the reason the bench reads as
  somewhere a person sits.
- **The brass nameplate** (`_draw_brass_plate()`) â€” the booth sign is engraved on
  a bevelled plate with corner screws. It was previously amber text straight onto
  the dark wall, which almost vanished.
- **The window** â€” brass framing, rivets, and a cold teal interior so the
  outside world recedes behind glass rather than reading as a flat backdrop.
- **The network floor beyond the glass** (`_draw_network_floor()`) â€” what the
  packets crossed to reach the booth. See below.

### What is outside the glass

**It is a network operations floor, not a city.** This is a design rule, not a
description: the reference art has a night skyline behind its window, and a skyline
of towers with lit windows is visually almost identical to a hall of equipment
racks covered in status LEDs â€” same vertical masses, same scatter of warm and cold
points. So the picture costs the same and now means something.

| In the reference | Here | What it is |
| --- | --- | --- |
| Towers | Wide, short cabinets | Equipment racks |
| Lit apartment windows | Small cyan / amber / green dots | Link and activity LEDs |
| Raised walkway | Horizontal runs | Cable trays |
| Street lighting | A bright line on the floor with bright dashes | The trunk and data in flight |

**Nothing outside that window is a tower or a building, and nothing should become
one.** The way buildings and cabinets are told apart is *proportion*, not the
lights: wide, short and tightly packed reads as equipment; tall, thin and gappy
reads as a skyline no matter what colour the dots are. The first attempt at this
used narrow cabinets (46â€“108 px wide, 120â€“300 px tall, gaps up to 22 px) and it
read as a city again. The current pass is 92â€“190 px wide, 96â€“205 px tall, gaps of
2â€“9 px, with dense patch-port strips across each cabinet.

If you want to push the theme harder, these all fit and none is a building: a
raised access floor, more patch fields, labelled port blocks, a KVM or console
station, a cooling unit, overhead busbar.

- **The documents** â€” aged paper with brown ink, a header rule, labelled field
  rows and a signed-off stamp, not a form rendered in UI grey.
- **The decision buttons** â€” glowing green and red plates with a soft outer
  shadow, drawn as physical controls rather than stock Godot buttons. Disabled
  states dim to grey-green / grey-red so the lock is legible without losing the
  colour identity.



`InspectionWindow` disables its own `_process` when idle, and everything it
animates is driven from there. So every animation **must** be listed in
`_all_settled()`. Missing one freezes that animation partway:

```gdscript
func _all_settled() -> bool:
    return _leaving.is_empty() \
        and _shuffling >= 1.0 \
        and _arrive >= 1.0 \
        and not _desk_animating()
```

The document was the one that got missed. `_arrive` was absent, so the slide-in
was cut off mid-flight and the sheet sat frozen to the side and still leaning â€”
it looked like it snapped into place and stayed tilted. The lift tween was the
second instance of the same mistake, which is why `_desk_animating()` checks
`is_running()` rather than assuming the tween finished.

`_animate_desk()` also calls `set_process(true)`, so starting an animation
restarts the loop that will finish it.

### The line outside

After a verdict the judged packet **walks off â€” right if you approved it, left
if you denied it** â€” waddling and fading as it goes, while the queue behind it
shuffles forward one place and the next packet arrives at the glass.

Everything behind the packet at the glass is drawn as a flat silhouette: no face
panel, no lit edges, no tape. Detail on the packets behind competes with the one
you are inspecting, and the point of the queue is that it is *waiting*, not that
it is readable.

**The line is clipped to the window opening.** A departing packet slides right
out of the frame and vanishes at the glass edge â€” without the clip it sails on
across the wall beside the window, which reads as walking through the booth.

> âš ï¸ **`RenderingServer.canvas_item_set_clip()` does NOT work from inside
> `_draw()`.** The clip rect is sampled when the canvas item is drawn, so setting
> it mid-draw is too late. This was tried, and it silently did nothing: rendering
> the same frame with and without the call produced **byte-identical images**.
> The bug was only caught by diffing two renders â€” every "pixel counting" test
> before that reported a false pass.

The reliable approach for rects is to clip by hand: `_draw_box_packet()` takes a
`clip: Rect2` and draws the intersection. A box entirely outside the opening
draws nothing at all, which is what makes a departing packet disappear at the
frame edge:

```gdscript
r = r.intersection(clip)
if r.size.x <= 0.0 or r.size.y <= 0.0:
    return          # fully outside the window â€” draw nothing
```

A partly-clipped packet is drawn by `_draw_box_clipped()`. The body is the
visible slice, but the **label and tape are calculated in BOX coordinates and
then intersected with the visible slice**, so each is cut off by the window edge
exactly like the body while staying bolted to the packet.

This took three attempts, and the two failure modes are worth remembering:

1. **Label positioned from the full box size** while the body was clipped â†’
   the label drifted off the packet and vanished on its own.
2. **Label positioned from the clipped rect** (as a fraction of the *visible*
   size) â†’ the label stayed in view but travelled across the face of the box as
   the slice shrank, so it looked like it was sliding out of the packet.

Only anchoring it to the box and clipping it separately gives the right
behaviour. Measured across an exit, the label's inset from the box's left edge
stays constant (18px) while the box slides from x=1104 to x=1766.

The frame is drawn *after* the queue either way, so what is left of the packet is
covered by the frame rather than showing a hard clipped edge.

Real clipping would mean putting the queue in its own `Control` with
`clip_contents = true`; hand-clipping was chosen because the boxes are axis
aligned rectangles and it needs no extra node.

Four implementation notes, each of which caused a bug first:

- **A departing packet leaves `_queue` immediately** and is drawn from a
  separate `_leaving` list. Only its *drawing* lingers. If it stayed in the
  queue until the animation finished, `_front()` would still be the old packet
  and the game state would be gated on a flourish.
- **`_judge()` already calls `depart()`.** Calling it again (the `--departing`
  dev flag did, via a timer) makes two copies walk off at once.
- **`_sync_to_front()` must clear `_packet` when the line is empty.** The bug
  this replaces: the queue drained, but `_packet` still held the last packet, so
  the document stayed readable and judgeable forever with nothing at the glass.
- **Every queue entry needs `target_depth`, including ones added by `_top_up()`.**
  A newly appended entry without it made the shuffle raise an error on *every*
  frame â€” and the test harness still reported 0 failures, because nothing
  asserted on the errors. Count `SCRIPT ERROR` in the log, not just the summary.
- **`main.gd` keeps no `packet_index`.** The booth owns the line now, so
  `_judge()` asks `booth.current_packet()` instead of indexing a local list â€”
  otherwise the verdict would attach to a different packet than the one on the
  desk.

## Where the project is right now

The decision loop works end to end, from the inspector's chair. The packets are
still a fixed list and the manual is fixed text â€” neither is generated yet, and
the queue outside is scenery: nobody walks up or leaves.

```
scenes/main.tscn             Control root "MainUI"
                               |- Control "Window"     InspectionWindow: plate, line, ID sheet, tag
                               |- Control "Ambient"    blinking camera lights and rack LEDs
                               |- Control "Manual"     ManualPage: the day's rules on the notebook
                               |- TextureButton "Allow" / "Block"   over the painted caps
                               |- Control "Lamp"       StatusLight, over the info panel's "i"
                               '- Label "Verdict"      the info panel's text

scripts/main.gd              the booth: queue, judging, lamp and text
scripts/inspection_window.gd class_name InspectionWindow - the plate and everything live on it
scripts/manual_page.gd       class_name ManualPage - the manual, typed onto the notebook
scripts/ambient_lights.gd    blinking / pulsing lights in the painting
scripts/packet.gd            class_name Packet - one customer and its correct answer
scripts/status_light.gd      class_name StatusLight - the verdict lamp, drawn not typed
scripts/ui_font.gd           autoload "UiFont" - the two shared fonts
tools/build_ui_assets.py     cuts source_files/booth_ui_source.png into assets/ui
```

### Layout rules worth keeping

The room fills the **entire 1920Ã—1080**. It was originally 1080 wide, which left
a dead strip down the right-hand side; if you resize the viewport, `ROOM_W` /
`ROOM_H` in `inspection_window.gd` and the `Window` node's offsets must both
change, or the same gap comes back.

The controls live in a single `VBoxContainer` pinned to the bottom right, and
the lifted document is sized to stop short of it (`DOC_LIFTED` ends at x=1400,
the controls start at x=1468). Two earlier bugs came from this area:

- The verdict text used to sit in the **same vertical stack** as the buttons, so
  a long verdict widened the container past its bounds, overflowed the screen
  and pushed `Block` out of view entirely. The verdict now
  lives in its own panel **beside** the actions, and its label is hidden (not
  blank) when there is nothing to report, so the panel shrinks to just the lamp.
- The buttons must not move when a verdict appears. `_layout_check.gd` asserted
  exactly that: it records each button's rect, judges a packet, and re-checks.

### Button gating

`packet_inspected` in `main.gd` mirrors whether the document is **currently
open**, and gates `Allow` / `Block`. `InspectionWindow` emits
`document_state_changed(up)`; `main.gd` connects to it in `_ready()` (guarded
with `is_connected` so a double call cannot stack connections). Before that the
verdict label doubles as the prompt â€” it is the only free space in that panel,
so it carries the instruction rather than sitting empty.

Two traps here, both of which bit:

- **Gate on the target, not the animation.** `_lift` is the tween's current
  value; `_lift_target` is where it is heading. Keying the gate off `_lift`
  means the buttons are still dead in the frame the player clicks, because the
  tween has not run yet. `is_document_open()` reads `_lift_target`, and
  `_animate_lift()` emits the signal immediately rather than on completion.
- **`_set_lift()` is animation-only and must not emit.** It is called once per
  tween step; emitting from there fires the signal dozens of times mid-animation
  and, worse, disagrees with `_lift_target`.

The verdict lamp is dark grey until a decision is made, then green or red.

`Packet` carries `should_allow` (the correct call) and `lesson` (the reason).
Both are hardcoded per packet. When the daily manual becomes real data, the
reason should be derived from that day's rules instead and these fields go away.

### The room, and what makes it feel like a room

*(Historical — see "The look: the painted booth".)* `inspection_window.gd`
used to draw the entire view with primitives â€” rectangles, polygons, circles, lines and
`draw_string()`. That is a deliberate choice, not a limitation: the scene can be
re-tuned by editing numbers, and it cannot break on a missing texture.

The camera sits *behind the desk*, and depth is built by layering, front to
back: the desk surface, the document lying on it, the manual board, the window
frame, and the queue beyond the glass. Things that are nearer are drawn later
and are lighter; things further away are darker and higher in the frame.

Four things do the work, all borrowed from how *Papers, Please* stages a booth:

1. **A heavy recessed frame.** The opening is set back into a thick wall, with
   a lit bevel on the top/left and shadow on the bottom/right, so you read the
   booth as a box you are sitting inside.
2. **Somebody is out there.** The queue is visible through the glass as box
   packets, the nearest standing at the glass and the rest receding behind it.
3. **A desk in the foreground** with the document on it and a warm pool of
   lamplight, the rest of the room falling away into shadow.
4. **Grime.** Film grain over everything, a vignette that darkens the corners,
   and one warm lamp against a cold room.

The palette is deliberately narrow and desaturated â€” dirty browns, olive greys,
one amber light. Anything saturated reads as "modern UI" and breaks the mood.

### The document

The one piece of perspective in the scene. Lying flat it is vertically squashed
(`FLAT_SQUASH`) and slightly sheared (`FLAT_SHEAR`), which is enough to read as
"on the desk" without a camera. Clicking it tweens between `DOC_FLAT` and
`DOC_LIFTED`; the squash and shear interpolate to zero as it rises.

Its text is drawn with real glyphs via `draw_string()`. An earlier pass blocked
the text out as bars â€” stable at any scale, but unreadable, and **a document the
player cannot read is not a document.**

The stamp is separate state, not part of the form: `_stamp_word` and
`_stamp_color` are cleared by `clear_stamp()` whenever a new packet arrives, and
set by `stamp_verdict(approved)` when the player rules. Two consequences worth
keeping:

- It is **tilted** (`STAMP_TILT`). The word matches the action buttons, so an
  axis-aligned box with a neat border reads as a clickable button rather than a
  stamp on paper.
- It records **the player's call**, not `packet.should_allow`. Showing the
  correct answer as a stamp would erase the evidence of what they actually did.

Two things learned the hard way while tuning it:

- **Silhouettes and boxes must be one hard-edged shape.** Stacking a translucent
  rim light over a body turns the whole queue into grey fog. A thin crisp
  polyline along one edge is what makes a shape read.
- **Verify colours by sampling pixels, not by eye.** Button text that looked
  "still white" in a downscaled preview sampled as exactly the warm cream it was
  set to.
- **`class_name` scripts need an import pass** before another script can see the
  type, and `--script` harnesses get no autoloads at all. That is why
  `_ui_font()` falls back to `ThemeDB.fallback_font` instead of assuming the
  `UiFont` autoload exists.

### Seeing a change without playing it

Godot can render straight to numbered PNGs, which is the only reliable way to
review a scene from a script environment:

```
godot --path . --write-movie /tmp/shot.png --fixed-fps 30 --quit-after 3
# then open /tmp/shot00000002.png

# start with the document already lifted, to check the readable state
godot --path . --write-movie /tmp/shot.png --fixed-fps 30 --quit-after 40 ++ --lifted

# start already judged, to check the verdict layout (the longest text state)
godot --path . --write-movie /tmp/shot.png --fixed-fps 30 --quit-after 60 ++ --judged

# judged and walking off, to check the departure animation
godot --path . --write-movie /tmp/shot.png --fixed-fps 30 --quit-after 26 ++ --departing
```

Note the `++`: everything after it arrives as a *user* arg for
`OS.get_cmdline_user_args()`, which is how `--lifted`, `--judged` and
`--departing` are read. All three are dev-only switches in `main.gd` and do
nothing in normal play.
`--headless` cannot be used with `--write-movie`: its dummy renderer returns no
image.

### A warning about writing test harnesses

Two traps cost real time here, and both produce **misleading results** rather
than obvious failures:

- **Tweens do not advance in a tight loop.** A `SceneTree` script that calls
  `node._process(delta)` repeatedly never lets `Tween`s run, because tweens are
  advanced by the `SceneTree`. Assertions about anything tween-driven will fail
  spuriously. Drive such tests across real frames instead.
- **`delta` is not 1/60 in an unthrottled run.** Counting frames as a proxy for
  time gave a wait roughly ten times shorter than intended, so an animation
  "never finished" when it simply had not been given long enough. Wait on
  elapsed time, not frame count.

Also: a green summary is not proof. `SCRIPT ERROR` lines can scroll past while
the assertion count still says 0 â€” grep the log for them, and when a claim is
visual, diff two renders rather than counting pixels.


1. **A heavy recessed frame.** The opening is set back into a thick wall, with
   a lit bevel on the top/left and shadow on the bottom/right, so you read the
   booth as a box you are sitting inside.
2. **Somebody is out there.** The queue is visible through the glass as solid
   silhouettes against a hazy street at night.
3. **A counter in the foreground** with a warm pool of lamplight on it, and the
   rest of the room falling away.
4. **Grime.** Film grain over everything, scratches on the glass, a vignette
   that darkens the corners, and a single warm lamp against a cold room.

The palette is deliberately narrow and desaturated â€” dirty browns, olive greys,
one amber light. Anything saturated reads as "modern UI" and breaks the mood.

Some things learned the hard way while tuning it:

- **Silhouettes must be one hard-edged shape.** Stacking a translucent rim
  light over the body turned the whole queue into grey fog. A thin crisp
  polyline along one edge is what makes a figure read.
- **Desk lamp placement matters** more than its glow. The shade has to sit
  below the frame or the cone collides with the window header.
- **Verify colours by sampling pixels, not by eye.** Button text that looked
  "still white" in a downscaled preview sampled as exactly the warm cream it
  was set to.

### Why the lamp is drawn instead of a "â—" character

Godot's default theme font has no `U+25CF`: `has_char()` returns false and the
glyph falls back to an undefined-character box. `StatusLight` draws a filled
circle with a soft halo instead, so the lamp renders identically regardless of
font or platform.

What is next, in order:

1. Spawn packets with randomised ID cards instead of the fixed list.
2. Turn the manual into real per-day rule data that decides `should_allow`,
   rather than a sentence sitting next to a hardcoded answer.
3. A score: correct calls pay, wrong calls cost trust.
4. End-of-shift wages and the upgrade screen.
5. Packet personalities, so TCP and UDP read differently on the card and the
   player can guess the protocol for a bonus.

## The design it is growing into

**ID cards** carry a source IP, a destination port, a protocol and a one-line
payload description. Ports are the backbone of the puzzle â€” 80 HTTP, 443 HTTPS,
22 SSH, 53 DNS, 3389 RDP, and the 49152â€“65535 range that malware likes â€” and the
rules about them can change every day ("today port 22 is IT staff only").

**Protocols have personality.** TCP is connection-oriented, so it knocks and
waits; UDP is connectionless, so it shouts and leaves without waiting for an
answer. The player reads the phrasing and names the protocol for bonus pay.

**Vendor booths** are the starting-trait choice, each with one strength and one
weakness â€” application awareness, state tracking, cheaper hardware, threat
intelligence, payload inspection.

**Progression** is three parallel tracks: active skills funded by a focus meter,
limited-use tools bought between shifts, and stacking passives paid for with EXP.

The shape of the campaign is 30 shifts, with difficulty rising through more
packets, more intricate rules and faster arrivals.

### A note on attacks

Combat is deliberately out of scope. If pressure mechanics arrive later they
belong *inside* the inspection loop â€” a flood of contradictory rules, ambiguous
cards and faster arrivals â€” rather than as a separate phase that interrupts it.

## Development

The project ships the [godot-ai](addons/godot_ai) and [godot-mcp](addons/godot_mcp)
editor addons, with `_mcp_game_helper` registered as an autoload so an attached
MCP client can drive the running game. That autoload is the only non-game entry
in `project.godot`.

Useful for checking a change without watching it by hand:

```
godot --headless --path . --script res://your_harness.gd
```

## Publishing to GitHub

`push-to-github.ps1` in the project root does the whole job — init, identity, commit,
remote, push — and is safe to re-run.

```
winget install --id Git.Git -e      # then open a NEW terminal
.\push-to-github.ps1
```

Two notes on it:

- **It exists because the project could not be pushed from where it was written.** That
  machine had no `git` installed and its outbound HTTPS was blocked, so the script is
  the handover: it runs on a machine that has both.
- **`.gitignore` keeps out three things**, and it is worth knowing why so you do not
  undo it. `.godot/` is Godot's import cache and is machine-specific. `verification/`
  holds screenshots taken while developing, not assets the game loads.
  `addons/.godot_ai_update/` is 7.3 MB of the AI addon's own self-update cache —
  vendored copies of old plugin releases that the addon regenerates by itself.
  Without that last rule the repo is more than twice the size for no benefit.

## Licence

MIT â€” see `LICENSE`.

