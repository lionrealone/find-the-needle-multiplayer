extends CanvasLayer
const AUTHOR := "lionderwahre"

const COL_TITLE := Color(1.0, 0.86, 0.34)
const COL_TEXT := Color(0.95, 0.96, 0.99)
const COL_DIM := Color(0.7, 0.73, 0.79)
const COL_BG := Color(0.03, 0.04, 0.06, 0.92)
const COL_PLATE := Color(0.03, 0.035, 0.045, 0.82)
const COL_CARD := Color(0.035, 0.045, 0.065, 0.97)
const COL_FIELD := Color(0.03, 0.04, 0.06, 0.72)
const COL_OFF := Color(0.44, 0.46, 0.5)
const COL_DONE := Color(0.72, 0.93, 0.56)
const COL_BAR := Color(0.84, 0.66, 0.28)
const COL_BAR_BACK := Color(1.0, 1.0, 1.0, 0.08)
const FEED_SECONDS := 7.0
const FEED_MAX := 6
const FEED_IN := 0.25
const FEED_OUT := 1.0
const WAIT_W := 372.0
const WAIT_TICK := 0.15
const WAIT_DONE := 5.0
const WAIT_BREATH := 2.8
const MARK_DONE := "✓"

enum Step { CONNECT, SAVE, WORLD, LOADING, INSIDE }

var mp: Node

var _root: ColorRect
var _panel: PanelContainer
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _port_edit: SpinBox
var _status: Label
var _progress: ProgressBar
var _players_label: RichTextLabel
var _host_btn: Button
var _steam_host_btn: Button
var _invite_btn: Button
var _steam_label: Label
var _ip_toggle: Button
var _ips_btn: Button
var _steps_label: RichTextLabel
var _help_label: Label
var _close_btn: Button
var _title_label: Label
var _subtitle_label: Label
var _show_ips := false
var _ip_box: VBoxContainer
var _join_btn: Button
var _leave_btn: Button
var _resync_btn: Button
var _ips_label: Label
var _view_main: VBoxContainer
var _view_create: VBoxContainer
var _create_sizes: VBoxContainer
var _back_btn: Button
var _create_title: Label
var _create_credit: Label
var _btn_new_game: Button
var _btn_load_game: Button
var _auto_open_done := false

var _feed: VBoxContainer
var _chat_box: PanelContainer
var _chat_edit: LineEdit
var _roster: RichTextLabel
var _roster_on := false
var _mouse_was_captured := false

var _last_note: Control = null
var _last_note_text := ""
var _last_note_n := 1

var _wait: PanelContainer
var _wait_title: Label
var _wait_sub: Label
var _wait_hint: Label
var _wait_bar: ProgressBar
var _wait_marks: Array[Label] = []
var _wait_names: Array[Label] = []
var _wait_rows: Array[StyleBoxFlat] = []
var _wait_sig := ""
var _wait_now := -1
var _wait_clock := 0.0
var _wait_t := 0.0
var _wait_done_at := 0.0
var _progress_v := -1.0

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_feed()
	_build_roster()
	_build_chat()
	_build_wait()
	_build_panel()
	refresh()

var _font_cache: Font = null
var _font_tried := false
var _ui_font_cls: Script = null
var _ui_font_tried := false

func _font() -> Font:
	if not _font_tried:
		_font_tried = true
		var cls := _ui_font()
		if cls != null:
			_font_cache = cls.call("bold")
	return _font_cache

func _ui_font() -> Script:
	if not _ui_font_tried:
		_ui_font_tried = true
		_ui_font_cls = _global_class("UiFont")
	return _ui_font_cls

func _style(l: Label, size: int, col: Color, outline := 4, heavy := false) -> void:
	var cls := _ui_font()
	if cls != null:
		cls.call("style", l, size, col, outline, heavy)
		return
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", outline)

