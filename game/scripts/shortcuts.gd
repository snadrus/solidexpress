class_name Shortcuts
## Central keyboard / mouse shortcut registry for the F1 help overlay.
## Entries mirror the live bindings in orbit_camera, viewport_interaction, and main.


const TABLE: Array[Dictionary] = [
	# View (orbit_camera.gd + viewport_interaction display/section/gizmos)
	{"keys": "Middle-drag", "context": "View", "desc": "Orbit camera"},
	{"keys": "Alt+Left-drag", "context": "View", "desc": "Orbit camera (touchpad-friendly)"},
	{"keys": "Two-finger drag", "context": "View", "desc": "Orbit camera (trackpad pan gesture)"},
	{"keys": "Shift+Middle", "context": "View", "desc": "Pan camera"},
	{"keys": "Alt+Shift+Left-drag", "context": "View", "desc": "Pan camera (touchpad-friendly)"},
	{"keys": "Wheel / pinch", "context": "View", "desc": "Zoom toward pivot"},
	{"keys": "F", "context": "View", "desc": "Fit / frame all bodies"},
	{"keys": "1", "context": "View", "desc": "Front view"},
	{"keys": "2", "context": "View", "desc": "Right view"},
	{"keys": "3", "context": "View", "desc": "Top view"},
	{"keys": "7", "context": "View", "desc": "Isometric view"},
	{"keys": "5", "context": "View", "desc": "Toggle orthographic / perspective"},
	{"keys": "W", "context": "View", "desc": "Cycle display mode (shaded / edges / wireframe)"},
	{"keys": "K", "context": "View", "desc": "Toggle section view"},
	{"keys": "G", "context": "View", "desc": "Toggle origin gizmos and grid"},
	# Model (viewport_interaction.gd)
	{"keys": "Click", "context": "Model", "desc": "Select body (again for face / edge)"},
	{"keys": "Drag", "context": "Model", "desc": "Move selected body on ground plane"},
	{"keys": "Drag face", "context": "Model", "desc": "Push / pull selected face"},
	{"keys": "Del / Backspace", "context": "Model", "desc": "Delete selected body"},
	{"keys": "Ctrl+Z", "context": "Model", "desc": "Undo"},
	{"keys": "Ctrl+Y", "context": "Model", "desc": "Redo"},
	{"keys": "Ctrl+Shift+Z", "context": "Model", "desc": "Redo"},
	# Voice (voice_capture.gd — hold-to-talk; registry is documentation only)
	{"keys": "V (hold)", "context": "Model", "desc": "Push-to-talk voice capture"},
	# Sketch (viewport_interaction._sketch_input)
	{"keys": "S", "context": "Sketch", "desc": "Select tool"},
	{"keys": "L", "context": "Sketch", "desc": "Line tool"},
	{"keys": "R", "context": "Sketch", "desc": "Rectangle tool"},
	{"keys": "C", "context": "Sketch", "desc": "Circle tool"},
	{"keys": "T", "context": "Sketch", "desc": "Trim tool"},
	{"keys": "X", "context": "Sketch", "desc": "Toggle construction on selection"},
	{"keys": "Right-click", "context": "Sketch", "desc": "End line chain"},
	{"keys": "Esc", "context": "Sketch", "desc": "Cancel sketch"},
	# File (main.gd _unhandled_input)
	{"keys": "Ctrl+S", "context": "File", "desc": "Save"},
	{"keys": "Ctrl+O", "context": "File", "desc": "Open"},
]


static func all() -> Array[Dictionary]:
	return TABLE


static func by_context() -> Dictionary:
	var out: Dictionary = {}
	for entry in TABLE:
		var ctx: String = entry["context"]
		if not out.has(ctx):
			out[ctx] = [] as Array
		(out[ctx] as Array).append(entry)
	return out


static func describe(keys: String) -> String:
	for entry in TABLE:
		if entry["keys"] == keys:
			return entry["desc"]
	return ""
