extends Control
## Desktop-first Studio: familiar ribbon/workspace/docks, original Luani chrome.
const Data = preload("res://scripts/studio_data.gd")
const Document = preload("res://scripts/studio_document.gd")
const ViewportPanel = preload("res://scripts/studio_viewport.gd")
const Cloud = preload("res://scripts/studio_cloud.gd")
const UI = preload("res://scripts/ui_theme.gd")
var initial: Dictionary = {}
var document: Document = Document.new()
var cloud: Cloud
var view: ViewportPanel
var explorer: Tree
var properties: VBoxContainer
var status: Label
var title_label: Label
var identity_button: Button
var game_id: String = ""
var revision: int = 0
var meta_revision: int = 0
var game_title: String = "Untitled game"
var description: String = ""
var visibility: String = "closed"
var _busy: bool = false
var _refreshing: bool = false
var _editing_property: bool = false
var _file_serial: int = -1
var _cloud_serial: int = -1
var _file_path: String = ""
var _metadata_dirty: bool = false
var _agreed: bool = false
var _mode_buttons: Dictionary = {}

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_window().title = "Luani Studio"
	get_window().min_size = Vector2i(1100,700)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.make_theme()
	theme.default_font = UI.font(500)
	theme.default_font_size = 13
	for state: String in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new(); style.bg_color = Color("2b2e35") if state != "hover" else Color("3c424e"); style.border_color = Color("444a57"); style.set_border_width_all(1); style.set_corner_radius_all(3)
		style.content_margin_left = 10; style.content_margin_right = 10; style.content_margin_top = 6; style.content_margin_bottom = 6
		theme.set_stylebox(state,"Button",style)
	cloud = Cloud.new(); add_child(cloud)
	var background := ColorRect.new(); background.color = Color("202226"); background.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(background); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := VBoxContainer.new(); layout.add_theme_constant_override("separation",0); add_child(layout); layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := HBoxContainer.new(); top.custom_minimum_size.y = 36; layout.add_child(top)
	top.add_child(_label("  ◉  luani studio",15))
	title_label = _label(game_title,13); title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(title_label)
	identity_button = _button("Sign in",_sign_in); top.add_child(identity_button)
	var menu := HBoxContainer.new(); menu.custom_minimum_size.y = 30; layout.add_child(menu)
	for entry: Array in [["New",_new_game],["Open file",_open_file],["Save file",_save_file],["Open game",_open_game],["Save to cloud",_save_cloud],["Publish to cloud",_publish],["Game settings",_settings],["Exit",_exit]]:
		menu.add_child(_button(str(entry[0]),entry[1]))
	var ribbon := HBoxContainer.new(); ribbon.add_theme_constant_override("separation",4); ribbon.custom_minimum_size.y = 64; layout.add_child(ribbon)
	for kind: String in ["select","move","rotate","scale"]:
		var button: Button = _button(kind.capitalize(),func() -> void: _set_mode(kind)); button.toggle_mode = true; _mode_buttons[kind] = button; ribbon.add_child(button)
	ribbon.add_child(VSeparator.new())
	var insert := OptionButton.new(); insert.add_item("Insert object…")
	for kind: String in Data.registry().classes: insert.add_item(kind)
	insert.item_selected.connect(func(index: int) -> void:
		if index > 0: _show_error(document.insert(insert.get_item_text(index)))
		insert.select(0))
	ribbon.add_child(insert)
	ribbon.add_child(_button("Duplicate",func() -> void: _show_error(document.duplicate_selected())))
	ribbon.add_child(_button("Delete",func() -> void: document.remove_selected()))
	ribbon.add_child(_button("Undo",func() -> void: document.undo()))
	ribbon.add_child(_button("Redo",func() -> void: document.redo()))
	var snap_box := CheckButton.new(); snap_box.text = "Snap"; snap_box.button_pressed = true; snap_box.toggled.connect(func(value: bool) -> void: view.snap = value); ribbon.add_child(snap_box)
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ribbon.add_child(spacer)
	var play: Button = _button("▶  Playtest",_playtest); play.modulate = Color("a2e5c5"); ribbon.add_child(play)
	var workspace := HSplitContainer.new(); workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL; workspace.split_offset = 920; layout.add_child(workspace)
	var center := VBoxContainer.new(); center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; center.add_theme_constant_override("separation",0); workspace.add_child(center)
	center.add_child(_label("  Viewport  ·  Right mouse: orbit  ·  Middle mouse: pan  ·  F: frame",12))
	view = ViewportPanel.new(); view.size_flags_vertical = Control.SIZE_EXPAND_FILL; view.custom_minimum_size = Vector2(480,300); center.add_child(view)
	view.selected.connect(document.select); view.transformed.connect(func(id: String,key: String,value: Array) -> void: _edit(id,key,value,false))
	var docks := VSplitContainer.new(); docks.custom_minimum_size.x = 360; docks.split_offset = 290; workspace.add_child(docks)
	var explorer_box := VBoxContainer.new(); docks.add_child(explorer_box); explorer_box.add_child(_label("  Explorer",14))
	explorer = Tree.new(); explorer.hide_root = false; explorer.size_flags_vertical = Control.SIZE_EXPAND_FILL; explorer.item_selected.connect(_tree_selected); explorer_box.add_child(explorer)
	var inspector := VBoxContainer.new(); docks.add_child(inspector); inspector.add_child(_label("  Properties",14))
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; inspector.add_child(scroll)
	properties = VBoxContainer.new(); properties.size_flags_horizontal = Control.SIZE_EXPAND_FILL; properties.add_theme_constant_override("separation",7); scroll.add_child(properties)
	status = _label("Ready · Local file and cloud publication are separate.",12); status.custom_minimum_size.y = 26; layout.add_child(status)
	document.changed.connect(_refresh); document.selection_changed.connect(_selection)
	if initial.get("world") is Dictionary and Data.validate(initial.world).is_empty():
		document.replace(initial.world); game_id = str(initial.get("game_id","") if initial.get("game_id") != null else ""); revision = int(initial.get("revision",0)); _cloud_serial = document.serial
		if initial.get("game") is Dictionary:
			game_title = str(initial.game.get("title","Untitled game")); description = str(initial.game.get("description","")); visibility = str(initial.game.get("visibility","closed")); meta_revision = int(initial.game.get("meta_revision",0))
	_refresh(); _set_mode("select")