func _styled(text: String, size: int, col: Color, outline := 4, heavy := false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style(l, size, col, outline, heavy)
	return l

func _global_class(n: String) -> Script:
	for c in ProjectSettings.get_global_class_list():
		if str(c["class"]) == n:
			return load(str(c["path"]))
	return null

func _label(text: String, size := 18, col := COL_TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 560
	var f := _font()
	if f != null and size >= 20:
		l.add_theme_font_override("font", f)
	return l

func _plate(accent: Color, mx := 12.0, my := 8.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PLATE
	sb.border_color = accent
	sb.border_width_left = 3
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my + 1.0
	return sb

func _card() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_CARD
	sb.set_border_width_all(1)
	sb.border_color = Color(COL_TITLE, 0.55)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	return sb

func _style_bar(bar: ProgressBar, square := false) -> void:
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	var r := 0 if square else 3
	var back := StyleBoxFlat.new()
	back.bg_color = COL_BAR_BACK
	back.set_corner_radius_all(r)
	var fill := StyleBoxFlat.new()
	fill.bg_color = COL_BAR
	fill.set_corner_radius_all(r)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)

func _button(text: String, cb: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 19)
	var f := _font()
	if f != null:
		b.add_theme_font_override("font", f)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		var base := Color(0.16, 0.14, 0.06) if accent else Color(0.1, 0.11, 0.14)
		sb.bg_color = base.lightened(0.12) if st == "hover" else (base.darkened(0.3) if st == "disabled" else base)
		sb.border_width_left = 4 if st == "hover" or accent else 0
		sb.border_color = COL_TITLE
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.corner_radius_top_left = 3
		sb.corner_radius_top_right = 3
		sb.corner_radius_bottom_left = 3
		sb.corner_radius_bottom_right = 3
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", COL_TITLE if accent else COL_TEXT)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.46, 0.5))
	b.pressed.connect(cb)
	return b

func _edit(text: String, placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, 40)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.add_theme_font_size_override("font_size", 19)
	return e

func _field(parent: Control, caption: String, ctl: Control) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_label(caption, 14, COL_DIM))
	box.add_child(ctl)
	parent.add_child(box)

func _build_panel() -> void:
	_root = ColorRect.new()
	_root.color = Color(0, 0, 0, 0.45)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG
	sb.border_width_left = 5
	sb.border_color = COL_TITLE
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(_panel)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 0)
	_panel.add_child(shell)

	_view_main = VBoxContainer.new()
	_view_main.add_theme_constant_override("separation", 14)
	shell.add_child(_view_main)

	_title_label = _label(mp.t("title"), 34, COL_TITLE)
	_view_main.add_child(_title_label)
	_subtitle_label = _label(mp.t("credit"), 15, COL_DIM)
	_view_main.add_child(_subtitle_label)

	_steam_host_btn = _button(mp.t("create_game"), _create_lobby, true)
	_view_main.add_child(_steam_host_btn)
	_invite_btn = _button(mp.t("invite_friends"), func() -> void: mp.invite_friends(), true)
	_view_main.add_child(_invite_btn)
	_ip_toggle = _button(mp.t("ip_section"), func() -> void:
		_ip_box.visible = not _ip_box.visible)
	_view_main.add_child(_ip_toggle)

	_ip_box = VBoxContainer.new()
	_ip_box.add_theme_constant_override("separation", 10)
	_ip_box.visible = false
	_view_main.add_child(_ip_box)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	_ip_edit = _edit(mp.last_ip, mp.t("ip_hint"))
	_field(row2, mp.t("host_ip"), _ip_edit)
	_port_edit = SpinBox.new()
	_port_edit.min_value = 1024
	_port_edit.max_value = 65535
	_port_edit.value = mp.last_port
	_port_edit.custom_minimum_size = Vector2(140, 40)
	var port_box := VBoxContainer.new()
	port_box.add_theme_constant_override("separation", 4)
	port_box.add_child(_label(mp.t("port"), 14, COL_DIM))
	port_box.add_child(_port_edit)
	row2.add_child(port_box)
	_ip_box.add_child(row2)

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 10)
	_host_btn = _button(mp.t("create_server"), _on_host, true)
	_join_btn = _button(mp.t("join"), _on_join, true)
	row3.add_child(_host_btn)
	row3.add_child(_join_btn)
	_ip_box.add_child(row3)

	_ips_btn = _button(mp.t("show_ips"), func() -> void:
		_show_ips = not _show_ips
		refresh())
	_ip_box.add_child(_ips_btn)
	_ips_label = _label("", 14, COL_DIM, true)
	_ip_box.add_child(_ips_label)

	_leave_btn = _button(mp.t("disconnect"), func() -> void: mp.leave(mp.t("session_closed")))
	_view_main.add_child(_leave_btn)
	_resync_btn = _button(mp.t("resync"), func() -> void: mp.request_resync())
	_resync_btn.visible = false
	_view_main.add_child(_resync_btn)

	_close_btn = _button(mp.t("close"), close_panel)
	_view_main.add_child(_close_btn)

	_view_create = VBoxContainer.new()
	_view_create.visible = false
	shell.add_child(_view_create)
	_create_title = _label("", 1, COL_TITLE)
	_create_title.visible = false
	_view_create.add_child(_create_title)
	_create_credit = _label("", 1, COL_DIM)
	_create_credit.visible = false
	_view_create.add_child(_create_credit)
	_btn_new_game = _button("", func() -> void: pass, true)
	_btn_new_game.visible = false
	_view_create.add_child(_btn_new_game)
	_btn_load_game = _button("", func() -> void: pass, true)
	_btn_load_game.visible = false
	_view_create.add_child(_btn_load_game)
	_create_sizes = VBoxContainer.new()
	_create_sizes.visible = false
	_view_create.add_child(_create_sizes)
	_back_btn = _button("", _open_main_view)
	_back_btn.visible = false
	_view_create.add_child(_back_btn)

	_name_edit = _edit(mp.my_name, "")
	_name_edit.visible = false
	_view_main.add_child(_name_edit)
	_steam_label = _label("", 1, COL_DIM)
	_steam_label.visible = false
	_view_main.add_child(_steam_label)
	_steps_label = RichTextLabel.new()
	_steps_label.visible = false
	_view_main.add_child(_steps_label)
	_status = _label("", 1, COL_TEXT)
	_status.visible = false
	_view_main.add_child(_status)
	_progress = ProgressBar.new()
	_progress.visible = false
	_view_main.add_child(_progress)
	_players_label = RichTextLabel.new()
	_players_label.visible = false
	_view_main.add_child(_players_label)
	_help_label = _label("", 1, COL_DIM)
	_help_label.visible = false
	_view_main.add_child(_help_label)

