extends Node
## Bounded JSON-only ENet+DTLS. No RPC/Variant/object decoding or plaintext fallback.
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal message_received(peer_id: int, message: Dictionary)
signal failed(message: String)
const MAX_PACKET := 32768
var _host: ENetConnection
var _peers: Dictionary = {}

func start_server(port: int, key: CryptoKey, certificate: X509Certificate) -> Error:
	_host = ENetConnection.new()
	var error := _host.create_host_bound("127.0.0.1", port, 64, 2, 2097152, 2097152)
	if error != OK: return error
	error = _host.dtls_server_setup(TLSOptions.server(key, certificate))
	if error != OK: close()
	return error

func start_client(endpoint: Dictionary) -> Error:
	var certificate := X509Certificate.new()
	if certificate.load_from_string(str(endpoint.get("certificate", ""))) != OK: return ERR_INVALID_DATA
	var address := str(endpoint.get("host", ""))
	var port := int(endpoint.get("port", 0))
	if address.is_empty() or address.length() > 253 or port < 1024 or port > 65535: return ERR_INVALID_PARAMETER
	_host = ENetConnection.new()
	var error := _host.create_host(1, 2, 262144, 262144)
	if error != OK: return error
	error = _host.dtls_client_setup(str(endpoint.get("common_name", "luani-game")), TLSOptions.client(certificate, "luani-game"))
	if error != OK: close(); return error
	var remote := _host.connect_to_host(address, port, 2)
	if remote == null: close(); return ERR_CANT_CONNECT
	return OK

func _process(_delta: float) -> void:
	if _host == null: return
	for _index in range(256):
		var event: Array = _host.service(0)
		var kind: int = int(event[0])
		if kind == ENetConnection.EVENT_NONE: break
		if kind == ENetConnection.EVENT_ERROR:
			failed.emit("Secure game connection failed.")
			close()
			break
		var peer := event[1] as ENetPacketPeer
		if peer == null: continue
		var id: int = peer.get_instance_id()
		if kind == ENetConnection.EVENT_CONNECT:
			_peers[id] = peer
			peer.set_timeout(16, 5000, 12000)
			peer_joined.emit(id)
		elif kind == ENetConnection.EVENT_DISCONNECT:
			_peers.erase(id)
			peer_left.emit(id)
		elif kind == ENetConnection.EVENT_RECEIVE:
			var bytes: PackedByteArray = peer.get_packet()
			if bytes.size() > MAX_PACKET:
				disconnect_peer(id)
				continue
			var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
			if not value is Dictionary:
				disconnect_peer(id)
				continue
			message_received.emit(id, value)

func send_message(id: int, message: Dictionary, reliable: bool = true) -> void:
	var peer := _peers.get(id) as ENetPacketPeer
	if peer == null or not peer.is_active(): return
	var bytes := JSON.stringify(message).to_utf8_buffer()
	if bytes.size() > MAX_PACKET: return
	peer.send(0 if reliable else 1, bytes, ENetPacketPeer.FLAG_RELIABLE if reliable else 0)

func disconnect_peer(id: int) -> void:
	var peer := _peers.get(id) as ENetPacketPeer
	if peer != null and peer.is_active(): peer.peer_disconnect_now()
	_peers.erase(id)
	peer_left.emit(id)

func rtt(id: int) -> float:
	var peer := _peers.get(id) as ENetPacketPeer
	return peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) * 0.001 if peer != null else 0.0

func flush() -> void:
	if _host != null: _host.flush()

func close() -> void:
	_peers.clear()
	if _host != null: _host.destroy()
	_host = null

func _exit_tree() -> void:
	close()