func _label(text: String, size: int = 13) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size",size); return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new(); button.text = text; button.pressed.connect(action); button.add_theme_font_size_override("font_size",12); return button

func _show_error(message: String) -> void:
	if not message.is_empty(): status.text = message

func _dirty() -> bool:
	return _metadata_dirty or document.serial != _file_serial and document.serial != _cloud_serial

func _guard(action: Callable) -> void:
	if _busy: return
	if not _dirty(): action.call(); return
	var dialog := ConfirmationDialog.new(); dialog.title = "Unsaved changes"; dialog.dialog_text = "Continue without saving your current changes?"; dialog.ok_button_text = "Continue"; add_child(dialog)
	dialog.confirmed.connect(func() -> void: dialog.queue_free(); action.call()); dialog.canceled.connect(dialog.queue_free); dialog.popup_centered()

func _new_game() -> void:
	_guard(func() -> void: game_id = ""; revision = 0; meta_revision = 0; game_title = "Untitled game"; description = ""; visibility = "closed"; _file_path = ""; _metadata_dirty = false; document.replace(Data.new_world()))

func _refresh() -> void:
	if view == null: return
	_refreshing = true
	view.set_document(document.world,document.selected)
	explorer.clear(); var root: TreeItem = explorer.create_item(); root.set_text(0,"World"); root.set_metadata(0,"")
	var items: Dictionary = {}
	for item: Dictionary in document.world.objects: _tree_item(item,root,items)
	_refreshing = false
	if not _editing_property: _selection()
	title_label.text = "  " + game_title + ("  •" if _dirty() else "")
	status.text = "Local changes · %d objects · Cloud revision %d" % [document.world.objects.size(),revision]