func _build_feed() -> void:
	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_feed.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_feed.alignment = BoxContainer.ALIGNMENT_END
	_feed.add_theme_constant_override("separation", 6)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)

	_feed.anchor_left = 0.5
	_feed.anchor_right = 0.5
	_feed.anchor_top = 1.0
	_feed.anchor_bottom = 1.0
	_feed.offset_top = -432
	_feed.offset_bottom = -212
	_feed.offset_left = -280
	_feed.offset_right = 280

func _build_roster() -> void:
	_roster = RichTextLabel.new()
	_roster.bbcode_enabled = true
	_roster.fit_content = true
	_roster.scroll_active = false
	_roster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roster.add_theme_font_size_override("normal_font_size", 16)
	_roster.add_theme_constant_override("outline_size", 5)
	_roster.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_roster.anchor_left = 1.0
	_roster.anchor_right = 1.0
	_roster.offset_left = -300
	_roster.offset_right = -16
	_roster.offset_top = 150
	_roster.offset_bottom = 400
	add_child(_roster)

func _build_chat() -> void:
	_chat_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_FIELD
	sb.set_border_width_all(1)
	sb.border_color = COL_TITLE
	sb.content_margin_left = 14
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 7
	_chat_box.add_theme_stylebox_override("panel", sb)
	_chat_box.anchor_left = 0.5
	_chat_box.anchor_right = 0.5
	_chat_box.anchor_top = 1.0
	_chat_box.anchor_bottom = 1.0
	_chat_box.offset_left = -360
	_chat_box.offset_right = 360
	_chat_box.offset_top = -206
	_chat_box.offset_bottom = -162
	_chat_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_chat_box.visible = false
	add_child(_chat_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_chat_box.add_child(row)
	row.add_child(_key_cap("enter", "ENTER"))

	_chat_edit = LineEdit.new()
	_chat_edit.placeholder_text = mp.t("chat_hint")
	_chat_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_edit.max_length = 200
	_chat_edit.context_menu_enabled = false

	for st in ["normal", "focus", "read_only"]:
		_chat_edit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var cls := _ui_font()
	if cls != null:
		_chat_edit.add_theme_font_override("font", cls.call("regular"))
	_chat_edit.add_theme_font_size_override("font_size", 20)
	_chat_edit.add_theme_color_override("font_color", COL_TEXT)
	_chat_edit.add_theme_color_override("font_placeholder_color", Color(COL_DIM, 0.7))
	_chat_edit.add_theme_color_override("caret_color", COL_TITLE)
	_chat_edit.text_submitted.connect(_on_chat_submit)
	row.add_child(_chat_edit)

func _key_cap(key: String, fallback: String) -> Control:
	var icons := _global_class("InputIcons")
	var tex: Variant = icons.call("named", key) if icons != null else null
	if tex is Texture2D:
		var r := TextureRect.new()
		r.texture = tex
		r.custom_minimum_size = Vector2(34, 30)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return r
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.2)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", sb)
	chip.add_child(_styled(fallback, 17, Color(0.94, 0.96, 1.0), 0, true))
	return chip

