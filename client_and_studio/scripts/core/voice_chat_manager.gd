# client_and_studio/scripts/core/voice_chat_manager.gd
extends Node

## Real-Time Multiplayer 3D Voice Chat Manager for Luani Client
## Captures local microphone input and streams 3D spatial voice audio to connected peers.

signal mic_state_changed(is_active: bool)

var is_mic_active: bool = false
var capture_effect: AudioEffectCapture = null
var record_bus_index: int = -1
var voice_bus_index: int = -1

func _ready() -> void:
	_setup_voice_audio_buses()

func _setup_voice_audio_buses() -> void:
	# Ensure 'Voice' bus exists
	voice_bus_index = AudioServer.get_bus_index("Voice")
	if voice_bus_index < 0:
		AudioServer.add_bus()
		voice_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(voice_bus_index, "Voice")
		AudioServer.set_bus_send(voice_bus_index, "Master")

	# Ensure 'Record' bus exists with AudioEffectCapture
	record_bus_index = AudioServer.get_bus_index("Record")
	if record_bus_index < 0:
		AudioServer.add_bus()
		record_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(record_bus_index, "Record")
		
		capture_effect = AudioEffectCapture.new()
		AudioServer.add_bus_effect(record_bus_index, capture_effect)
		AudioServer.set_bus_mute(record_bus_index, true) # Muted locally so player doesn't hear own echo
	else:
		for i in range(AudioServer.get_bus_effect_count(record_bus_index)):
			var eff := AudioServer.get_bus_effect(record_bus_index, i)
			if eff is AudioEffectCapture:
				capture_effect = eff
				break

func toggle_mic() -> bool:
	if OS.has_feature("android"):
		if not OS.get_granted_permissions().has("android.permission.RECORD_AUDIO"):
			OS.request_permission("RECORD_AUDIO")
			print("[Luani VoiceChat] Requested Android RECORD_AUDIO runtime permission.")
	is_mic_active = not is_mic_active
	if capture_effect:
		capture_effect.clear()
	emit_signal("mic_state_changed", is_mic_active)
	print("[Luani VoiceChat] Microphone toggled: ", is_mic_active)
	return is_mic_active

func _process(_delta: float) -> void:
	if not is_mic_active or not capture_effect:
		return
		
	var frames_avail := capture_effect.get_frames_available()
	if frames_avail >= 512:
		var buffer := capture_effect.get_buffer(frames_avail)
		if buffer.size() > 0:
			var sender_id := multiplayer.get_unique_id()
			rpc("rpc_receive_voice_chunk", sender_id, buffer)

@rpc("any_peer", "unreliable_ordered", "call_remote")
func rpc_receive_voice_chunk(sender_peer_id: int, pcm_buffer: PackedVector2Array) -> void:
	if pcm_buffer.is_empty():
		return
		
	# Find target player avatar node
	var player_node: Node = get_node_or_null("/root/GameWorld/Players/" + str(sender_peer_id))
	if not player_node:
		player_node = get_node_or_null("/root/Main/Players/" + str(sender_peer_id))
		
	if player_node and player_node.has_method("play_voice_chunk"):
		player_node.call("play_voice_chunk", pcm_buffer)