func _tree_item(item: Dictionary, root: TreeItem, items: Dictionary) -> TreeItem:
	if items.has(item.id): return items[item.id]
	var parent: TreeItem = root if item.parent == null else _tree_item(Data.by_id(document.world,str(item.parent)),root,items)
	var entry: TreeItem = explorer.create_item(parent); entry.set_text(0,str(item.name)); entry.set_tooltip_text(0,str(item["class"])); entry.set_metadata(0,str(item.id)); items[item.id] = entry
	if item.id == document.selected: entry.select(0)
	return entry

func _tree_selected() -> void:
	if _refreshing: return
	var item: TreeItem = explorer.get_selected()
	if item != null: document.select(str(item.get_metadata(0)))

func _selection() -> void:
	view.set_selection(document.selected)
	_refreshing = true
	var tree_selection: TreeItem = _find_tree(explorer.get_root(),document.selected)
	if tree_selection != null: tree_selection.select(0)
	_refreshing = false
	for child: Node in properties.get_children(): properties.remove_child(child); child.queue_free()
	var item: Dictionary = Data.by_id(document.world,document.selected)
	if item.is_empty(): properties.add_child(_label("Select an object in Explorer or the viewport.",12)); return
	properties.add_child(_label(str(item["class"]),14))
	var name_field := LineEdit.new(); name_field.text = str(item.name); name_field.max_length = 80; name_field.placeholder_text = "Name"; name_field.tooltip_text = "Instance name"; properties.add_child(name_field)
	name_field.text_submitted.connect(func(value: String) -> void: _show_error(document.edit(str(item.id),"name",value,false)))
	name_field.text_changed.connect(func(value: String) -> void: _edit(str(item.id),"name",value,true,false))
	var parent_field := OptionButton.new(); parent_field.add_item("World"); parent_field.set_item_metadata(0,null)
	for candidate: Dictionary in document.world.objects:
		if candidate.id != item.id and candidate["class"] in ["Model","Folder"]: parent_field.add_item(str(candidate.name)); parent_field.set_item_metadata(parent_field.item_count-1,candidate.id)
	for index: int in range(parent_field.item_count):
		if parent_field.get_item_metadata(index) == item.parent: parent_field.select(index)
	parent_field.item_selected.connect(func(index: int) -> void: _show_error(document.edit(str(item.id),"parent",parent_field.get_item_metadata(index),false)))
	properties.add_child(_label("Parent",12)); properties.add_child(parent_field)
	var definitions: Dictionary = Data.registry().classes[item["class"]]
	for key: String in definitions: _property(item,key,definitions[key])

func _find_tree(item: TreeItem, id: String) -> TreeItem:
	if item == null: return null
	if str(item.get_metadata(0)) == id: return item
	var child: TreeItem = item.get_first_child()
	while child != null:
		var found: TreeItem = _find_tree(child,id)
		if found != null: return found
		child = child.get_next()
	return null

