# client_and_studio/scenes/ui/leaderboard_overlay.gd
extends CanvasLayer

## In-Game Player Leaderboard Overlay (Toggled via TAB Key)

@onready var leaderboard_panel: PanelContainer = %LeaderboardPanel
@onready var player_list_vbox: VBoxContainer = %PlayerListVBox

const VERIFIED_ICON_PATH := "res://assets/verified_badge.png"

func _ready() -> void:
	leaderboard_panel.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB:
		if event.is_pressed() and not event.is_echo():
			_refresh_player_list()
			leaderboard_panel.show()
		elif not event.is_pressed():
			leaderboard_panel.hide()

func _refresh_player_list() -> void:
	for child in player_list_vbox.get_children():
		child.queue_free()

	var players_container := get_node_or_null("/root/GameWorld/Players")
	if not players_container:
		players_container = get_node_or_null("/root/Main/Players")

	var active_nodes: Array = players_container.get_children() if players_container else []
	if active_nodes.is_empty():
		_add_player_row("Player (Local Host)", "15 ms", true, false, {})
		return

	for node in active_nodes:
		var uname: String = node.name
		var is_owner: bool = false
		var is_verified: bool = false
		var colors: Dictionary = {}

		if node.has_method("get") and node.get("player_username") != null:
			uname = str(node.get("player_username"))
		if node.has_method("get") and node.get("avatar_colors") != null:
			colors = node.get("avatar_colors")

		var net_mgr := get_node_or_null("/root/NetworkManager")
		if net_mgr and node.name == str(multiplayer.get_unique_id()):
			is_owner = net_mgr.is_owner
			is_verified = net_mgr.is_verified
			if colors.is_empty():
				colors = net_mgr.local_avatar_colors

		_add_player_row(uname, "12 ms", is_owner, is_verified, colors)

func _add_player_row(uname: String, ping_str: String, is_owner: bool, is_verified: bool, colors: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 36)

	# Avatar Color Square Indicator
	var color_rect := ColorRect.new()
	color_rect.custom_minimum_size = Vector2(24, 24)
	var torso_color := Color.html(str(colors.get("torso", "#6366f1"))) if not colors.is_empty() else Color(0.39, 0.4, 0.95)
	color_rect.color = torso_color
	row.add_child(color_rect)

	# Crown icon for owner
	if is_owner:
		var crown_label := Label.new()
		crown_label.text = "👑"
		row.add_child(crown_label)

	# Verified Checkmark Icon
	if is_verified:
		if ResourceLoader.exists(VERIFIED_ICON_PATH):
			var tex_rect := TextureRect.new()
			tex_rect.texture = load(VERIFIED_ICON_PATH)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.custom_minimum_size = Vector2(20, 20)
			row.add_child(tex_rect)
		else:
			var check_label := Label.new()
			check_label.text = "☑️"
			row.add_child(check_label)

	# Player Username
	var name_label := Label.new()
	name_label.text = uname
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	# Ping
	var ping_label := Label.new()
	ping_label.text = ping_str
	ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(ping_label)

	player_list_vbox.add_child(row)
