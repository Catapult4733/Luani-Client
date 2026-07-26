# client_and_studio/scripts/core/network_manager.gd
extends Node

## Singleton managing ENet Multiplayer Peers for Player Self-Hosting and Client Connections

signal server_started(port: int)
signal client_connected_to_server(ip: String, port: int)
signal connection_failed(reason: String)
signal player_spawned(peer_id: int, player_node: Node)

const PLAYER_AVATAR_SCENE := preload("res://scenes/player/player_avatar.tscn")

var active_peer: ENetMultiplayerPeer
var is_server: bool = false
var players_container: Node

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

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
	return OK

## Connects client peer to a Luani server IP:Port
func join_server(ip: String, port: int, auth_token: String = "") -> Error:
	active_peer = ENetMultiplayerPeer.new()
	var err := active_peer.create_client(ip, port)
	if err != OK:
		push_error("[Luani NetworkManager] Failed to connect to server %s:%d: %s" % [ip, port, str(err)])
		connection_failed.emit("Could not reach " + ip + ":" + str(port))
		return err

	multiplayer.multiplayer_peer = active_peer
	is_server = false
	print("[Luani NetworkManager] Client connecting to %s:%d..." % [ip, port])
	return OK

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
	players_container.add_child(avatar)

	print("[Luani NetworkManager] Spawned PlayerAvatar for peer ID: ", peer_id, " under container: ", players_container.get_path())
	player_spawned.emit(peer_id, avatar)
	return avatar

func _on_peer_connected(id: int) -> void:
	print("[Luani NetworkManager] Peer connected: ", id)
	if is_server:
		spawn_player_avatar(id)

func _on_peer_disconnected(id: int) -> void:
	print("[Luani NetworkManager] Peer disconnected: ", id)
	if players_container and players_container.has_node(str(id)):
		players_container.get_node(str(id)).queue_free()

func _on_connected_to_server() -> void:
	var my_id := multiplayer.get_unique_id()
	print("[Luani NetworkManager] Successfully connected to server as peer ID: ", my_id)
	client_connected_to_server.emit("", 0)
	spawn_player_avatar(my_id)

func _on_connection_failed() -> void:
	print("[Luani NetworkManager] Connection attempt failed.")
	connection_failed.emit("Connection timed out or refused.")

func _on_server_disconnected() -> void:
	print("[Luani NetworkManager] Server disconnected.")
	connection_failed.emit("Host closed session.")

func disconnect_network() -> void:
	if active_peer:
		active_peer.close()
		multiplayer.multiplayer_peer = null
	is_server = false
