# client_and_studio/scenes/ui/leaderboard_overlay.gd
extends CanvasLayer

## In-Game Player Leaderboard Overlay (Toggled via TAB Key)

@onready var leaderboard_panel: PanelContainer = %LeaderboardPanel
@onready var player_list_vbox: VBoxContainer = %PlayerListVBox

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
		_add_player_row("Player (Local Host)", "15 ms", true, false)
		return

	for node in active_nodes:
		var uname: String = node.name
		var is_owner: bool = false
		var is_verified: bool = false

		if node.has_method("get") and node.get("player_username") != null:
			uname = str(node.get("player_username"))

		var net_mgr := get_node_or_null("/root/NetworkManager")
		if net_mgr and node.name == str(multiplayer.get_unique_id()):
			is_owner = net_mgr.is_owner
			is_verified = net_mgr.is_verified

		_add_player_row(uname, "12 ms", is_owner, is_verified)

func _add_player_row(uname: String, ping_str: String, is_owner: bool, is_verified: bool) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 32)

	var name_label := Label.new()
	var badge_prefix := ""
	if is_owner: badge_prefix += "👑 "
	if is_verified: badge_prefix += "☑️ "
	name_label.text = badge_prefix + uname
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var ping_label := Label.new()
	ping_label.text = ping_str
	ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	row.add_child(name_label)
	row.add_child(ping_label)
	player_list_vbox.add_child(row)
