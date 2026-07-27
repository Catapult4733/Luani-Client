# client_and_studio/scenes/ui/chat_overlay.gd
extends CanvasLayer

## In-Game Multiplayer Chat System with Badges (👑 Owner, 🔵 Verified BBCode Image) after Username

@onready var chat_log: RichTextLabel = %ChatLog
@onready var chat_input: LineEdit = %ChatInput
@onready var chat_input_container: HBoxContainer = %ChatInputContainer

var local_username: String = "Player"
var is_owner: bool = false
var is_verified: bool = false

func _ready() -> void:
	chat_input.text_submitted.connect(_on_chat_submitted)
	chat_input_container.hide()

	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		if net_mgr.local_username != "":
			local_username = net_mgr.local_username
		is_owner = net_mgr.is_owner
		is_verified = net_mgr.is_verified

	add_system_message("Welcome to Luani! Press [T] or [Enter] to chat.")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if (event.keycode == KEY_T or event.keycode == KEY_ENTER) and not chat_input.has_focus():
			toggle_chat()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and chat_input.has_focus():
			chat_input.release_focus()
			chat_input_container.hide()
			get_viewport().set_input_as_handled()

func toggle_chat() -> void:
	if chat_input_container.visible:
		chat_input.release_focus()
		chat_input_container.hide()
	else:
		chat_input_container.show()
		chat_input.grab_focus()

func _on_chat_submitted(new_text: String) -> void:
	var msg := new_text.strip_edges()
	chat_input.text = ""
	chat_input.release_focus()
	chat_input_container.hide()

	if msg == "":
		return

	# Broadcast to all connected peers via RPC
	rpc("receive_chat_message", local_username, msg, is_owner, is_verified)

@rpc("any_peer", "call_local", "reliable")
func receive_chat_message(sender_name: String, msg_text: String, sender_is_owner: bool, sender_is_verified: bool) -> void:
	var badges := ""
	if sender_is_owner:
		badges += " 👑"
	if sender_is_verified:
		badges += " [img tint=#1DA1F2 width=16 height=16]res://assets/verified_badge.png[/img]"

	var formatted := "[b][color=#818cf8]%s[/color][/b]%s: %s" % [sender_name, badges, msg_text]
	chat_log.append_text(formatted + "\n")

func add_system_message(text: String) -> void:
	chat_log.append_text("[i][color=#9ca3af][System]: " + text + "[/color][/i]\n")
