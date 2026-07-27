# client_and_studio/scripts/core/ui_manager.gd
extends CanvasLayer

## Persistent Autoload UI Manager for Luani Client & Game Worlds
## Manages Chat Overlay and Leaderboard Overlay. Bypassed in headless/dedicated server mode.

var chat_overlay_inst: Node = null
var leaderboard_overlay_inst: Node = null

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		print("[Luani UIManager] Running in Headless/Dedicated Server Mode. Bypassing UI overlays.")
		return

	layer = 100 # Draw on top of game scenes
	process_mode = Node.PROCESS_MODE_ALWAYS

	_setup_overlays()

func _setup_overlays() -> void:
	var chat_scene := load("res://scenes/ui/chat_overlay.tscn")
	if chat_scene and not has_node("ChatOverlay"):
		chat_overlay_inst = chat_scene.instantiate()
		add_child.call_deferred(chat_overlay_inst)

	var tab_scene := load("res://scenes/ui/leaderboard_overlay.tscn")
	if tab_scene and not has_node("LeaderboardOverlay"):
		leaderboard_overlay_inst = tab_scene.instantiate()
		add_child.call_deferred(leaderboard_overlay_inst)

func toggle_chat() -> void:
	if chat_overlay_inst and chat_overlay_inst.has_method("toggle_chat"):
		chat_overlay_inst.call("toggle_chat")

func toggle_leaderboard() -> void:
	if leaderboard_overlay_inst and leaderboard_overlay_inst.has_method("toggle_leaderboard"):
		leaderboard_overlay_inst.call("toggle_leaderboard")
