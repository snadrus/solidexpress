class_name FilmUICues
extends RefCounted

## Maps film actions to the same shortcut labels as Shortcuts.TABLE / the live app.


static func alert(keys: String, desc: String) -> Dictionary:
	return {"keys": keys, "desc": desc}


static func tool_keys(tool: int) -> Dictionary:
	match tool:
		SketchMode.Tool.LINE:
			return alert("L", "Line tool — click start and end points")
		SketchMode.Tool.CIRCLE:
			return alert("C", "Circle tool — click center, then radius")
		SketchMode.Tool.SPLINE:
			return alert("Spline", "Spline tool — click fit points, then end chain")
		SketchMode.Tool.SMART_DIM:
			return alert("D", "Smart dimension — edit value")
		SketchMode.Tool.EXTEND:
			return alert("E", "Extend tool — click the line to extend")
		_:
			return alert("Click", "Sketch click")


static func sketch_click(desc: String = "Place sketch point") -> Dictionary:
	return alert("Click", desc)


static func ctrl_pad() -> Dictionary:
	return alert("Ctrl+Click", "Add sketch pad to selection")


static func merge_join() -> Dictionary:
	return alert("Click", "Merge join — connect pad endpoints into a path")


static func exit_sketch() -> Dictionary:
	return alert("Exit Sketch", "Commit sketch and show yellow pad")


static func extrude(depth: float) -> Dictionary:
	return alert("Extrude", "Extrude profile %.0f mm (New body)" % depth)


static func dim_value(v: float) -> Dictionary:
	return alert("Dim", "Set dimension to %.2f" % v)


static func toolbar_sketch() -> Dictionary:
	return alert("Sketch", "Start sketch on picked face or ground")
