extends Node

## Shared UI font.
##
## The ID document draws its text with draw_string() rather than using Label
## nodes, so it needs a Font resource. Godot's default theme font is available
## through ThemeDB, but it is behind a runtime theme lookup; holding one
## reference here keeps the document self-contained and avoids repeating the
## lookup on every redraw.
##
## Registered as an autoload in project.godot. That registration is the reason
## `InspectionWindow` still falls back to ThemeDB directly if this node is
## missing — autoloads do NOT exist when a script is run with `--script` (a
## SceneTree harness), and the document must still draw there.

var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