func _build_wait() -> void:
	_wait = PanelContainer.new()
	_wait.visible = false
	_wait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wait.add_theme_stylebox_override("panel", _card())
	_wait.anchor_left = 1.0
	_wait.anchor_right = 1.0
	_wait.anchor_top = 0.5
	_wait.anchor_bottom = 0.5
	_wait.offset_left = -(WAIT_W + 44.0)
	_wait.offset_right = -44.0
	_wait.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_wait)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 10)
	_wait.add_child(v)

	_wait_title = _styled(mp.t("wait_title"), 21, COL_TITLE, 5, true)
	v.add_child(_wait_title)
	_wait_sub = _styled("", 16, COL_DIM)
	v.add_child(_wait_sub)

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 2)
	v.add_child(rows)
	for i in Step.size():

		var box := PanelContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color(COL_TITLE, 0)
		sb.border_width_left = 3
		sb.content_margin_left = 10
		sb.content_margin_right = 8
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		box.add_theme_stylebox_override("panel", sb)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var mark := _styled("", 16, COL_DONE)
		mark.custom_minimum_size.x = 14
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var name_l := _styled("", 16, COL_OFF)
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(mark)
		row.add_child(name_l)
		rows.add_child(box)
		_wait_marks.append(mark)
		_wait_names.append(name_l)
		_wait_rows.append(sb)

	_wait_bar = ProgressBar.new()
	_wait_bar.custom_minimum_size = Vector2(0, 6)
	_wait_bar.visible = false
	_style_bar(_wait_bar, true)
	v.add_child(_wait_bar)

	_wait_hint = _styled("", 16, COL_DIM)
	_wait_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_wait_hint)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	if _chat_box.visible:
		if k == KEY_ESCAPE:
			_close_chat()
			get_viewport().set_input_as_handled()
		return
	if k == KEY_F2:
		if _root.visible:
			close_panel()
		else:
			open_panel()
		get_viewport().set_input_as_handled()
	elif k == KEY_ESCAPE and _root.visible:
		close_panel()
		get_viewport().set_input_as_handled()
	elif k == KEY_Y and mp.active() and mp.in_world() and not _root.visible:
		_open_chat()
		get_viewport().set_input_as_handled()
	elif k == KEY_F6 and mp.in_world():
		_toggle_debug_menu()
		get_viewport().set_input_as_handled()
	elif k == KEY_F8 and mp.active():
		mp.request_resync()
		get_viewport().set_input_as_handled()

func _toggle_debug_menu() -> void:
	var w: Node = mp.world_sync.world
	var dm: Variant = w.get("debug_menu")
	if dm == null or not is_instance_valid(dm):
		var cls := _global_class("DebugMenu")
		if cls == null:
			notify(mp.t("no_debug_menu"))
			return

		if not InputMap.has_action("debug_menu"):
			InputMap.add_action("debug_menu")
		dm = cls.new()
		dm.name = "DebugMenu"
		dm.player = w.get("player")
		dm.world = w
		dm.props = w.get("props")
		dm.hud = w.get("hud")
		dm.live = w.get("live")
		dm.builds = w.get("builds")
		add_child(dm)
		w.set("debug_menu", dm)
		_add_take_money(dm)
	dm.toggle()
	if dm.is_open():
		_release_mouse()
	else:
		_restore_mouse()

