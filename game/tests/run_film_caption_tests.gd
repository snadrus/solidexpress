# Run: tools/godot/godot --headless --path game --script tests/run_film_caption_tests.gd
extends SceneTree

const _FilmChromeBoot := preload("res://tests/lib/film_chrome.gd")

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   - " + msg)
	else:
		failures += 1
		printerr("  FAIL - " + msg)


func _init() -> void:
	print("film caption tests")
	check(FilmChrome.format_webvtt_time(0.0) == "00:00:00.000", "format zero")
	check(FilmChrome.format_webvtt_time(61.5) == "00:01:01.500", "format mm:ss")
	var cues: Array = [
		{"start_frame": 0, "end_frame": 60, "text": "Step one"},
		{"start_frame": 60, "end_frame": 120, "text": "Step two"},
	]
	var vtt := FilmChrome.cues_to_webvtt(cues, 60.0)
	check(vtt.begins_with("WEBVTT"), "starts with WEBVTT")
	check("Step one" in vtt and "Step two" in vtt, "includes cue text")
	check("00:00:00.000 --> 00:00:01.000" in vtt, "first cue timing")
	check("00:00:01.000 --> 00:00:02.000" in vtt, "second cue timing")
	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)
