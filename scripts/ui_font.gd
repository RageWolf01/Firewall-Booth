extends Node

## Shared fonts.
##
## The booth art lettering is matched by two OFL fonts shipped in assets/fonts:
##
##   font  IBM Plex Mono SemiBold — the paperwork: ID sheet values, manual, tag,
##         stamp. It is the face the painting's typewritten text was drawn in.
##   sans  Rubik SemiBold — the info panel's softer prompt text.
##
## Registered as an autoload in project.godot. That registration is the reason
## the scripts that draw text still fall back to loading the files themselves if
## this node is missing — autoloads do NOT exist when a script is run with
## `--script` (a SceneTree harness), and the document must still draw there.

const MONO_PATH := "res://assets/fonts/IBMPlexMono-SemiBold.ttf"
const SANS_PATH := "res://assets/fonts/Rubik-Variable.ttf"

var font: Font
var sans: Font


func _ready() -> void:
	font = mono_font()
	sans = sans_font()


static func mono_font() -> Font:
	var f := load(MONO_PATH) as Font
	return f if f != null else ThemeDB.fallback_font


static func sans_font() -> Font:
	var base := load(SANS_PATH) as Font
	if base == null:
		return ThemeDB.fallback_font
	var v := FontVariation.new()
	v.base_font = base
	# Keyed by the numeric OpenType tag: a plain "wght" string key is silently
	# ignored here and the face falls back to its thin default instance.
	var ts := TextServerManager.get_primary_interface()
	v.variation_opentype = {ts.name_to_tag("wght"): 600}
	return v