func _add_take_money(dm: Node) -> void:
	var row := _find_money_row(dm)
	if row == null:
		return
	for amount in [100.0, 1000.0, 10000.0]:
		var label := "-$%s" % _money_text(amount)
		row.add_child(dm._button(label, dm._on_grant.bind(-amount)))

func _find_money_row(n: Node) -> Node:
	for child in n.get_children():
		if child is HBoxContainer:
			for b in child.get_children():
				if b is Button and (b as Button).text.begins_with("+$"):
					return child
		var found := _find_money_row(child)
		if found != null:
			return found
	return null

func _money_text(amount: float) -> String:
	var n := int(amount)
	var out := ""
	while n >= 1000:
		out = ",%03d%s" % [n % 1000, out]
		n /= 1000
	return "%d%s" % [n, out]

func _world_player() -> Node:
	if mp.world_sync != null and is_instance_valid(mp.world_sync.player):
		return mp.world_sync.player
	return null

func _release_mouse() -> void:
	var p := _world_player()
	_mouse_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if p != null and p.has_method("capture_mouse"):
		p.capture_mouse(false)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _restore_mouse() -> void:
	if not _mouse_was_captured:
		return
	var p := _world_player()
	if p != null and p.has_method("capture_mouse"):
		p.capture_mouse(true)

func open_panel() -> void:
	if _root.visible:
		return
	_name_edit.text = mp.my_name
	_ip_edit.text = mp.last_ip
	_port_edit.value = mp.last_port
	_open_main_view()
	_root.visible = true
	_release_mouse()
	refresh()

func close_panel() -> void:
	if not _root.visible:
		return
	_root.visible = false
	_open_main_view()
	_restore_mouse()
	_update_wait()

func _open_main_view() -> void:
	_view_main.visible = true
	_view_create.visible = false

func _create_lobby() -> void:
	if mp.active():
		notify(mp.t("already_hosting"))
		return
	_open_main_view()
	mp.host_steam()

func unlock_menu_play_buttons() -> void:
	var menu := get_tree().current_scene
	if menu == null or not mp.is_menu(menu):
		return
	if not mp.active() or not mp.is_host:
		return
	for keys in [
		["NEW_GAME", "NEW GAME", "NEUES SPIEL", "NEW", "PLAY", "START"],
		["LOAD_GAME", "LOAD", "LOAD SAVE", "SPIELSTAND LADEN", "LADEN", "CONTINUE", "FORTSETZEN"],
	]:
		var b := _find_button_by_keys(menu, keys)
		if b == null:
			continue
		b.disabled = false
		b.visible = true
		b.modulate = Color.WHITE
		b.mouse_filter = Control.MOUSE_FILTER_STOP

func trigger_menu_action(action: String) -> void:
	var menu := get_tree().current_scene
	if menu == null or not mp.is_menu(menu):
		notify(mp.t("use_game_menu"))
		return
	var keys: Array = []
	if action == "new_game":
		keys = ["NEW_GAME", "NEW GAME", "NEUES SPIEL", "NEW"]
	elif action == "load_game":
		keys = ["LOAD_GAME", "LOAD", "LOAD SAVE", "SPIELSTAND LADEN", "LADEN", "CONTINUE"]
	else:
		return
	unlock_menu_play_buttons()
	var b := _find_button_by_keys(menu, keys)
	if b == null:
		notify(mp.t("use_game_menu"))
		return
	Audio.play("ui_open")
	b.pressed.emit()

func _find_button_by_keys(root: Node, keys: Array) -> Button:
	var want: Array[String] = []
	for k in keys:
		want.append(str(k).to_lower())
		if root != null:
			want.append(str(root.tr(str(k))).to_lower())
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button:
			var t := (n as Button).text.strip_edges().to_lower()
			for w in want:
				if w != "" and (t == w or t.contains(w)):
					return n
		stack.append_array(n.get_children())
	return null

func _open_chat() -> void:
	_chat_box.visible = true
	_chat_edit.text = ""
	_release_mouse()
	_chat_edit.grab_focus.call_deferred()

func _close_chat() -> void:
	_chat_edit.release_focus()
	_chat_box.visible = false
	_restore_mouse()

func _on_chat_submit(text: String) -> void:
	mp.send_chat(text)
	_close_chat()

func _on_host() -> void:
	mp.host(int(_port_edit.value))

