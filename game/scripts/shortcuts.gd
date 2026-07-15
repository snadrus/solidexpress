class_name Shortcuts
## Central keyboard / mouse shortcut registry for the F1 help overlay.
## Entries mirror the live bindings in orbit_camera, viewport_interaction, and main.


const TABLE: Array[Dictionary] = [
	# View (orbit_camera.gd + viewport_interaction display/section/gizmos)
	{"keys": "Empty-space drag", "context": "View", "desc": "Orbit camera"},
	{"keys": "Right-drag", "context": "View", "desc": "Orbit camera (click alone opens context menu)"},
	{"keys": "Two-finger drag", "context": "View", "desc": "Orbit camera (trackpad; hold click for more sensitivity)"},
	{"keys": "Alt+Left-drag", "context": "View", "desc": "Orbit camera (touchpad-friendly)"},
	{"keys": "Middle-drag", "context": "View", "desc": "Orbit (SX/SW) or pan (Fusion nav preset)"},
	{"keys": "Shift+Middle", "context": "View", "desc": "Pan (SX/SW) or orbit (Fusion nav preset)"},
	{"keys": "Alt+Shift+Left-drag", "context": "View", "desc": "Pan / orbit per nav preset"},
	{"keys": "Double-Middle", "context": "View", "desc": "Fit selection (or all)"},
	{"keys": "Wheel / pinch", "context": "View", "desc": "Zoom toward cursor (Ctrl+two-finger drag also zooms on Linux)"},
	{"keys": "Ctrl+Empty-drag", "context": "View", "desc": "Rubber-band box select"},
	{"keys": "Space", "context": "View", "desc": "Orientation panel (views / fit / named view)"},
	{"keys": "Right-click", "context": "Model", "desc": "Selection context menu (Fillet / Look at / Hide / Delete)"},
	{"keys": "Rotate arcs / Pull tip", "context": "Model", "desc": "Rotate about X/Y/Z or push/pull selected face"},
	{"keys": "F", "context": "View", "desc": "Fit selection (or all if none)"},
	{"keys": "Shift+F", "context": "View", "desc": "Fit all bodies"},
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
	{"keys": "Empty click", "context": "Model", "desc": "Clear selection"},
	{"keys": "Shift+Click", "context": "Model", "desc": "Add / toggle multi-select (empty click keeps selection)"},
	{"keys": "Ctrl+Click", "context": "Model", "desc": "Add / toggle multi-select"},
	{"keys": "Drag body", "context": "Model", "desc": "Move on the active plane; shows old/new center + editable Δ"},
	{"keys": "ΔZ / lift grip (above body)", "context": "Model", "desc": "Double-headed elevator grip — leave / approach the ground plane"},
	{"keys": "X / Y / Z (while moving)", "context": "Model", "desc": "Lock the body move to that axis (tap again to free; highlighted axis line)"},
	{"keys": "Stretch arrow (face)", "context": "Model", "desc": "Single outward chevron — stretch that face; Enter refines Δ"},
	{"keys": "Drag rotate arc", "context": "Model", "desc": "Rotate about that axis; Enter refines Δ°"},
	{"keys": "Join / Subtract / Intersect", "context": "Model", "desc": "Shown on multi-body selection — applies instantly (primary keeps the result)"},
	{"keys": "Drag face", "context": "Model", "desc": "Push / pull selected face"},
	{"keys": "Del / Backspace", "context": "Model", "desc": "Delete selected body (or component instance)"},
	{"keys": "Ctrl+C", "context": "Model", "desc": "Copy selected bodies"},
	{"keys": "Ctrl+V", "context": "Model", "desc": "Paste copy offset 20% of bounds on the ground plane"},
	{"keys": "Drag instance", "context": "Model", "desc": "Move a component instance; mates re-solve on release"},
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
	{"keys": "Click badge", "context": "Sketch", "desc": "Select a constraint (H/V/∥/⊥/=/◉ glyphs)"},
	{"keys": "Del", "context": "Sketch", "desc": "Delete the selected constraint badge"},
	{"keys": "Click dimension", "context": "Sketch", "desc": "Edit the value in place (Enter commits)"},
	{"keys": "Right-click", "context": "Sketch", "desc": "End line chain"},
	{"keys": "Esc", "context": "Sketch", "desc": "Cancel sketch"},
	# Timeline (timeline_panel.gd)
	{"keys": "Drag row", "context": "Timeline", "desc": "Reorder features (blocked drops flash red)"},
	{"keys": "Drag rollback bar", "context": "Timeline", "desc": "Suspend features below the bar (double-click = roll to end)"},
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
