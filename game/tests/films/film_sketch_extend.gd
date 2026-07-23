extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")
const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")

## Film: extend tool (sketch parity extend binding).


func run_film(ctx: FilmContext) -> void:
	var main = ctx.main
	var sm: SketchMode = main.sketch_mode

	await ctx.beat("Sketch a short line and a vertical target", 0.5)
	await FilmUI.enter_sketch(ctx)
	var _a: String = sm.sketch.add_line(0, 0, 10, 0)
	var _b: String = sm.sketch.add_line(20, -5, 20, 5)

	await ctx.beat("Extend the line until it meets the target", 0.4)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.EXTEND)
	var hit := Vector2(9, 0)
	var screen := FilmUI.sketch_uv_to_screen(ctx, hit)
	var cue: Dictionary = FilmUICues.tool_keys(SketchMode.Tool.EXTEND)
	await ctx.chrome.animate_pointer_click(screen, str(cue.keys), str(cue.desc))
	sm.extend_at(hit)
	await ctx.clock.wait_sec(ctx.tree, 0.6)
	ctx.chrome.clear_keys()

	await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	await ctx.beat("Line extended to intersection", 1.0)
	await ctx.camera.showcase_smooth(0.9, 28.0)

