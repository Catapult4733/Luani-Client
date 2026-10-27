extends CanvasLayer
## Android-only connection UI; no account, website launcher or practice menu.
signal retry_requested
const UI = preload("res://scripts/ui_theme.gd")
var _title: Label
var _detail: Label
var _retry: Button

func _ready() -> void:
	var root := Control.new(); root.theme=UI.make_theme(); add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color=UI.DARK; root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new(); root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new(); box.custom_minimum_size.x=320; box.add_theme_constant_override("separation",18); center.add_child(box)
	_title=UI.label("connecting",26,UI.INK,600); _title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; box.add_child(_title)
	_detail=UI.label("",14,UI.MUTED); _detail.custom_minimum_size.x=320; _detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; box.add_child(_detail)
	_retry=Button.new(); _retry.text="Retry"; _retry.custom_minimum_size.y=48; _retry.pressed.connect(func() -> void: retry_requested.emit()); box.add_child(_retry)
	show_connecting()

func show_connecting() -> void:
	_title.text="connecting"; _detail.hide(); _retry.hide(); show()

func show_error(message: String) -> void:
	_title.text="Connection unavailable"; _detail.text=message.substr(0,240); _detail.show(); _retry.show(); show()
