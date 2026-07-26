# client_and_studio/scenes/ui/loading_overlay.gd
extends CanvasLayer

## Full-Screen Loading & Connection Error Overlay for Luani Client

@onready var status_label: Label = %StatusLabel
@onready var error_box: VBoxContainer = %ErrorBox
@onready var error_label: Label = %ErrorLabel
@onready var quit_button: Button = %QuitButton
@onready var spinner_label: Label = %SpinnerLabel

var dot_count: int = 0
var anim_timer: float = 0.0
var is_error: bool = false
var base_status_text: String = "Connecting to server"

func _ready() -> void:
	layer = 100
	error_box.hide()
	quit_button.pressed.connect(_on_quit_pressed)

func _process(delta: float) -> void:
	if is_error:
		return

	anim_timer += delta
	if anim_timer >= 0.35:
		anim_timer = 0.0
		dot_count = (dot_count + 1) % 4
		var dots := ""
		for i in range(dot_count):
			dots += "."
		spinner_label.text = dots

func start_loading(ip: String, port: int) -> void:
	is_error = false
	error_box.hide()
	spinner_label.show()
	base_status_text = "Connecting to server at " + ip + ":" + str(port)
	status_label.text = base_status_text
	show()

func show_error(err_msg: String) -> void:
	is_error = true
	spinner_label.hide()
	status_label.text = "Connection Failed"
	error_label.text = err_msg
	error_box.show()
	show()

func _on_quit_pressed() -> void:
	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr and net_mgr.has_method("disconnect_network"):
		net_mgr.call("disconnect_network")

	var main_ui := get_node_or_null("/root/Main")
	if main_ui:
		show()
		hide()
		get_tree().quit()
	else:
		get_tree().quit()
