class_name FilmContext
extends RefCounted

var main
var view: DocumentView
var camera: FilmCamera
var chrome: FilmChrome
var clock: FilmClock
var tree: SceneTree


## Advance the narrative: closed caption + short hold.
func beat(caption: String, hold_sec: float = 0.75) -> void:
	if chrome != null:
		chrome.show_caption(caption)
	await tree.process_frame
	await clock.wait_sec(tree, hold_sec)


func after_regen() -> void:
	if view != null:
		view.refresh()
	if main != null and main.has_method("_on_document_changed"):
		main._on_document_changed()
	await tree.process_frame
	await tree.process_frame
