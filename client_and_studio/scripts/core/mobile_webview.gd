# client_and_studio/scripts/core/mobile_webview.gd
extends CanvasLayer

## In-App Mobile Web View overlay for web-to-game launching and seamless web portal browsing on Android/iOS

signal uri_intercepted(uri: String)

@onready var web_container: Control = %WebContainer
@onready var btn_refresh_web: Button = %BtnRefreshWeb
@onready var btn_quick_play: Button = %BtnQuickPlay
@onready var btn_close_web: Button = %BtnCloseWeb

var webview_id: int = -1
var target_url: String = "https://www.luani.fyi"

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		hide()
		return

	if btn_refresh_web:
		btn_refresh_web.pressed.connect(_on_refresh_pressed)
	if btn_quick_play:
		btn_quick_play.pressed.connect(_on_quick_play_pressed)
	if btn_close_web:
		btn_close_web.pressed.connect(hide)

	# Check if mobile device
	if OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]:
		_setup_mobile_webview()

func _setup_mobile_webview() -> void:
	print("[Luani MobileWebView] Initializing mobile webview overlay for URL: ", target_url)
	# Check for native Engine / DisplayServer webview interface or fallback overlay
	if Engine.has_singleton("GodotWebView"):
		var webview = Engine.get_singleton("GodotWebView")
		if webview and webview.has_method("open"):
			webview.open(target_url)

func load_web_portal() -> void:
	show()
	_on_refresh_pressed()

func _on_refresh_pressed() -> void:
	print("[Luani MobileWebView] Refreshing web portal at ", target_url)

func _on_quick_play_pressed() -> void:
	print("[Luani MobileWebView] Quick Play selected. Joining starter world.")
	hide()
	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_method("connect_to_server"):
		game_mgr.connect_to_server("luani.fyi", 7700, "")

func handle_navigation(url: String) -> void:
	if "luani://join" in url or url.begins_with("luani://"):
		print("[Luani MobileWebView] Intercepted protocol navigation URL: ", url)
		hide()
		uri_intercepted.emit(url)