func _property(item: Dictionary, key: String, spec: Array) -> void:
	properties.add_child(_label(key.capitalize(),12))
	var value: Variant = item.properties[key]
	match str(spec[0]):
		"vector":
			var row := HBoxContainer.new(); properties.add_child(row)
			for axis: int in range(3):
				var field := SpinBox.new(); field.min_value = float(spec[1]); field.max_value = float(spec[2]); field.step = 0.001; field.value = float(value[axis]); field.size_flags_horizontal = Control.SIZE_EXPAND_FILL; field.custom_minimum_size.x = 80; field.tooltip_text = key + " " + ["X","Y","Z"][axis]; row.add_child(field)
				field.value_changed.connect(func(n: float) -> void: var values: Array = Data.by_id(document.world,str(item.id)).properties[key].duplicate(); values[axis] = n; _edit(str(item.id),key,values))
		"number":
			var field := SpinBox.new(); field.min_value = float(spec[1]); field.max_value = float(spec[2]); field.step = 0.01; field.value = float(value); properties.add_child(field); field.value_changed.connect(func(n: float) -> void: _edit(str(item.id),key,n))
		"boolean":
			var field := CheckButton.new(); field.text = "Enabled"; field.button_pressed = bool(value); properties.add_child(field); field.toggled.connect(func(enabled: bool) -> void: _edit(str(item.id),key,enabled))
		"color":
			var field := ColorPickerButton.new(); field.color = Color(str(value)); field.edit_alpha = false; field.custom_minimum_size.y = 28; properties.add_child(field); field.color_changed.connect(func(color: Color) -> void: _edit(str(item.id),key,color.to_html(false)))
		"enum", "reference":
			var field := OptionButton.new(); properties.add_child(field)
			if spec[0] == "reference":
				field.add_item("None"); field.set_item_metadata(0,null)
				for candidate: Dictionary in document.world.objects:
					if candidate["class"] in ["Part","SpawnPoint"]: field.add_item(str(candidate.name)); field.set_item_metadata(field.item_count-1,candidate.id)
			else:
				for option: String in spec[1]: field.add_item(option); field.set_item_metadata(field.item_count-1,option)
			for index: int in range(field.item_count):
				if field.get_item_metadata(index) == value: field.select(index)
			field.item_selected.connect(func(index: int) -> void: _edit(str(item.id),key,field.get_item_metadata(index)))

func _edit(id: String, key: String, value: Variant, keep_inspector: bool = true, property: bool = true) -> void:
	_editing_property = keep_inspector
	var error: String = document.edit(id,key,value,property)
	_editing_property = false
	if not error.is_empty(): status.text = error; view.set_document(document.world,document.selected)

func _set_mode(mode: String) -> void:
	view.set_mode(mode)
	for key: String in _mode_buttons: (_mode_buttons[key] as Button).set_pressed_no_signal(key == mode)

func _file_dialog(save: bool) -> void:
	var dialog := FileDialog.new(); dialog.title = "Save Luani world" if save else "Open Luani world"; dialog.access = FileDialog.ACCESS_FILESYSTEM; dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if save else FileDialog.FILE_MODE_OPEN_FILE; dialog.filters = PackedStringArray(["*.luani.json ; Luani Studio world","*.json ; JSON world"])
	if save: dialog.current_file = "world.luani.json"
	add_child(dialog); dialog.file_selected.connect(func(path: String) -> void: dialog.queue_free(); _write_file(path) if save else _read_file(path)); dialog.canceled.connect(dialog.queue_free); dialog.popup_centered_ratio(0.7)

func _open_file() -> void: _guard(func() -> void: _file_dialog(false))
func _save_file() -> void:
	if not _busy: _file_dialog(true)

func _write_file(path: String) -> void:
	var value: Dictionary = {"format":"luani-studio","version":1,"title":game_title,"description":description,"visibility":visibility,"world":document.world}
	var temporary: String = path + ".write-" + document.identifier()
	var file: FileAccess = FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: status.text = "Could not save this file"; return
	file.store_string(JSON.stringify(value,"\t")); file.flush(); file.close()
	if DirAccess.rename_absolute(temporary,path) != OK: DirAccess.remove_absolute(temporary); status.text = "Could not replace this file; existing contents were preserved"; return
	_file_path = path; _file_serial = document.serial; _metadata_dirty = false; title_label.text = "  " + game_title; status.text = "Saved locally. Cloud publication was not changed."

func _read_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path,FileAccess.READ)
	if file == null: status.text = "Could not open this file"; return
	if file.get_length() > 280000: file.close(); status.text = "World file is too large"; return
	var value: Variant = JSON.parse_string(file.get_as_text()); file.close()
	if not value is Dictionary or value.get("format") != "luani-studio" or value.get("version") != 1 or not value.get("title") is String or str(value.title).strip_edges().is_empty() or str(value.title).length() > 100 or not value.get("description","") is String or str(value.get("description","")).length() > 2000 or not value.get("visibility","closed") in ["closed","friends","public"]: status.text = "Invalid Luani Studio file"; return
	var error: String = Data.validate(value.get("world"))
	if not error.is_empty(): status.text = error; return
	game_id = ""; revision = 0; meta_revision = 0; game_title = value.title; description = value.get("description",""); visibility = value.get("visibility","closed"); _file_path = path; _metadata_dirty = false
	document.replace(value.world); _file_serial = document.serial; _cloud_serial = -1; _refresh(); status.text = "Opened local world. Save to cloud creates a new game."

