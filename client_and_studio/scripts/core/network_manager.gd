# client_and_studio/scripts/core/network_manager.gd
extends Node

## Manages ENet multiplayer server hosting, client joins, DNS resolution, and player avatar synchronization

signal server_started(port: int)
signal client_connected_to_server(server_ip: String, server_port: int)
signal connection_failed(reason: String)
signal player_spawned(peer_id: int, avatar_node: Node)

const PLAYER_AVATAR_SCENE := preload("res://scenes/player/player_avatar.tscn")
const LOADING_OVERLAY_SCENE := preload("res://scenes/ui/loading_overlay.tscn")

var active_peer: ENetMultiplayerPeer = null
var is_server: bool = false
var players_container: Node = null

var local_username: String = "Player"
var local_avatar: String = ""
var local_avatar_colors: Dictionary = {}
var is_owner: bool = false
var is_verified: bool = false

var loading_overlay_node: CanvasLayer = null
var target_server_ip: String = "127.0.0.1"
var target_server_port: int = 7777
var connection_timer_active: bool = false
var connection_elapsed: float = 0.0
const CONNECTION_TIMEOUT_SECONDS: float = 12.0

## Empty-server auto-quit guard (server only)
var empty_server_elapsed: float = 0.0
var empty_server_timer_active: bool = false
const EMPTY_SERVER_QUIT_SECONDS: float = 300.0  # 5 minutes

var backend_status_url: String = "https://www.luani.fyi/api/daemon/update-status"
var server_request_id: String = ""

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	var parser := get_node_or_null("/root/ProtocolParser")
	if parser and parser.latest_session_data.get("valid", false):
		var data: Dictionary = parser.latest_session_data
		if data.get("username", "") != "":
			local_username = data.get("username")
		if data.has("avatar_colors") and data.get("avatar_colors") is Dictionary:
			local_avatar_colors = data.get("avatar_colors")
		is_owner = data.get("owner", false)
		is_verified = data.get("verified", false)

	# Read user_profile.json if username is default
	if local_username == "Player" and FileAccess.file_exists("user://user_profile.json"):
		var profile_file := FileAccess.open("user://user_profile.json", FileAccess.READ)
		if profile_file:
			var parsed = JSON.parse_string(profile_file.get_as_text())
			if parsed is Dictionary:
				if parsed.get("username", "") != "":
					local_username = parsed.get("username")
				if parsed.get("colors") is Dictionary:
					local_avatar_colors = parsed.get("colors")

	print("[Luani NetworkManager] Initialized identity: ", local_username, " (Owner: ", is_owner, ", Verified: ", is_verified, ")")

	# Extract --request-id= if passed via command line
	var all_args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in all_args:
		var clean := arg.strip_edges().trim_prefix("'").trim_suffix("'").trim_prefix("\"").trim_suffix("\"").strip_edges()
		if clean.begins_with("--request-id="):
			server_request_id = clean.trim_prefix("--request-id=")
		elif clean.begins_with("--request_id="):
			server_request_id = clean.trim_prefix("--request_id=")

	if server_request_id != "":
		print("[Luani NetworkManager] Dedicated server bound to request ID: ", server_request_id)

func _process(delta: float) -> void:
	if connection_timer_active:
		connection_elapsed += delta
		if connection_elapsed >= CONNECTION_TIMEOUT_SECONDS:
			connection_timer_active = false
			print("[Luani NetworkManager] 12-second connection handshake timeout reached.")
			_handle_connection_failure("[Connection Timeout] Could not reach server at " + target_server_ip + ":" + str(target_server_port) + ". Server failed to respond in time.")

	# Empty-server auto-quit guard: only shut down after 5 continuous minutes with 0 peers
	if is_server and empty_server_timer_active:
		empty_server_elapsed += delta
		if empty_server_elapsed >= EMPTY_SERVER_QUIT_SECONDS:
			print("[Luani NetworkManager] Server empty for 5 minutes. Shutting down gracefully.")
			get_tree().quit()

func _handle_connection_failure(reason_text: String) -> void:
	connection_timer_active = false
	if active_peer:
		active_peer.close()
		multiplayer.multiplayer_peer = null

	print("[Luani NetworkManager] Connection Error: ", reason_text)
	connection_failed.emit(reason_text)

	if loading_overlay_node and is_instance_valid(loading_overlay_node):
		if loading_overlay_node.has_method("show_error"):
			loading_overlay_node.call("show_error", reason_text)
	else:
		_show_fullscreen_error_overlay(reason_text)