func _on_join() -> void:
	var ip := _ip_edit.text.strip_edges()
	if ip == "":
		notify(mp.t("ask_ip"))
		return
	mp.join(ip, int(_port_edit.value))

func set_status(text: String) -> void:
	_status.text = text

func set_progress(v: float) -> void:
	_progress_v = v
	_progress.visible = v >= 0.0
	if v >= 0.0:
		_progress.value = v * 100.0
	_update_wait()

func notify(text: String, accent := COL_TITLE) -> void:
	print("[MPMod] ", text)
	set_status(text)

	if text == _last_note_text and is_instance_valid(_last_note) and _last_note.get_parent() == _feed:
		_last_note_n += 1
		var badge: Variant = _last_note.get_meta("badge", null)
		if badge is Label:
			(badge as Label).text = mp.t("note_repeat") % _last_note_n
			(badge as Label).visible = true
		_feed.move_child(_last_note, _feed.get_child_count() - 1)
		_feed_life(_last_note, false)
		return
	_last_note_text = text
	_last_note_n = 1
	_last_note = _feed_card(accent, "", text)
	_push_feed(_last_note)

func chat_line(who: String, col: Color, text: String) -> void:
	_forget_note()
	_push_feed(_feed_card(col, mp.t("chat_name") % who, text))

func _feed_card(accent: Color, who: String, text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _plate(accent))
	card.modulate.a = 0.0
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	if who != "":
		var n := _styled(who, 17, accent, 4, true)
		n.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(n)
	var msg := _styled(text, 17, COL_TEXT)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(msg)
	var badge := _styled("", 13, COL_DIM, 3, true)
	badge.visible = false
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	card.set_meta("badge", badge)
	return card

func _esc(s: String) -> String:
	return s.replace("[", "[lb]")

func _push_feed(c: Control) -> void:
	_feed.add_child(c)
	while _feed.get_child_count() > FEED_MAX:
		var old := _feed.get_child(0) as Control
		_feed.remove_child(old)
		_drop_feed(old)
	_feed_life(c, true)

func _feed_life(c: Control, fade_in: bool) -> void:
	_kill_life(c)
	var t := create_tween()
	c.set_meta("tw", t)
	if fade_in:
		t.tween_property(c, "modulate:a", 1.0, FEED_IN)
	else:
		c.modulate.a = 1.0
	t.tween_interval(FEED_SECONDS)
	t.tween_property(c, "modulate:a", 0.0, FEED_OUT)
	t.tween_callback(_drop_feed.bind(c))

func _kill_life(c: Control) -> void:

	if not c.has_meta("tw"):
		return
	var tw: Variant = c.get_meta("tw")
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()

func _drop_feed(c: Control) -> void:
	if not is_instance_valid(c):
		return
	_kill_life(c)
	if _last_note == c:
		_forget_note()
	c.queue_free()

func _forget_note() -> void:
	_last_note = null
	_last_note_text = ""
	_last_note_n = 1

func _process(delta: float) -> void:
	if _wait == null:
		return
	_wait_clock += delta
	if _wait_clock >= WAIT_TICK:
		_wait_clock = 0.0
		_update_wait()
	_pulse_wait(delta)

func _wait_step() -> int:
	if not mp.active() or mp.is_host:
		return -1
	if mp.phase == mp.Phase.IN_WORLD and mp.in_world():
		return Step.INSIDE
	if mp.phase == mp.Phase.LOADING:

		return Step.WORLD if _progress_v >= 0.0 else Step.LOADING
	if mp.phase == mp.Phase.LOBBY:
		var host: Dictionary = mp.players.get(1, {})

		return Step.WORLD if str(host.get("state", "")) == "world" else Step.SAVE
	return Step.CONNECT

func _update_wait() -> void:
	if _wait == null:
		return
	var step := _wait_step()
	var up := step >= 0 and not (_root != null and _root.visible)
	if step < 0:
		_wait_done_at = 0.0
	elif step == Step.INSIDE:
		if _wait_done_at <= 0.0:
			_wait_done_at = _clock() + WAIT_DONE
		elif _clock() >= _wait_done_at:
			up = false
	else:
		_wait_done_at = 0.0
	if up:
		var pct: int = int(round(_progress_v * 100.0)) if _progress_v >= 0.0 else -1
		var host := ""
		if mp.players.has(1):
			var hp: Dictionary = mp.players[1]
			host = str(hp.get("name", ""))
		var sig := "%d|%d|%s|%s" % [step, pct, host, mp.i18n.locale()]
		if sig != _wait_sig:
			_wait_sig = sig
			_write_wait(step, pct, host)
	_wait.visible = up
	if _roster != null:

		_roster.visible = _roster_on and not up

