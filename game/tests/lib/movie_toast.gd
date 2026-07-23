class_name MovieToast
extends RefCounted

## Brief top-of-screen intent banner for demo films (distinct from step captions).


static func show_on(chrome: FilmChrome, text: String) -> void:
	if chrome == null:
		return
	chrome.show_toast(text)


static func dismiss_on(chrome: FilmChrome) -> void:
	if chrome == null:
		return
	chrome.hide_toast()
