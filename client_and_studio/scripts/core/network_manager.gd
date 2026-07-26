# client_and_studio/scripts/core/network_manager.gd
extends Node

## Singleton managing ENet Multiplayer Peers for Player Self-Hosting, Client Connections, Domain Resolution, and Loading/Error UI

signal server_started(port: int)
signal client_connected_to_server(ip: String, port: int)
signal connection_failed(reason: String)
signal player_spawned(peer_id: int, player_node: Node)

const PLAYER_AVATAR_SCENE := preload("res://scenes/player/player_avatar.tscn")
const LOADING_OVERLAY_SCENE := preload("res://scenes/ui/loading_overlay.tscn")

var active_peer: ENetMultiplayerPeer
var is_server: bool = false
var players_container: Node
var local_username: String = "Player"
var local_avatar: String = ""

var loading_overlay_node: CanvasLayer = null
var target_server_ip: String = "127.0.0.1"
var target_server_port: int = 7777
var connection_timer_active: bool = false
var connection_elapsed: float = 0.0
const CONNECTION_TIMEOUT_SECONDS: float = 12.0

var backend_status_url: String = "https://www.luani.fyi/api/daemon/update-status"
var server_request_id: String = ""

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	var parser := get_node_or_null("/root/ProtocolParser")
	if parser and parser.latest_session_data.get("username", "") != "":
		local_username = parser.latest_session_data.get("username")
		local_avatar = parser.latest_session_data.get("avatar", "")
		print("[Luani NetworkManager] Initialized local player identity: ", local_username)

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
			_handle_connection_failure("[Connection Timeout] Server at " + target_server_ip + ":" + str(target_server_port) + " failed to respond within 12 seconds.")

func setup_players_container(container: Node) -> void:
	players_container = container

## Starts an ENet server instance for self-hosting or headless server mode
func host_server(port: int = 7777, max_clients: int = 16) -> Error:
	active_peer = ENetMultiplayerPeer.new()
	var err := active_peer.create_server(port, max_clients)
	if err != OK:
		push_error("[Luani NetworkManager] Failed to start ENet server on port %d: %s" % [port, str(err)])
		connection_failed.emit("Failed to bind port " + str(port))
		return err

	multiplayer.multiplayer_peer = active_peer
	is_server = true
	print("[Luani NetworkManager] ENet Server running on port: ", port)
	server_started.emit(port)

	# Spawn local host player avatar (peer id 1)
	spawn_player_avatar(1)
	_report_player_count_to_backend()
	return OK

## Connects client peer to a Luani server IP or Domain Name (playit.gg) with 12s timeout & loading screen
func join_server(ip: String, port: int, auth_token: String = "") -> Error:
	target_server_ip = ip
	target_server_port = port
	connection_elapsed = 0.0
	connection_timer_active = true

	var connect_host := ip.strip_edges()
	var resolved_ip := connect_host

	if not connect_host.is_valid_ip_address():
		print("[Luani NetworkManager] Target host '%s' is a domain name. Resolving IPv4..." % connect_host)
		var dns_result := IP.resolve_hostname(connect_host, IP.TYPE_IPV4)
		if dns_result != "" and dns_result.is_valid_ip_address():
			print("[Luani NetworkManager] Resolved domain '%s' -> IP: %s" % [connect_host, dns_result])
			resolved_ip = dns_result
		else:
			print("[Luani NetworkManager] Warning: IP.resolve_hostname returned '%s' for domain '%s'. Passing hostname directly." % [dns_result, connect_host])

	print("[Luani NetworkManager] Connecting to host: %s (resolved IP: %s) port: %d..." % [connect_host, resolved_ip, port])

	# Show Loading Overlay UI (Safely deferred to prevent scene tree lock)
	call_deferred("_show_loading_screen", ip, port)

	active_peer = ENetMultiplayerPeer.new()
	var err := active_peer.create_client(resolved_ip, port)
	if err != OK:
		push_error("[Luani NetworkManager] Failed to create client connection to %s (%s):%d: %s" % [ip, resolved_ip, port, str(err)])
		_handle_connection_failure("[Connection Refused] Could not establish connection to " + ip + ":" + str(port) + ". Server may be offline or port blocked.")
		return err

	multiplayer.multiplayer_peer = active_peer
	is_server = false
	print("[Luani NetworkManager] Client connection initialized for %s (%s):%d (12s timeout active)..." % [ip, resolved_ip, port])
	return OK

func _show_loading_screen(ip: String, port: int) -> void:
	if not loading_overlay_node or not is_instance_valid(loading_overlay_node):
		loading_overlay_node = LOADING_OVERLAY_SCENE.instantiate() as CanvasLayer
		get_tree().root.add_child.call_deferred(loading_overlay_node)
	
	if loading_overlay_node.has_method("start_loading"):
		loading_overlay_node.call_deferred("start_loading", ip, port)

func _handle_connection_failure(reason: String) -> void:
	connection_timer_active = false
	print("[Luani NetworkManager] Connection failure: ", reason)
	connection_failed.emit(reason)

	if not loading_overlay_node or not is_instance_valid(loading_overlay_node):
		loading_overlay_node = LOADING_OVERLAY_SCENE.instantiate() as CanvasLayer
		get_tree().root.add_child.call_deferred(loading_overlay_node)

	if loading_overlay_node.has_method("show_error"):
		loading_overlay_node.call_deferred("show_error", reason)

func spawn_player_avatar(peer_id: int) -> Node:
	if not players_container or not is_instance_valid(players_container):
		players_container = get_node_or_null("/root/GameWorld/Players")
		if not players_container:
			players_container = get_node_or_null("/root/Main/Players")
		if not players_container:
			players_container = self

	# Avoid duplicate avatar spawning
	if players_container.has_node(str(peer_id)):
		return players_container.get_node(str(peer_id)) as Node

	var avatar := PLAYER_AVATAR_SCENE.instantiate() as CharacterBody3D
	avatar.name = str(peer_id)
	avatar.position = Vector3(randf_range(-2, 2), 2.0, randf_range(-2, 2))
	players_container.add_child.call_deferred(avatar)

	if avatar.has_method("set_player_username"):
		var uname: String = local_username if peer_id == multiplayer.get_unique_id() else "Player_" + str(peer_id)
		avatar.call_deferred("set_player_username", uname)

	print("[Luani NetworkManager] Spawned PlayerAvatar for peer ID: ", peer_id, " under container: ", players_container.get_path())
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
		spawn_player_avatar(id)
		_report_player_count_to_backend()

func _on_peer_disconnected(id: int) -> void:
	print("[Luani NetworkManager] Peer disconnected: ", id)
	if players_container and players_container.has_node(str(id)):
		players_container.get_node(str(id)).queue_free()
	if is_server:
		_report_player_count_to_backend()

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