func _sign_in() -> void:
	if _busy: return
	if not cloud.access_token.is_empty():
		_guard(func() -> void: cloud.sign_out(); identity_button.text = "Sign in"; game_id = ""; revision = 0; meta_revision = 0; _cloud_serial = -1; game_title = "Untitled game"; description = ""; visibility = "closed"; _metadata_dirty = false; document.replace(Data.new_world()))
		return
	var dialog := AcceptDialog.new(); dialog.title = "Sign in to Luani Studio"; dialog.ok_button_text = "Sign in"; dialog.min_size = Vector2i(400,220); add_child(dialog)
	var box := VBoxContainer.new(); dialog.add_child(box)
	box.add_child(_label("Use your existing Luani account. Credentials are not saved.",12))
	var identifier := LineEdit.new(); identifier.placeholder_text = "Username or email"; identifier.max_length = 254; box.add_child(identifier)
	var password := LineEdit.new(); password.placeholder_text = "Password"; password.secret = true; password.max_length = 512; box.add_child(password)
	dialog.confirmed.connect(func() -> void:
		var who: String = identifier.text; var secret: String = password.text; password.text = ""; dialog.queue_free(); _busy = true; status.text = "Signing in…"
		var success: bool = await cloud.sign_in(who,secret); secret = ""; _busy = false
		identity_button.text = "Sign out" if success else "Sign in"; status.text = "Connected to Luani cloud" if success else cloud.last_error)
	dialog.canceled.connect(func() -> void: password.text = ""; dialog.queue_free()); dialog.popup_centered()

func _connected() -> bool:
	if _busy: return false
	if cloud.access_token.is_empty(): status.text = "Sign in, then choose this action again"; _sign_in(); return false
	return true

func _save_cloud() -> void:
	if not _connected(): return
	if not _agreement(_save_cloud): return
	var snapshot: Dictionary = document.world.duplicate(true); var serial: int = document.serial
	_busy = true; status.text = "Saving draft to cloud…"
	var creating: bool = game_id.is_empty()
	var values: Dictionary = {"title":game_title,"world":snapshot} if creating else {"game_id":game_id,"revision":revision,"world":snapshot}
	var result: Dictionary = await cloud.operation("create" if creating else "save",values)
	if not result.is_empty():
		var saved: Dictionary = result.value
		game_id = str(saved.id); revision = int(saved.revision); meta_revision = int(saved.meta_revision)
		if creating and (not description.is_empty() or visibility != "closed"):
			var settings_result: Dictionary = await cloud.operation("settings",{"game_id":game_id,"meta_revision":meta_revision,"title":game_title,"description":description,"visibility":visibility})
			if not settings_result.is_empty(): meta_revision = int(settings_result.value.meta_revision); _metadata_dirty = false
		var readback: Dictionary = await cloud.operation("get",{"game_id":game_id})
		if not readback.is_empty() and Data.equivalent(readback.value.world,snapshot) and int(readback.value.revision) == revision:
			_cloud_serial = serial; meta_revision = int(readback.value.meta_revision)
			_metadata_dirty = readback.value.title != game_title or readback.value.description != description or readback.value.visibility != visibility
			status.text = "World saved, but game settings differ. Reopen Game settings before publishing." if _metadata_dirty else "Cloud draft saved and verified · revision %d. Publication unchanged." % revision
		else: status.text = "Cloud write returned, but readback was not verified. Reopen the cloud game before retrying."
	else: status.text = cloud.last_error
	_busy = false

func _open_game() -> void:
	if not _connected(): return
	_guard(_choose_game)