func _show_fullscreen_error_overlay(reason_text: String) -> void:
	if loading_overlay_node and is_instance_valid(loading_overlay_node):
		loading_overlay_node.queue_free()

	loading_overlay_node = LOADING_OVERLAY_SCENE.instantiate() as CanvasLayer
	get_tree().root.add_child.call_deferred(loading_overlay_node)
	if loading_overlay_node.has_method("show_error"):
		loading_overlay_node.call_deferred("show_error", reason_text)

func setup_players_container(node: Node) -> void:
	players_container = node

func host_server(port: int = 7777, max_clients: int = 32) -> Error:
	active_peer = ENetMultiplayerPeer.new()
	var err := active_peer.create_server(port, max_clients)
	if err == OK:
		multiplayer.multiplayer_peer = active_peer
		is_server = true
		# Increase ENet timeout to tolerate mobile UDP packet drops (30s disconnect threshold)
		if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
			var enet_host = (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_host()
			if enet_host:
				enet_host.bandwidth_limit(0, 0)
				print("[Luani NetworkManager] ENet host bandwidth limits cleared for server.")
		print("[Luani NetworkManager] Server successfully started on port: ", port)
		server_started.emit(port)
		spawn_player_avatar(1)
	else:
		push_error("[Luani NetworkManager] Failed to create server on port " + str(port) + ". Error code: " + str(err))
	return err

func join_server(host: String = "127.0.0.1", port: int = 7777, _auth_token: String = "") -> Error:
	var connect_host := host.strip_edges()
	target_server_ip = connect_host
	target_server_port = port

	print("[NetworkManager] Connecting to host:", connect_host, "port:", port)

	if not connect_host.is_valid_ip_address():
		print("[Luani NetworkManager] Resolving hostname: ", connect_host)
		var resolved_ip := IP.resolve_hostname(connect_host, IP.TYPE_IPV4)
		if resolved_ip != "":
			print("[Luani NetworkManager] Resolved domain ", connect_host, " to IPv4: ", resolved_ip)
			connect_host = resolved_ip
		else:
			push_error("[Luani NetworkManager] Could not resolve hostname: " + connect_host)

	# Show Game Loading Overlay with 12s timeout
	if loading_overlay_node and is_instance_valid(loading_overlay_node):
		loading_overlay_node.queue_free()

	loading_overlay_node = LOADING_OVERLAY_SCENE.instantiate() as CanvasLayer
	get_tree().root.add_child.call_deferred(loading_overlay_node)

	connection_elapsed = 0.0
	connection_timer_active = true

	active_peer = ENetMultiplayerPeer.new()
	var err := active_peer.create_client(connect_host, port)
	if err == OK:
		multiplayer.multiplayer_peer = active_peer
		is_server = false
		# Increase ENet timeout to tolerate mobile UDP packet drops (30s disconnect threshold)
		if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
			var enet_host = (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_host()
			if enet_host:
				enet_host.bandwidth_limit(0, 0)
				print("[Luani NetworkManager] ENet host bandwidth limits cleared for client.")
		print("[Luani NetworkManager] Initiated client connection to ", connect_host, ":", port)
	else:
		_handle_connection_failure("Failed to create ENet client peer to " + connect_host + ":" + str(port))
	return err

func spawn_player_avatar(peer_id: int) -> Node:
	var target_container: Node = null
	
	var game_world := get_node_or_null("/root/GameWorld")
	if game_world:
		target_container = game_world.get_node_or_null("Players")
		if not target_container:
			target_container = game_world.get_node_or_null("%Players")

	if not target_container:
		var main_node := get_node_or_null("/root/Main")
		if main_node:
			target_container = main_node.get_node_or_null("Players")

	if not target_container:
		target_container = players_container if (players_container and is_instance_valid(players_container)) else null

	if not target_container:
		if is_server:
			target_container = get_node_or_null("/root/ServerPlayersContainer")
			if not target_container:
				var server_node := Node3D.new()
				server_node.name = "ServerPlayersContainer"
				get_tree().root.add_child.call_deferred(server_node)
				target_container = server_node
		else:
			return null

	# Avoid duplicate avatar spawning
	if target_container.has_node(str(peer_id)):
		return target_container.get_node(str(peer_id)) as Node

	var avatar := PLAYER_AVATAR_SCENE.instantiate() as CharacterBody3D
	avatar.name = str(peer_id)
	avatar.position = Vector3(randf_range(-2, 2), 2.0, randf_range(-2, 2))
	target_container.add_child.call_deferred(avatar)

	if avatar.has_method("set_player_username"):
		var uname: String = local_username if peer_id == multiplayer.get_unique_id() else "Player_" + str(peer_id)
		avatar.call_deferred("set_player_username", uname)

	var proto_mgr := get_node_or_null("/root/ProtocolParser")
	if proto_mgr and proto_mgr.latest_session_data.has("accessory_ids"):
		var accs: Array = proto_mgr.latest_session_data["accessory_ids"]
		if avatar.has_method("sync_equipped_accessories"):
			avatar.call_deferred("rpc", "sync_equipped_accessories", accs)

	var path_str: String = str(target_container.get_path()) if target_container.is_inside_tree() else target_container.name
	print("[Luani NetworkManager] Spawned PlayerAvatar for peer ID: ", peer_id, " under container: ", path_str)
	player_spawned.emit(peer_id, avatar)
	return avatar

func _report_player_count_to_backend() -> void:
	if not is_server or server_request_id == "":
		return
	
	var total_players: int = multiplayer.get_peers().size() + 1
	print("[Luani NetworkManager] Reporting player count (%d) to backend for req_id: %s" % [total_players, server_request_id])
	
	var http := HTTPRequest.new()
	add_child.call_deferred(http)
	
	http.request_completed.connect(func(_res: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray):
		http.queue_free()
	)
	
	var payload := JSON.stringify({
		"requestId": server_request_id,
		"status": "RUNNING",
		"playerCount": total_players
	})
	
	var headers := PackedStringArray(["Content-Type: application/json"])
	http.request(backend_status_url, headers, HTTPClient.METHOD_POST, payload)

func _on_peer_connected(id: int) -> void:
	print("[Luani NetworkManager] Peer connected: ", id)
	if is_server:
		# Cancel empty-server shutdown timer when a new peer joins
		empty_server_timer_active = false
		empty_server_elapsed = 0.0
		spawn_player_avatar(id)
		_report_player_count_to_backend()

func _on_peer_disconnected(id: int) -> void:
	print("[Luani NetworkManager] Peer disconnected: ", id)
	if players_container and players_container.has_node(str(id)):
		players_container.get_node(str(id)).queue_free()
	if is_server:
		_report_player_count_to_backend()
		# Guard: only start auto-quit timer when there are genuinely 0 remaining peers
		var remaining_peers: int = multiplayer.get_peers().size()
		if remaining_peers == 0:
			print("[Luani NetworkManager] Server has 0 peers. Starting 5-minute empty-server shutdown timer.")
			empty_server_elapsed = 0.0
			empty_server_timer_active = true
		else:
			# Reset timer — server is not empty
			empty_server_timer_active = false
			empty_server_elapsed = 0.0

func _on_connected_to_server() -> void:
	connection_timer_active = false
	var my_id := multiplayer.get_unique_id()
	print("[Luani NetworkManager] Successfully connected to server as peer ID: ", my_id)
	
	if loading_overlay_node and is_instance_valid(loading_overlay_node):
		loading_overlay_node.queue_free()
		loading_overlay_node = null

	client_connected_to_server.emit(target_server_ip, target_server_port)
	spawn_player_avatar(my_id)

func _on_connection_failed() -> void:
	_handle_connection_failure("[Connection Refused] Could not establish connection to " + target_server_ip + ":" + str(target_server_port) + ". Server may be offline or port blocked.")

func _on_server_disconnected() -> void:
	_handle_connection_failure("[Server Disconnected] Session closed by server at " + target_server_ip + ":" + str(target_server_port) + ".")

func disconnect_network() -> void:
	connection_timer_active = false
	if active_peer:
		active_peer.close()
		multiplayer.multiplayer_peer = null
	is_server = false
