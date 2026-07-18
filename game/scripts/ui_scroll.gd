class_name UiScroll
extends RefCounted
## Soften Godot's default ScrollContainer / PopupMenu wheel jump (~page/8).
## A notch or trackpad flick should move a bit less so menus feel controllable.

## Fraction of the engine default wheel/pan step (PAGE_DIVISOR = 8).
const WHEEL_SCALE := 0.55


static func soften(scroll: ScrollContainer) -> void:
	if scroll == null or scroll.has_meta("_sx_soft_scroll"):
		return
	scroll.set_meta("_sx_soft_scroll", true)
	scroll.gui_input.connect(_on_scroll_gui_input.bind(scroll))


static func soften_menu(pm: PopupMenu) -> void:
	if pm == null or pm.has_meta("_sx_soft_menu"):
		return
	pm.set_meta("_sx_soft_menu", true)
	var apply := func() -> void:
		for c in pm.find_children("*", "ScrollContainer", true, false):
			soften(c as ScrollContainer)
	apply.call()
	if not pm.about_to_popup.is_connected(apply):
		pm.about_to_popup.connect(apply)


## Walk a UI subtree: ScrollContainers, PopupMenus, MenuButton / OptionButton popups.
static func soften_tree(root: Node) -> void:
	if root == null:
		return
	if root is ScrollContainer:
		soften(root as ScrollContainer)
	elif root is PopupMenu:
		soften_menu(root as PopupMenu)
	elif root is MenuButton:
		soften_menu((root as MenuButton).get_popup())
	elif root is OptionButton:
		soften_menu((root as OptionButton).get_popup())
	for child in root.get_children():
		soften_tree(child)


static func _on_scroll_gui_input(event: InputEvent, scroll: ScrollContainer) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		var horizontal := false
		var sign := 0.0
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				sign = -1.0
				# Shift swaps axes (same rule as ScrollContainer C++).
				horizontal = scroll.scroll_horizontal_by_default != mb.shift_pressed
			MOUSE_BUTTON_WHEEL_DOWN:
				sign = 1.0
				horizontal = scroll.scroll_horizontal_by_default != mb.shift_pressed
			MOUSE_BUTTON_WHEEL_LEFT:
				sign = -1.0
				horizontal = true
			MOUSE_BUTTON_WHEEL_RIGHT:
				sign = 1.0
				horizontal = true
			_:
				return
		var amount := sign * _wheel_step(scroll, mb.factor, horizontal)
		if is_zero_approx(amount):
			return
		if horizontal:
			scroll.scroll_horizontal = int(scroll.scroll_horizontal + amount)
		else:
			scroll.scroll_vertical = int(scroll.scroll_vertical + amount)
		scroll.accept_event()
	elif event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		var moved := false
		var h_bar := scroll.get_h_scroll_bar()
		var v_bar := scroll.get_v_scroll_bar()
		if h_bar != null and h_bar.visible and absf(pg.delta.x) > 1e-6:
			scroll.scroll_horizontal = int(scroll.scroll_horizontal \
					+ h_bar.page * pg.delta.x / 8.0 * WHEEL_SCALE)
			moved = true
		if v_bar != null and v_bar.visible and absf(pg.delta.y) > 1e-6:
			scroll.scroll_vertical = int(scroll.scroll_vertical \
					+ v_bar.page * pg.delta.y / 8.0 * WHEEL_SCALE)
			moved = true
		if moved:
			scroll.accept_event()


static func _wheel_step(scroll: ScrollContainer, factor: float, horizontal: bool) -> float:
	var bar: ScrollBar = scroll.get_h_scroll_bar() if horizontal else scroll.get_v_scroll_bar()
	if bar == null or not bar.visible:
		return 0.0
	# Match engine: page / PAGE_DIVISOR (8), then scale down.
	var page := float(bar.page)
	var change := (page / 8.0 if page > 0.0 else (bar.max_value - bar.min_value) / 16.0) \
			* factor * WHEEL_SCALE
	return maxf(change, float(bar.step))