func _choose_game() -> void:
	_busy = true; var result: Dictionary = await cloud.operation("list"); _busy = false
	if result.is_empty(): status.text = cloud.last_error; return
	var games: Array = result.value
	var dialog := AcceptDialog.new(); dialog.title = "Open cloud game"; dialog.ok_button_text = "Open"; dialog.min_size = Vector2i(420,180); add_child(dialog)
	var choice := OptionButton.new(); dialog.add_child(choice)
	for game: Dictionary in games: choice.add_item(str(game.title)); choice.set_item_metadata(choice.item_count-1,game.id)
	if games.is_empty(): choice.add_item("No games yet — save a new world to cloud"); dialog.get_ok_button().disabled = true
	dialog.confirmed.connect(func() -> void: var id: String = str(choice.get_item_metadata(choice.selected)); dialog.queue_free(); _load_game(id)); dialog.canceled.connect(dialog.queue_free); dialog.popup_centered()

func _load_game(id: String) -> void:
	_busy = true; var result: Dictionary = await cloud.operation("get",{"game_id":id}); _busy = false
	if result.is_empty(): status.text = cloud.last_error; return
	var value: Dictionary = result.value
	var error: String = Data.validate(value.get("world"))
	if not error.is_empty(): status.text = error; return
	game_id = str(value.id); revision = int(value.revision); meta_revision = int(value.meta_revision); game_title = str(value.title); description = str(value.description); visibility = str(value.visibility); _metadata_dirty = false
	document.replace(value.world); _cloud_serial = document.serial; _file_serial = -1; _refresh(); status.text = "Opened cloud draft revision %d" % revision

func _settings() -> void:
	if _busy: return
	var dialog := AcceptDialog.new(); dialog.title = "Game settings"; dialog.ok_button_text = "Save settings"; dialog.min_size = Vector2i(460,320); add_child(dialog)
	var box := VBoxContainer.new(); dialog.add_child(box)
	box.add_child(_label("Name",12)); var name_field := LineEdit.new(); name_field.max_length = 100; name_field.text = game_title; box.add_child(name_field)
	box.add_child(_label("Description",12)); var text := TextEdit.new(); text.text = description; text.custom_minimum_size.y = 120; box.add_child(text)
	box.add_child(_label("Who can join after publication?",12)); var access := OptionButton.new(); box.add_child(access)
	for label: String in ["Closed — owner only","Friends only","Public"]: access.add_item(label)
	access.select(["closed","friends","public"].find(visibility))
	dialog.confirmed.connect(func() -> void:
		var next_title: String = name_field.text.strip_edges(); var next_description: String = text.text; var next_visibility: String = ["closed","friends","public"][access.selected]; dialog.queue_free()
		if next_title.is_empty() or next_description.length() > 2000: status.text = "Use a name and a description no longer than 2000 characters"; return
		_save_settings(next_title,next_description,next_visibility))
	dialog.canceled.connect(dialog.queue_free); dialog.popup_centered()

func _save_settings(next_title: String, next_description: String, next_visibility: String) -> void:
	if game_id.is_empty(): game_title = next_title; description = next_description; visibility = next_visibility; _metadata_dirty = true; _refresh(); return
	if not _connected(): return
	if not _agreement(func() -> void: _save_settings(next_title,next_description,next_visibility)): return
	_busy = true
	var result: Dictionary = await cloud.operation("settings",{"game_id":game_id,"meta_revision":meta_revision,"title":next_title,"description":next_description,"visibility":next_visibility})
	if not result.is_empty():
		var readback: Dictionary = await cloud.operation("get",{"game_id":game_id})
		if not readback.is_empty():
			var matches: bool = readback.value.title == next_title and readback.value.description == next_description and readback.value.visibility == next_visibility
			meta_revision = int(readback.value.meta_revision); game_title = str(readback.value.title); description = str(readback.value.description); visibility = str(readback.value.visibility); _metadata_dirty = false; _refresh()
			status.text = "Cloud game settings saved and verified" if matches else "Server settings differ; the current server values have been loaded."
		else: status.text = "Game settings readback could not be verified: " + cloud.last_error
	else: status.text = cloud.last_error
	_busy = false