func _write_wait(step: int, pct: int, host: String) -> void:
	_wait_title.text = mp.t("wait_title")
	_wait_sub.text = mp.t("wait_sub") % host
	_wait_sub.visible = host != ""
	var names := PackedStringArray(["wait_connect", "wait_save", "wait_world", "wait_load", "wait_in"])
	for i in _wait_names.size():
		var mark := _wait_marks[i]
		var row := _wait_names[i]
		if i == step and i == Step.WORLD and pct >= 0:
			row.text = mp.t("wait_world_pct") % pct
		else:
			row.text = mp.t(names[i])
		var sb := _wait_rows[i]

		mark.text = MARK_DONE if i < step else ""
		if i == step:
			_style(row, 16, COL_TEXT, 4, true)
			sb.bg_color = Color(0.02, 0.03, 0.05, 0.3)
			sb.border_color = COL_TITLE
		else:
			_style(row, 16, COL_DIM if i < step else COL_OFF)
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = Color(COL_TITLE, 0)
	var hints := PackedStringArray(["wait_hint_connect", "wait_hint_save", "wait_hint_world", "wait_hint_load", "wait_hint_in"])
	_wait_hint.text = mp.t(hints[step])
	_wait_bar.visible = step == Step.WORLD and pct >= 0
	_wait_bar.value = float(maxi(pct, 0))
	_wait_now = step

func _pulse_wait(delta: float) -> void:
	if not _wait.visible or _wait_now < 0 or _wait_now >= _wait_rows.size() or _wait_now == Step.INSIDE:
		return
	_wait_t += delta
	var a := 0.675 + 0.275 * sin(TAU * _wait_t / WAIT_BREATH)
	_wait_rows[_wait_now].border_color = Color(COL_TITLE, a)

func _clock() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _steps_text() -> String:
	var steps := [mp.t("create_game"), mp.t("invite_friends"), mp.t("step_play")]
	var at := 0
	if mp.active() and mp.is_host:
		at = 1 if not mp.in_world() else 2
		if mp.players.size() > 1:
			at = 2
	elif mp.active():
		steps = [mp.t("step_connecting"), mp.t("step_entering"), mp.t("step_dig")]
		at = 1 if mp.phase == mp.Phase.LOADING else (2 if mp.in_world() else 0)
	var out := PackedStringArray()
	for i in steps.size():
		var col := COL_TITLE.to_html(false) if i == at else "8a8f99"
		var mark := "▶" if i == at else "%d ·" % (i + 1)
		out.append("[color=#%s]%s %s[/color]" % [col, mark, steps[i]])
	return "   ".join(out)

func _apply_texts() -> void:
	_title_label.text = mp.t("title")
	_subtitle_label.text = mp.t("credit")
	_steam_host_btn.text = mp.t("create_game")
	_invite_btn.text = mp.t("invite_friends")
	_ip_toggle.text = mp.t("ip_section")
	_host_btn.text = mp.t("create_server")
	_join_btn.text = mp.t("join")
	_leave_btn.text = mp.t("disconnect")
	_resync_btn.text = mp.t("resync")
	_close_btn.text = mp.t("close")
	_ip_edit.placeholder_text = mp.t("ip_hint")
	_chat_edit.placeholder_text = mp.t("chat_hint")