func _publish() -> void:
	if not _connected(): return
	if not _agreement(_publish): return
	if game_id.is_empty() or document.serial != _cloud_serial or _metadata_dirty: status.text = "Save your current world and game settings to cloud before publishing"; return
	var dialog := ConfirmationDialog.new(); dialog.title = "Publish cloud revision"; dialog.dialog_text = "Publish revision %d? Access: %s.\nNew servers use this revision; existing servers keep theirs." % [revision,visibility]; dialog.ok_button_text = "Publish"; add_child(dialog)
	dialog.confirmed.connect(func() -> void: dialog.queue_free(); _publish_revision()); dialog.canceled.connect(dialog.queue_free); dialog.popup_centered()

func _publish_revision() -> void:
	_busy = true; var result: Dictionary = await cloud.operation("publish",{"game_id":game_id,"revision":revision})
	if not result.is_empty():
		var readback: Dictionary = await cloud.operation("get",{"game_id":game_id})
		if not readback.is_empty() and int(readback.value.published_revision) == revision: meta_revision = int(readback.value.meta_revision); status.text = "Published revision %d · %s. Hosting is subject to server availability." % [revision,visibility]
		else: status.text = "Publication readback could not be verified"
	else: status.text = cloud.last_error
	_busy = false

func _playtest() -> void:
	if not _connected(): return
	if not _agreement(_playtest): return
	var values: Dictionary = {"world":document.world.duplicate(true)}
	if not game_id.is_empty(): values.game_id = game_id
	_busy = true; status.text = "Preparing a ticketed local playtest…"
	var result: Dictionary = await cloud.operation("playtest",values); _busy = false
	if result.is_empty(): status.text = cloud.last_error; return
	var uri: String = str(result.value.get("launch_url","")); var pattern := RegEx.new(); pattern.compile("^luani://launch\\?ticket=[A-Za-z0-9_-]{43}&studio=play&studio_ticket=[A-Za-z0-9_-]{43}$")
	if pattern.search(uri) == null: status.text = "Invalid Studio launch response"; return
	if OS.shell_open(uri) != OK: status.text = "Could not open Luani Client. Install the Studio-enabled client update."
	else: status.text = "Opening Luani Client with a local server. Your cloud draft/publication was not changed."

func _agreement(action: Callable) -> bool:
	if _agreed: return true
	var dialog := AcceptDialog.new(); dialog.title = "Studio community terms"; dialog.ok_button_text = "Continue"; dialog.min_size = Vector2i(440,200); add_child(dialog)
	var box := VBoxContainer.new(); dialog.add_child(box)
	box.add_child(_button("Read Terms of Use",func() -> void: OS.shell_open("https://new.luani.fyi/terms.html")))
	box.add_child(_button("Read Privacy Policy",func() -> void: OS.shell_open("https://new.luani.fyi/privacy.html")))
	var agree := CheckBox.new(); agree.text = "I agree to the Terms and have read the Privacy Policy"; box.add_child(agree)
	dialog.get_ok_button().disabled = true; agree.toggled.connect(func(value: bool) -> void: dialog.get_ok_button().disabled = not value)
	dialog.confirmed.connect(func() -> void: _agreed = true; dialog.queue_free(); action.call_deferred()); dialog.canceled.connect(dialog.queue_free); dialog.popup_centered()
	return false

func _exit() -> void: _guard(func() -> void: get_tree().quit())
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _exit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.ctrl_pressed and event.physical_keycode == KEY_S: _save_file(); get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.physical_keycode == KEY_Z: document.redo() if event.shift_pressed else document.undo(); get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.physical_keycode == KEY_D: _show_error(document.duplicate_selected()); get_viewport().set_input_as_handled()
	elif get_viewport().gui_get_focus_owner() == view:
		if event.physical_keycode == KEY_DELETE: document.remove_selected()
		elif event.physical_keycode in [KEY_Q,KEY_W,KEY_E,KEY_R]: _set_mode({KEY_Q:"select",KEY_W:"move",KEY_E:"rotate",KEY_R:"scale"}[event.physical_keycode])