func refresh() -> void:
	if _panel == null:
		return
	_apply_texts()
	_open_main_view()
	var on: bool = mp.active()
	var steam_ok: bool = mp.steam_ready()
	_steam_host_btn.disabled = on or not steam_ok
	_invite_btn.disabled = not (on and mp.is_host and mp.over_steam)
	_host_btn.disabled = on
	_join_btn.disabled = on
	_leave_btn.visible = on
	_leave_btn.disabled = not on
	_resync_btn.visible = on and mp.in_world()
	_resync_btn.disabled = not (on and mp.in_world())
	_ip_edit.editable = not on
	if on and mp.is_host and not mp.in_world():
		unlock_menu_play_buttons()

	if _show_ips:
		var ips := PackedStringArray()
		for a in IP.get_local_addresses():
			if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
				ips.append(a)
		_ips_label.text = ", ".join(ips) if not ips.is_empty() else "-"
		_ips_btn.text = mp.t("hide_ips")
	else:
		_ips_label.text = ""
		_ips_btn.text = mp.t("show_ips")

	_roster_on = on and mp.players.size() > 0
	if _roster_on:
		var rl := PackedStringArray()
		for id in mp.players:
			var p: Dictionary = mp.players[id]
			rl.append("[right][color=#%s]●[/color] %s[/right]" % [(p["color"] as Color).to_html(false), _esc(str(p["name"]))])
		_roster.text = "\n".join(rl)
	else:
		_roster.text = ""
	_update_wait()

func hook_menu(menu: Node) -> void:
	for i in 120:
		var b := _find_mp_button(menu)
		if b != null:
			_wire_mp_button(b)
			if mp.active() and mp.is_host:
				unlock_menu_play_buttons()
			_maybe_auto_open()
			return
		await get_tree().process_frame
		if not is_instance_valid(menu):
			return
	var created := _inject_mp_button(menu)
	if created == null:
		push_warning("[MPMod] could not find or create the MULTIPLAYER button")
	if mp.active() and mp.is_host:
		unlock_menu_play_buttons()
	_maybe_auto_open()

func _wire_mp_button(b: Button) -> void:
	for c in b.pressed.get_connections():
		b.pressed.disconnect(c["callable"])
	b.pressed.connect(func() -> void:
		Audio.play("ui_open")
		open_panel())
	b.visible = true
	b.disabled = false
	if str(b.text).strip_edges() == "":
		b.text = mp.t("title")

func _inject_mp_button(menu: Node) -> Button:
	if menu == null:
		return null
	var ref := _find_button_by_keys(menu, [
		"NEW_GAME", "NEW GAME", "NEUES SPIEL", "PLAY", "START", "CONTINUE", "FORTSETZEN", "LOAD_GAME", "LADEN",
	])
	var parent: Node = ref.get_parent() if ref != null else null
	if parent == null:
		parent = _find_menu_button_parent(menu)
	if parent == null:
		return null
	var b := Button.new()
	b.name = "MPModButton"
	b.text = mp.t("title")
	b.focus_mode = Control.FOCUS_NONE
	if ref != null:
		b.custom_minimum_size = ref.custom_minimum_size
		b.size_flags_horizontal = ref.size_flags_horizontal
		b.size_flags_vertical = ref.size_flags_vertical
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			var sb := ref.get_theme_stylebox(st)
			if sb != null:
				b.add_theme_stylebox_override(st, sb)
		var f := ref.get_theme_font("font")
		if f != null:
			b.add_theme_font_override("font", f)
		var fs := ref.get_theme_font_size("font_size")
		if fs > 0:
			b.add_theme_font_size_override("font_size", fs)
	parent.add_child(b)
	if ref != null:
		parent.move_child(b, mini(ref.get_index() + 1, parent.get_child_count() - 1))
	_wire_mp_button(b)
	return b

func _find_menu_button_parent(menu: Node) -> Node:
	var stack: Array[Node] = [menu]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var buttons := 0
		for c in n.get_children():
			if c is Button and (c as Button).visible:
				buttons += 1
		if buttons >= 2:
			return n
		stack.append_array(n.get_children())
	return null

func _maybe_auto_open() -> void:
	_auto_open_done = true
	var flag: String = str(mp.mp_data_root().path_join("auto_open"))
	if FileAccess.file_exists(flag):
		DirAccess.remove_absolute(flag)

func _find_mp_button(n: Node) -> Button:
	var want: Array[String] = []
	for t in [n.tr("MULTIPLAYER"), "MULTIPLAYER", "MEHRSPIELER", "Mehrspieler", mp.t("title")]:
		var s := str(t).strip_edges()
		if s != "":
			want.append(s.to_lower())
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is Button:
			var label := (c as Button).text.strip_edges().to_lower()
			if label in want:
				return c
			if "multiplayer" in label or "mehrspieler" in label:
				return c
		stack.append_array(c.get_children())
	return null
